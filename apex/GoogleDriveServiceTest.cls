@IsTest
private class GoogleDriveServiceTest {

    private class GoogleDriveMock implements HttpCalloutMock {
        private Integer statusCode;
        public GoogleDriveMock(Integer code) {
            this.statusCode = code;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);

            String ep = req.getEndpoint();
            if (ep.contains('uploadType=multipart')) {
                res.setBody('{"id":"mock_drive_file_id","webViewLink":"https://drive.google.com/file/d/mock_drive_file_id/view"}');
            } else if (ep.contains('mimeType=application/vnd.google-apps.folder')) {
                res.setBody('{"id":"mock_drive_folder_id","webViewLink":"https://drive.google.com/drive/folders/mock_drive_folder_id"}');
            } else {
                res.setBody('{"id":"mock_id"}');
            }
            return res;
        }
    }

    @IsTest
    static void testSingleFileUpload() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock(200));

        Test.startTest();
        Map<String, Object> result = GoogleDriveService.uploadFileToDrive(
            acc.Id, 
            'TestDoc.pdf', 
            'application/pdf', 
            'SGVsbG8gV29ybGQ=', 
            'General'
        );
        Test.stopTest();

        System.assertEquals('mock_drive_file_id', result.get('id'));
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :acc.Id]);
    }

    @IsTest
    static void testMultiFileUpload() {
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock(200));

        List<GoogleDriveService.FileInput> fileList = new List<GoogleDriveService.FileInput>();
        GoogleDriveService.FileInput f1 = new GoogleDriveService.FileInput();
        f1.fileName = 'Doc1.pdf'; f1.fileType = 'application/pdf'; f1.base64Data = 'SGVsbG8=';
        fileList.add(f1);

        GoogleDriveService.FileInput f2 = new GoogleDriveService.FileInput();
        f2.fileName = 'Doc2.pdf'; f2.fileType = 'application/pdf'; f2.base64Data = 'V29ybGQ=';
        fileList.add(f2);

        Test.startTest();
        Map<String, Object> result = GoogleDriveService.uploadFilesToDrive(
            opp.Id, 
            'Contracts', 
            JSON.serialize(fileList)
        );
        Test.stopTest();

        System.assertEquals(2, result.get('count'));
    }

    @IsTest
    static void testMaxUploadMb() {
        Decimal mb = GoogleDriveService.getMaxUploadMb();
        System.assertNotEquals(null, mb);
    }
}