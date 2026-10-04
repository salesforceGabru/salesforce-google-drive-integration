import { LightningElement, api, track, wire } from 'lwc';
import uploadFileToDrive from '@salesforce/apex/GoogleDriveService.uploadFileToDrive';
import uploadFilesToDrive from '@salesforce/apex/GoogleDriveService.uploadFilesToDrive';
import getMaxUploadMb from '@salesforce/apex/GoogleDriveService.getMaxUploadMb';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FALLBACK_MAX_MB = 4;

/**
 * Generic Dynamic Google Drive Uploader Child Component
 */
export default class GoogleDriveUploader extends LightningElement {
    // Configurable Public Attributes for Child Usage
    @api recordId;                  // Target Salesforce Record ID
    @api docType = 'General';       // Document classification/type
    @api label = 'Upload Document'; // Form label
    @api hideUploadButton = false;  // Hide standalone button (useful if parent submits on form submit)
    @api autoUpload = false;        // Trigger instant upload on file drop/select
    @api allowMultiple = false;     // Multi-file upload support
    @api compact = false;           // Inline compact icon mode
    @api acceptedFormats = '*/*';    // MIME types or extensions (e.g. '.pdf,.png,image/*')
    @api iconTitle = 'Click or drop files here to upload to Google Drive';

    @track isLoading = false;
    @track selectedFiles = [];
    @track isDragOver = false;

    maxMb = FALLBACK_MAX_MB;

    @wire(getMaxUploadMb)
    wiredMax({ data, error }) {
        if (data) {
            this.maxMb = Number(data) || FALLBACK_MAX_MB;
        } else if (error) {
            this.maxMb = FALLBACK_MAX_MB;
        }
    }

    // Dynamic Getters
    get selectedFile() { 
        return this.selectedFiles[0] || null; 
    }

    get fileName() {
        if (this.selectedFiles.length === 0) return '';
        if (this.selectedFiles.length === 1) return this.selectedFiles[0].name;
        return `${this.selectedFiles.length} files selected (${this.selectedFiles.map(f => f.name).join(', ')})`;
    }

    get fileSizeFormatted() {
        if (this.selectedFiles.length === 0) return '';
        const totalBytes = this.selectedFiles.reduce((acc, f) => acc + f.size, 0);
        return `${(totalBytes / (1024 * 1024)).toFixed(2)} MB total`;
    }

    get dropzoneClass() {
        return `slds-file-selector__dropzone gd-dropzone ${this.isDragOver ? 'gd-drag-over' : ''}`;
    }

    get compactClass() { 
        return `gd-compact-wrapper ${this.isLoading ? 'is-loading' : ''} ${this.isDragOver ? 'gd-drag-over' : ''}`; 
    }

    get limitLabel() {
        return `Max ${this.maxMb} MB per file`;
    }

    @api
    get hasFile() {
        return this.selectedFiles.length > 0;
    }

    get showUploadButton() {
        return !this.hideUploadButton && !this.autoUpload && this.hasFile;
    }

    // Drag & Drop Handlers
    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = true;
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = false;
        
        const files = event.dataTransfer && event.dataTransfer.files;
        if (files && files.length > 0) {
            this.acceptFiles(files);
        }
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (files && files.length > 0) {
            this.acceptFiles(files);
        }
    }

    acceptFiles(fileList) {
        let files = Array.from(fileList);
        
        if (!this.allowMultiple && files.length > 1) {
            files = [files[0]];
        }

        const limitBytes = this.maxMb * 1024 * 1024;
        const tooBig = files.find(f => f.size > limitBytes);

        if (tooBig) {
            const sizeMb = (tooBig.size / (1024 * 1024)).toFixed(1);
            this.showToast(
                'File Too Large',
                `"${tooBig.name}" is ${sizeMb} MB. Max allowed is ${this.maxMb} MB.`,
                'error'
            );
            this.handleRemoveFile();
            return;
        }

        this.selectedFiles = files;

        // Dispatch Custom Event to Parent LWC
        this.dispatchEvent(new CustomEvent('fileselected', { 
            detail: { 
                files: this.selectedFiles, 
                fileName: this.fileName, 
                count: files.length 
            } 
        }));

        if (this.compact || this.autoUpload) {
            this.handleManualUpload();
        }
    }

    openPicker(event) {
        event.preventDefault();
        event.stopPropagation();
        const input = this.template.querySelector('input[type="file"]');
        if (input) input.click();
    }

    @api
    handleRemoveFile() {
        this.selectedFiles = [];
        try {
            const input = this.template.querySelector('input[type="file"]');
            if (input) input.value = '';
        } catch (e) {
            // reset safety
        }
        this.dispatchEvent(new CustomEvent('fileremoved'));
    }

    async handleManualUpload() {
        try {
            const result = await this.uploadSelectedFile(this.recordId);
            if (result) {
                const count = result.count || 1;
                this.showToast(
                    'Success', 
                    count > 1 ? `${count} files uploaded to Google Drive.` : 'File uploaded to Google Drive.', 
                    'success'
                );
            }
        } catch (error) {
            // Managed in uploadSelectedFile
        }
    }

    readFileAsPayload(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({ 
                fileName: file.name, 
                fileType: file.type || 'application/octet-stream', 
                base64Data: reader.result.split(',')[1] 
            });
            reader.onerror = (err) => reject(err);
            reader.readAsDataURL(file);
        });
    }

    /**
     * Programmatic API callable from parent component
     * Usage: this.template.querySelector('c-google-drive-uploader').uploadSelectedFile(recordId);
     */
    @api
    async uploadSelectedFile(targetRecordId) {
        if (this.selectedFiles.length === 0) return null;

        const activeRecordId = targetRecordId || this.recordId;
        this.isLoading = true;

        try {
            let result;
            if (this.selectedFiles.length === 1) {
                const payload = await this.readFileAsPayload(this.selectedFiles[0]);
                result = await uploadFileToDrive({
                    recordId: activeRecordId,
                    fileName: payload.fileName,
                    fileType: payload.fileType,
                    base64Data: payload.base64Data,
                    docType: this.docType
                });
            } else {
                const payloads = await Promise.all(this.selectedFiles.map(f => this.readFileAsPayload(f)));
                result = await uploadFilesToDrive({ 
                    recordId: activeRecordId, 
                    docType: this.docType, 
                    filesJson: JSON.stringify(payloads) 
                });
            }
            
            this.isLoading = false;
            
            // Dispatch success event to parent
            this.dispatchEvent(new CustomEvent('docuploaded', { 
                detail: { 
                    recordId: activeRecordId, 
                    result: result 
                } 
            }));

            this.handleRemoveFile();
            return result;

        } catch (error) {
            this.isLoading = false;
            const msg = (error && error.body && error.body.message) || error.message || 'Upload failed.';
            
            this.dispatchEvent(new CustomEvent('uploaderror', { 
                detail: { error: msg } 
            }));

            this.showToast('Upload Error', msg.replace(/^Upload failed:\s*/i, ''), 'error');
            throw error;
        }
    }

    stopProp(event) { 
        event.stopPropagation(); 
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant, 
            mode: variant === 'error' ? 'sticky' : 'dismissible' 
        }));
    }
}