@isTest
private class AppointmentRequestSelectorTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test volunteer user
        User volunteer = OHRTestDataFactory.createVolunteerUser(0);
        
        // Create appointment requests
        List<Appointment_Request__c> requests = new List<Appointment_Request__c>();
        for (Integer i = 0; i < 3; i++) {
            requests.add(new Appointment_Request__c(
                Volunteer__c = volunteer.Id,
                Status__c = 'New',
                Reference_Email__c = 'customer' + i + '@test.com',
                Reference_First_Name__c = 'Customer',
                Reference_Last_Name__c = 'Test' + i
            ));
        }
        insert requests;
    }
    
    @isTest
    static void testGetAppointmentRequestById_Success() {
        Appointment_Request__c request = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        List<Appointment_Request__c> result = AppointmentRequestSelector.getAppointmentRequestById(request.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return one request');
        System.assertEquals(request.Id, result[0].Id, 'Should return correct request');
        System.assertNotEquals(null, result[0].Volunteer__c, 'Should have volunteer');
        System.assertNotEquals(null, result[0].Status__c, 'Should have status');
    }
    
    @isTest
    static void testGetAppointmentRequestById_WithReferenceInfo() {
        Appointment_Request__c request = [SELECT Id FROM Appointment_Request__c 
                                          WHERE Reference_Email__c = 'customer0@test.com' LIMIT 1];
        
        Test.startTest();
        List<Appointment_Request__c> result = AppointmentRequestSelector.getAppointmentRequestById(request.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return one request');
        System.assertNotEquals(null, result[0].Reference_Email__c, 'Should have reference email');
        System.assertNotEquals(null, result[0].Reference_First_Name__c, 'Should have first name');
        System.assertNotEquals(null, result[0].Reference_Last_Name__c, 'Should have last name');
    }
    
    @isTest
    static void testGetAppointmentRequestById_NotFound() {
        Id fakeId = 'a00000000000000';
        
        Test.startTest();
        List<Appointment_Request__c> result = AppointmentRequestSelector.getAppointmentRequestById(fakeId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
}
