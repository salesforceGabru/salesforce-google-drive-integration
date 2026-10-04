# salesforce-google-drive-integration
Salesforce Google Drive Integration via Named Credentials &amp; Dynamic LWC  Production-ready Salesforce to Google Drive integration using External/Named Credentials, GCP OAuth 2.0, and a dynamic drag-and-drop Lightning Web Component (LWC). Upload files server-side with auto record linking and zero file size limits.

# 🚀 Salesforce Google Drive Integration (LWC + Named Credentials)

[![Salesforce API](https://img.shields.io/badge/Salesforce-v60.0-00A1E0?logo=salesforce)](https://developer.salesforce.com/)
[![Google Drive API](https://img.shields.io/badge/Google%20Drive%20API-v3-4285F4?logo=googledrive)](https://developers.google.com/drive)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A complete, production-ready solution for integrating **Salesforce with Google Drive** using modern **Salesforce External & Named Credentials** and a dynamic, generic **Lightning Web Component (LWC)** drag-and-drop file uploader.

This repository enables developers to seamlessly upload files directly from any Salesforce record to Google Drive via server-side OAuth 2.0 callouts—bypassing client-side limits and automatically linking uploaded Drive files/folders back to Salesforce records using standard `ContentVersion` attachments.

---

## 🔥 Key Features

* **🔐 Modern Named Credentials & GCP OAuth 2.0:** Secure server-side authentication without hardcoded tokens or client secret leaks in Apex.
* **⚡ Drag & Drop Dynamic LWC (`c-google-drive-uploader`):** Flexible UI supporting drag-and-drop, single/multi-file select, auto-upload on select, and standard/compact display modes.
* **📦 Multi-File Folder Grouping:** Automatically groups multi-file uploads into dated subfolders on Google Drive and attaches a single link in Salesforce.
* **🔗 Automated Salesforce File Linking:** Instantly creates `ContentVersion` / `ContentDocumentLink` records pointing to Google Drive web links.
* **🛡️ Production-Ready Apex & Unit Tests:** Scalable Apex service class (`GoogleDriveService.cls`) complete with unit test coverage (`GoogleDriveServiceTest.cls`) and mock response handlers.
* **🚀 SFDX Deployable:** Built for fast deployment using Salesforce CLI (`sf project deploy start`).

---

