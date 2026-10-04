/**
 * @description Generic Apex Controller for Google Drive Integration via Named Credentials.
 * Uses 'callout:Google_Drive_NC' to hit Google Drive API v3 and automatically creates
 * Salesforce ContentVersion/ContentDocumentLink records.
 */
public with sharing class GoogleDriveService {

    private static final String NAMED_CREDENTIAL = 'callout:Google_Drive_NC';
    public static final String ERR_TOO_LARGE = 'TOO_LARGE';
    private static final Decimal DEFAULT_MAX_MB = 4.0; 

    @AuraEnabled(cacheable=true)
    public static Decimal getMaxUploadMb() {
        return DEFAULT_MAX_MB;
    }

    /**
     * @description Uploads a single file to Google Drive and links it to a Salesforce Record
     */
    @AuraEnabled
    public static Map<String, Object> uploadFileToDrive(Id recordId, String fileName, String fileType, String base64Data, String docType) {
        try {
            if (String.isBlank(base64Data)) {
                throw new AuraHandledException('No file content received.');
            }

            // Heap Safety Validation
            Long approxBytes = (Long) (base64Data.length() * 3L / 4L);
            Long maxBytes = (Long)(DEFAULT_MAX_MB * 1024 * 1024);
            if (approxBytes > maxBytes) {
                throw new AuraHandledException(ERR_TOO_LARGE + ': File size exceeds ' + DEFAULT_MAX_MB + ' MB limit.');
            }

            // Execute Callout
            Map<String, String> driveRes = uploadMultipartToDrive(fileName, fileType, base64Data, null);
            base64Data = null; // Release heap

            String fileUrl = driveRes.get('webViewLink');
            String driveId = driveRes.get('id');

            // Link to Salesforce
            Id contentVersionId = null;
            if (recordId != null) {
                contentVersionId = createSalesforceLink(recordId, fileName, fileUrl, driveId);
            }

            return new Map<String, Object>{
                'id'        => driveId,
                'title'     => fileName,
                'url'       => fileUrl,
                'recId'     => recordId,
                'cvId'      => contentVersionId,
                'count'     => 1
            };
        } catch (Exception ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            e.setMessage(ex.getMessage());
            throw e;
        }
    }

    public class FileInput {
        @AuraEnabled public String fileName;
        @AuraEnabled public String fileType;
        @AuraEnabled public String base64Data;
    }

    /**
     * @description Uploads multiple files (groups into a new dated folder if > 1 file)
     */
    @AuraEnabled
    public static Map<String, Object> uploadFilesToDrive(Id recordId, String docType, String filesJson) {
        try {
            if (String.isBlank(filesJson)) throw new AuraHandledException('No files received.');

            List<FileInput> files = (List<FileInput>) JSON.deserialize(filesJson, List<FileInput>.class);
            if (files == null || files.isEmpty()) throw new AuraHandledException('No files received.');

            if (files.size() == 1) {
                FileInput f = files[0];
                return uploadFileToDrive(recordId, f.fileName, f.fileType, f.base64Data, docType);
            }

            String folderName = String.valueOf(Date.today()) + ' - ' + (String.isNotBlank(docType) ? docType : 'Files');
            Map<String, String> folder = createDriveFolder(folderName, null);
            String folderId = folder.get('id');
            String folderUrl = folder.get('webViewLink');

            for (FileInput f : files) {
                uploadMultipartToDrive(f.fileName, f.fileType, f.base64Data, folderId);
            }

            Id cvId = null;
            if (recordId != null) {
                cvId = createSalesforceLink(recordId, folderName, folderUrl, folderId);
            }

            return new Map<String, Object>{
                'id'     => folderId,
                'title'  => folderName,
                'url'    => folderUrl,
                'recId'  => recordId,
                'cvId'   => cvId,
                'count'  => files.size()
            };
        } catch (Exception ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            e.setMessage(ex.getMessage());
            throw e;
        }
    }

    private static Map<String, String> uploadMultipartToDrive(String fileName, String fileType, String base64Data, String parentFolderId) {
        String boundary = '----------' + String.valueOf(DateTime.now().getTime());
        String delimiter = '\r\n--' + boundary + '\r\n';
        String closeDelimiter = '\r\n--' + boundary + '--';

        Map<String, Object> metadata = new Map<String, Object>{ 'name' => fileName };
        if (String.isNotBlank(parentFolderId)) {
            metadata.put('parents', new List<String>{ parentFolderId });
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink&supportsAllDrives=true');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/related; boundary=' + boundary);
        req.setTimeout(120000);
        req.setBody(
            delimiter + 'Content-Type: application/json; charset=UTF-8\r\n\r\n' + JSON.serialize(metadata) +
            delimiter + 'Content-Type: ' + (String.isBlank(fileType) ? 'application/octet-stream' : fileType) + '\r\n' +
            'Content-Transfer-Encoding: base64\r\n\r\n' + base64Data + closeDelimiter
        );

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> r = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return new Map<String, String>{
                'id'          => (String) r.get('id'),
                'webViewLink' => (String) r.get('webViewLink')
            };
        }
        throw new CalloutException('Google API Error (' + res.getStatusCode() + '): ' + res.getBody());
    }

    private static Map<String, String> createDriveFolder(String folderName, String parentFolderId) {
        Map<String, Object> body = new Map<String, Object>{
            'name'     => folderName,
            'mimeType' => 'application/vnd.google-apps.folder'
        };
        if (String.isNotBlank(parentFolderId)) {
            body.put('parents', new List<String>{ parentFolderId });
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/drive/v3/files?fields=id,webViewLink&supportsAllDrives=true');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> r = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return new Map<String, String>{
                'id'          => (String) r.get('id'),
                'webViewLink' => (String) r.get('webViewLink')
            };
        }
        throw new CalloutException('Folder creation failed (' + res.getStatusCode() + '): ' + res.getBody());
    }

    private static Id createSalesforceLink(Id recordId, String title, String url, String driveId) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            ContentUrl = url,
            Origin = 'H'
        );
        insert as user cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH USER_MODE LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId    = recordId,
            ShareType         = 'V'
        );
        insert as user cdl;

        return cv.Id;
    }
}