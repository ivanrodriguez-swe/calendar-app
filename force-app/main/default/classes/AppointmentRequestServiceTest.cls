@isTest
private class AppointmentRequestServiceTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
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
        User volunteer = [SELECT Id, Email FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        String csvContent = volunteer.Email + ',John,Doe,john.doe@test.com\n' +
                           volunteer.Email + ',Jane,Smith,jane.smith@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Upload should succeed');
            System.assertEquals(2, result.get('recordsCreated'), 'Should create 2 records');
            System.assertNotEquals(null, result.get('message'), 'Message should be set');
        }
        Test.stopTest();
        
        // Verify records were created
        List<Appointment_Request__c> requests = [
            SELECT Id, Volunteer__c, Reference_First_Name__c, Reference_Last_Name__c, Reference_Email__c, Status__c
            FROM Appointment_Request__c
        ];
        System.assertEquals(2, requests.size(), 'Should have 2 appointment requests');
        System.assertEquals('New', requests[0].Status__c, 'Status should be New');
    }
    
    @isTest
    static void testUploadCSV_WithHeader() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id, Email FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        String csvContent = 'Volunteer Email,First Name,Last Name,Email\n' +
                           volunteer.Email + ',John,Doe,john.doe@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Upload should succeed');
            System.assertEquals(1, result.get('recordsCreated'), 'Should create 1 record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_WithQuotedValues() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id, Email FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        String csvContent = '"' + volunteer.Email + '","John","Doe","john.doe@test.com"';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Upload should succeed');
            System.assertEquals(1, result.get('recordsCreated'), 'Should create 1 record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_EmptyCSV() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV('');
            
            System.assertEquals(false, result.get('success'), 'Upload should fail');
            System.assertEquals('CSV content is empty', result.get('message'), 'Should have correct error message');
            System.assertEquals(0, result.get('recordsCreated'), 'Should not create any records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_NullCSV() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(null);
            
            System.assertEquals(false, result.get('success'), 'Upload should fail');
            System.assertEquals('CSV content is empty', result.get('message'), 'Should have correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_NoValidRecords() {
        User admin = getAdminUser();
        
        // CSV with invalid volunteer email - will be parsed but skipped during volunteer matching
        String csvContent = 'invalid@test.com,John,Doe,john.doe@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(false, result.get('success'), 'Upload should fail');
            System.assert(String.valueOf(result.get('message')).contains('No valid appointment requests'), 'Should indicate no valid records');
            System.assertEquals(0, result.get('recordsCreated'), 'Should not create any records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_VolunteerEmailNotFound() {
        User admin = getAdminUser();
        
        String csvContent = 'nonexistent@test.com,John,Doe,john.doe@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(false, result.get('success'), 'Upload should fail');
            System.assert(String.valueOf(result.get('message')).contains('No valid appointment requests'), 'Should indicate no valid records');
            System.assertEquals(0, result.get('recordsCreated'), 'Should not create any records');
            
            List<String> skippedRecords = (List<String>) result.get('skippedRecords');
            System.assert(skippedRecords.size() > 0, 'Should have skipped records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_VolunteerIdAsEmail() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        // Use User ID directly (starts with 005)
        String csvContent = volunteer.Id + ',John,Doe,john.doe@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Upload should succeed');
            System.assertEquals(1, result.get('recordsCreated'), 'Should create 1 record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_MissingRequiredFields() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id, Email FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        // Missing last name
        String csvContent = volunteer.Email + ',John,,john.doe@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(false, result.get('success'), 'Upload should fail');
            System.assertEquals('No valid records found in CSV', result.get('message'), 'Should have correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_MixedValidAndInvalid() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id, Email FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        String csvContent = volunteer.Email + ',John,Doe,john.doe@test.com\n' +
                           'nonexistent@test.com,Jane,Smith,jane.smith@test.com\n' +
                           volunteer.Email + ',Bob,Johnson,bob.johnson@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Upload should succeed');
            System.assertEquals(2, result.get('recordsCreated'), 'Should create 2 valid records');
            
            List<String> skippedRecords = (List<String>) result.get('skippedRecords');
            System.assert(skippedRecords.size() > 0, 'Should have skipped records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUploadCSV_BlankLines() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id, Email FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        String csvContent = volunteer.Email + ',John,Doe,john.doe@test.com\n' +
                           '\n' +
                           volunteer.Email + ',Jane,Smith,jane.smith@test.com';
        
        Test.startTest();
        System.runAs(admin) {
            Map<String, Object> result = AppointmentRequestService.uploadCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Upload should succeed');
            System.assertEquals(2, result.get('recordsCreated'), 'Should create 2 records (blank line skipped)');
        }
        Test.stopTest();
    }
}


