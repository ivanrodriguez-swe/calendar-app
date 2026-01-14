@isTest
private class AppointmentRequestServiceTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE FirstName = 'OHR' AND LastName = 'Admin' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        OHRTestDataFactory.createOHRAdminUser();
    }
    
    @isTest
    static void testProcessFile_Success() {
        User admin = getAdminUser();
        
        String fileContent = 'Doe,John,john@example.com,2026-06-01,Engineering,Jane Smith,jane@example.com,Manager';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(fileContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Process should succeed');
            Assert.areEqual(1, result.get('selecteesCreated'), 'Should create 1 selectee');
            Assert.areEqual(1, result.get('requestsCreated'), 'Should create 1 request');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessFile_WithHeader() {
        User admin = getAdminUser();
        
        String fileContent = 'Selectee Last,First Name,Email,EOD,Discipline,Ref Name,Ref Email,Relationship\n' +
                            'Doe,John,john@example.com,2026-06-01,Engineering,Jane Smith,jane@example.com,Manager';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(fileContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Process should succeed');
            Assert.areEqual(1, result.get('selecteesCreated'), 'Should create 1 selectee');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessFile_MultipleReferences() {
        User admin = getAdminUser();
        
        String fileContent = 'Doe,John,john@example.com,2026-06-01,Engineering,Jane Smith,jane@example.com,Manager,Bob Jones,bob@example.com,Peer';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(fileContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Process should succeed');
            Assert.areEqual(1, result.get('selecteesCreated'), 'Should create 1 selectee');
            Assert.areEqual(2, result.get('requestsCreated'), 'Should create 2 requests');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessFile_EmptyContent() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile('');
            
            Assert.isFalse((Boolean) result.get('success'), 'Process should fail');
            Assert.areEqual('File content is empty', result.get('message'), 'Should have correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessFile_NullContent() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(null);
            
            Assert.isFalse((Boolean) result.get('success'), 'Process should fail');
            Assert.areEqual('File content is empty', result.get('message'), 'Should have correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessFile_NoReferences() {
        User admin = getAdminUser();
        
        String fileContent = 'Doe,John,john@example.com,2026-06-01,Engineering';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(fileContent);
            
            Assert.isFalse((Boolean) result.get('success'), 'Process should fail');
            Assert.isTrue(String.valueOf(result.get('message')).contains('reference'), 'Should mention reference requirement');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessFile_ExistingSelectee() {
        User admin = getAdminUser();
        
        Selectee__c existingSelectee = new Selectee__c(
            Name = 'John Doe',
            Email__c = 'john@example.com'
        );
        insert existingSelectee;
        
        String fileContent = 'Doe,John,john@example.com,2026-06-01,Engineering,Jane Smith,jane@example.com,Manager';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(fileContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Process should succeed');
            Assert.areEqual(0, result.get('selecteesCreated'), 'Should not create new selectee');
            Assert.areEqual(1, result.get('requestsCreated'), 'Should create 1 request');
        }
        Test.stopTest();
        
        List<Selectee__c> selectees = [SELECT Id FROM Selectee__c];
        Assert.areEqual(1, selectees.size(), 'Should still have only 1 selectee');
    }
    
    @isTest
    static void testProcessFile_InvalidDateFormat() {
        User admin = getAdminUser();
        
        String fileContent = 'Doe,John,john@example.com,invalid-date,Engineering,Jane Smith,jane@example.com,Manager';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.processFile(fileContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Process should succeed even with invalid date');
            Assert.areEqual(1, result.get('selecteesCreated'), 'Should create 1 selectee');
        }
        Test.stopTest();
        
        Selectee__c selectee = [SELECT Expected_EOD__c FROM Selectee__c LIMIT 1];
        Assert.isNull(selectee.Expected_EOD__c, 'EOD should be null for invalid date');
    }
}
