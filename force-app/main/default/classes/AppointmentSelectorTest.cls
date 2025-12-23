@isTest
private class AppointmentSelectorTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test volunteer user
        User volunteer = OHRTestDataFactory.createVolunteerUser(0);
        
        // Create time slot
        Time_Slot__c slot = new Time_Slot__c(
            Day__c = Date.today(),
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(9, 15, 0, 0),
            Status__c = 'Available',
            Volunteer__c = volunteer.Id
        );
        insert slot;
        
        // Create appointment request
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = volunteer.Id,
            Status__c = 'New'
        );
        insert request;
        
        // Create appointments
        List<Appointment__c> appointments = new List<Appointment__c>();
        for (Integer i = 0; i < 3; i++) {
            appointments.add(new Appointment__c(
                Appointment_Request__c = request.Id,
                Time_Slot__c = slot.Id,
                Status__c = 'Confirmed'
            ));
        }
        insert appointments;
    }
    
    @isTest
    static void testGetAppointmentById_Success() {
        Appointment__c appointment = [SELECT Id FROM Appointment__c LIMIT 1];
        
        Test.startTest();
        List<Appointment__c> result = AppointmentSelector.getAppointmentById(appointment.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return one appointment');
        System.assertEquals(appointment.Id, result[0].Id, 'Should return correct appointment');
        System.assertNotEquals(null, result[0].Appointment_Request__c, 'Should have appointment request');
        System.assertNotEquals(null, result[0].Time_Slot__c, 'Should have time slot');
    }
    
    @isTest
    static void testGetAppointmentById_NotFound() {
        Id fakeId = 'a00000000000000';
        
        Test.startTest();
        List<Appointment__c> result = AppointmentSelector.getAppointmentById(fakeId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
}

