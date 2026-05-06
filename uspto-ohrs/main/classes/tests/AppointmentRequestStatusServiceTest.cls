@isTest
private class AppointmentRequestStatusServiceTest {
    
    @TestSetup
    static void setupTestData() {
        OHRTestDataFactory.createOHRAdminUser();
        User volunteer = OHRTestDataFactory.createVolunteerUser(0);
        
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = volunteer.Id,
            Status__c = 'New',
            Reference_Email__c = 'test@example.com',
            Reference_First_Name__c = 'Test'
        );
        insert request;
    }
    
    @isTest
    static void testIsValidEmail_Success() {
        Test.startTest();
        Boolean result1 = AppointmentRequestStatusService.isValidEmail('test@example.com');
        Boolean result2 = AppointmentRequestStatusService.isValidEmail('user.name@example.com');
        Boolean result3 = AppointmentRequestStatusService.isValidEmail('test+tag@example.com');
        Test.stopTest();
        
        Assert.areEqual(true, result1, 'Should validate standard email');
        Assert.areEqual(true, result2, 'Should validate email with subdomain');
        Assert.areEqual(true, result3, 'Should validate email with plus');
    }
    
    @isTest
    static void testIsValidEmail_Invalid() {
        Test.startTest();
        Boolean result1 = AppointmentRequestStatusService.isValidEmail('');
        Boolean result2 = AppointmentRequestStatusService.isValidEmail(null);
        Boolean result3 = AppointmentRequestStatusService.isValidEmail('invalid');
        Boolean result4 = AppointmentRequestStatusService.isValidEmail('test@');
        Test.stopTest();
        
        Assert.areEqual(false, result1, 'Should reject empty string');
        Assert.areEqual(false, result2, 'Should reject null');
        Assert.areEqual(false, result3, 'Should reject email without @');
        Assert.areEqual(false, result4, 'Should reject email without domain');
    }
    
    @isTest
    static void testUpdateStatusToSent_Success() {
        Appointment_Request__c request = [SELECT Id FROM Appointment_Request__c WHERE Status__c = 'New' LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AppointmentRequestStatusService.updateStatusToSent(new List<Id>{ request.Id });
        Test.stopTest();
        
        Assert.areEqual(true, result.get('success'), 'Should succeed');
        Assert.areEqual(1, result.get('recordsUpdated'), 'Should update 1 record');
        
        Appointment_Request__c updatedRequest = [SELECT Status__c FROM Appointment_Request__c WHERE Id = :request.Id];
        Assert.areEqual('Sent', updatedRequest.Status__c, 'Status should be updated to Sent');
    }
    
    @isTest
    static void testUpdateStatusToSent_NoRecords() {
        Test.startTest();
        Map<String, Object> result = AppointmentRequestStatusService.updateStatusToSent(new List<Id>());
        Test.stopTest();
        
        Assert.areEqual(false, result.get('success'), 'Should fail with no records');
        List<String> errors = (List<String>) result.get('errors');
        Assert.isFalse(errors.isEmpty(), 'Should have error message');
    }
    
    @isTest
    static void testUpdateStatusToSent_NullInput() {
        Test.startTest();
        Map<String, Object> result = AppointmentRequestStatusService.updateStatusToSent(null);
        Test.stopTest();
        
        Assert.areEqual(false, result.get('success'), 'Should fail with null input');
    }
    
    @isTest
    static void testUpdateStatusToSent_AlreadySent() {
        Appointment_Request__c request = [SELECT Id FROM Appointment_Request__c WHERE Status__c = 'New' LIMIT 1];
        request.Status__c = 'Sent';
        update request;
        
        Test.startTest();
        Map<String, Object> result = AppointmentRequestStatusService.updateStatusToSent(new List<Id>{ request.Id });
        Test.stopTest();
        
        Assert.areEqual(false, result.get('success'), 'Should fail for already sent record');
    }
    
    @isTest
    static void testUpdateStatusToSent_MissingEmail() {
        Appointment_Request__c request = [SELECT Id FROM Appointment_Request__c WHERE Status__c = 'New' LIMIT 1];
        request.Reference_Email__c = null;
        update request;
        
        Test.startTest();
        Map<String, Object> result = AppointmentRequestStatusService.updateStatusToSent(new List<Id>{ request.Id });
        Test.stopTest();
        
        Assert.areEqual(false, result.get('success'), 'Should fail for missing email');
        List<String> errors = (List<String>) result.get('errors');
        Assert.isFalse(errors.isEmpty(), 'Should have error about missing email');
    }
}

