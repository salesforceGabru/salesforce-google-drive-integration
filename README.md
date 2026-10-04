# 🚀 Salesforce Google Drive Integration (LWC + Named Credentials)

[![Salesforce API](https://img.shields.io/badge/Salesforce-v60.0-00A1E0?logo=salesforce)](https://developer.salesforce.com/)
[![Google Drive API](https://img.shields.io/badge/Google%20Drive%20API-v3-4285F4?logo=googledrive)](https://developers.google.com/drive)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Lightning Web Components](https://img.shields.io/badge/LWC-Enabled-00A1E0)](https://developer.salesforce.com/docs/component-library/overview/components)

Production-ready integration between **Salesforce** and **Google Drive** using modern Salesforce **External & Named Credentials (OAuth 2.0)** and a dynamic, generic **Lightning Web Component (LWC)** drag-and-drop file uploader.

Upload files server-side directly from any Salesforce record into Google Drive, automatically link created Drive files or folders back to the Salesforce record via standard `ContentVersion` attachments, and eliminate hardcoded API tokens or file size bottlenecks.

---

## 📄 Full Setup & Integration Guide (PDF)

> 💡 **Detailed Step-by-Step Instructions:**  
> A complete, step-by-step setup manual with configuration walkthroughs, GCP OAuth screenshots, and setup checkpoints is available in the included PDF document:  
> 🔗 **[`Google Drive Salesforce Integration Guide.pdf`](./Google%20Drive%20Salesforce%20Integration%20Guide.pdf)**

---

## 📁 Repository Structure

```text
salesforce-google-drive-integration/
├── apex/
│   ├── GoogleDriveService.cls       # Core Apex controller handling OAuth callouts & Drive API v3
│   └── GoogleDriveServiceTest.cls   # Comprehensive unit tests with HTTP Callout Mocks
├── lwc/
│   └── googleDriveUploader/         # Dynamic drag-and-drop standalone/child LWC
│       ├── googleDriveUploader.html
│       ├── googleDriveUploader.js
│       ├── googleDriveUploader.css
│       └── googleDriveUploader.js-meta.xml
├── Google Drive Salesforce Integration Guide.pdf  # Comprehensive setup manual & architecture guide
└── README.md                       # Project landing page & developer guide
