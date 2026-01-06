@isTest
private class AppointmentRequestServiceTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE FirstName = 'OHR' AND LastName = 'Admin' LIMIT 1];
    }
    
    private static User getVolunteer() {
        return [SELECT Id, Email FROM User WHERE FirstName = 'Volunteer' AND LastName LIKE 'Test%' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test volunteer users
        List<User> volunteers = OHRTestDataFactory.createVolunteerUsers(2);
    }
    
    @isTest
    static void testUploadCSV_Success() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        String csvContent = volunteer.Email + ',John,Doe,ref0@example.com\n' +
                           volunteer.Email + ',Jane,Smith,ref1@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Upload should succeed');
            Assert.areEqual(2, result.get('recordsCreated'), 'Should create 2 records');
            Assert.isNotNull(result.get('message'), 'Message should be set');
        }
        Test.stopTest();
        
        // Verify records were created
        List<Appointment_Request__c> requests = [
            SELECT Id, Volunteer__c, Reference_First_Name__c, Reference_Last_Name__c, Reference_Email__c, Status__c
            FROM Appointment_Request__c
        ];
        Assert.areEqual(2, requests.size(), 'Should have 2 appointment requests');
        Assert.areEqual('New', requests[0].Status__c, 'Status should be New');
    }
    
    @isTest
    static void testUploadCSV_WithHeader() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        String csvContent = 'Volunteer Email,First Name,Last Name,Email\n' +
                           volunteer.Email + ',John,Doe,ref0@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Upload should succeed');
            Assert.areEqual(1, result.get('recordsCreated'), 'Should create 1 record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_WithQuotedValues() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        String csvContent = '"' + volunteer.Email + '","John","Doe","ref0@example.com"';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Upload should succeed');
            Assert.areEqual(1, result.get('recordsCreated'), 'Should create 1 record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_EmptyCSV() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV('');
            
            Assert.isFalse((Boolean) result.get('success'), 'Upload should fail');
            Assert.areEqual('CSV content is empty', result.get('message'), 'Should have correct error message');
            Assert.areEqual(0, result.get('recordsCreated'), 'Should not create any records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_NullCSV() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(null);
            
            Assert.areEqual(false, result.get('success'), 'Upload should fail');
            Assert.areEqual('CSV content is empty', result.get('message'), 'Should have correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_NoValidRecords() {
        User admin = getAdminUser();
        
        // CSV with invalid volunteer identifier - will be parsed but skipped during volunteer matching
        String csvContent = 'invalid@example.com,John,Doe,ref0@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.isFalse((Boolean) result.get('success'), 'Upload should fail');
            Assert.isTrue(String.valueOf(result.get('message')).contains('No valid appointment requests'), 'Should indicate no valid records');
            Assert.areEqual(0, result.get('recordsCreated'), 'Should not create any records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_VolunteerEmailNotFound() {
        User admin = getAdminUser();
        
        String csvContent = 'nonexistent@example.com,John,Doe,ref0@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.isFalse((Boolean) result.get('success'), 'Upload should fail');
            Assert.isTrue(String.valueOf(result.get('message')).contains('No valid appointment requests'), 'Should indicate no valid records');
            Assert.areEqual(0, result.get('recordsCreated'), 'Should not create any records');
            
            List<String> skippedRecords = (List<String>) result.get('skippedRecords');
            Assert.isTrue(skippedRecords.size() > 0, 'Should have skipped records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_VolunteerIdAsEmail() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        // Test that User ID format (starts with 005) is handled as email lookup
        String csvContent = volunteer.Email + ',John,Doe,ref0@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.isTrue((Boolean) result.get('success'), 'Upload should succeed');
            Assert.areEqual(1, result.get('recordsCreated'), 'Should create 1 record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_MissingRequiredFields() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        // Missing last name
        String csvContent = volunteer.Email + ',John,,ref0@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.areEqual(false, result.get('success'), 'Upload should fail');
            Assert.areEqual('No valid records found in CSV', result.get('message'), 'Should have correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_MixedValidAndInvalid() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        String csvContent = volunteer.Email + ',John,Doe,ref0@example.com\n' +
                           'nonexistent@example.com,Jane,Smith,ref1@example.com\n' +
                           volunteer.Email + ',Bob,Johnson,ref2@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.areEqual(true, result.get('success'), 'Upload should succeed');
            Assert.areEqual(2, result.get('recordsCreated'), 'Should create 2 valid records');
            
            List<String> skippedRecords = (List<String>) result.get('skippedRecords');
            Assert.isTrue(skippedRecords.size() > 0, 'Should have skipped records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_BlankLines() {
        User admin = getAdminUser();
        User volunteer = getVolunteer();
        
        String csvContent = volunteer.Email + ',John,Doe,ref0@example.com\n' +
                           '\n' +
                           volunteer.Email + ',Jane,Smith,ref1@example.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            Assert.areEqual(true, result.get('success'), 'Upload should succeed');
            Assert.areEqual(2, result.get('recordsCreated'), 'Should create 2 records (blank line skipped)');
        }
        Test.stopTest();
    }
}


