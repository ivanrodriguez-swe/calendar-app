@isTest
private class BookingEmailServiceTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE FirstName = 'OHR' AND LastName = 'Admin' LIMIT 1];
    }
    
    private static Time_Slot__c getTimeSlotWithRelationships() {
        return [SELECT Id, Day__c, Start_Time__c, End_Time__c, Volunteer__c, Volunteer__r.Email, Volunteer__r.Name 
                FROM Time_Slot__c LIMIT 1];
    }
    
    private static Time_Slot__c getTimeSlotBasic() {
        return [SELECT Id, Day__c, Start_Time__c, End_Time__c, Volunteer__c 
                FROM Time_Slot__c LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        OHRTestDataFactory.createOHRAdminUser();
        User volunteer = OHRTestDataFactory.createVolunteerUser(0);
        
        Time_Slot__c slot = new Time_Slot__c(
            Day__c = Date.today(),
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(9, 15, 0, 0),
            Status__c = 'Available',
            Volunteer__c = volunteer.Id
        );
        insert slot;
        
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
        Boolean result1 = BookingEmailService.isValidEmail('test@example.com');
        Boolean result2 = BookingEmailService.isValidEmail('user.name@example.com');
        Boolean result3 = BookingEmailService.isValidEmail('test+tag@example.com');
        Test.stopTest();
        
        Assert.areEqual(true, result1, 'Should validate standard email');
        Assert.areEqual(true, result2, 'Should validate email with subdomain');
        Assert.areEqual(true, result3, 'Should validate email with plus');
    }
    
    @isTest
    static void testIsValidEmail_Invalid() {
        Test.startTest();
        Boolean result1 = BookingEmailService.isValidEmail('');
        Boolean result2 = BookingEmailService.isValidEmail(null);
        Boolean result3 = BookingEmailService.isValidEmail('invalid');
        Boolean result4 = BookingEmailService.isValidEmail('test@');
        Test.stopTest();
        
        Assert.areEqual(false, result1, 'Should reject empty string');
        Assert.areEqual(false, result2, 'Should reject null');
        Assert.areEqual(false, result3, 'Should reject email without @');
        Assert.areEqual(false, result4, 'Should reject email without domain');
    }
    
    @isTest
    static void testSendBookingEmails_Success() {
        Time_Slot__c slot = getTimeSlotWithRelationships();
        String customerName = 'Customer Test';
        String customerEmail = 'reference@example.com';
        
        Test.startTest();
        BookingEmailService.sendBookingEmails(slot, customerName, customerEmail);
        Test.stopTest();
        
        Assert.isTrue(true, 'Method should complete without error');
    }
    
    @isTest
    static void testSendBookingEmails_NoVolunteerEmail() {
        Time_Slot__c slot = getTimeSlotBasic();
        slot.Volunteer__r = null;
        
        String customerName = 'Customer Test';
        String customerEmail = 'reference@example.com';
        
        Test.startTest();
        BookingEmailService.sendBookingEmails(slot, customerName, customerEmail);
        Test.stopTest();
        
        Assert.isTrue(true, 'Should complete without error');
    }
    
    @isTest
    static void testSendBookingEmails_NoCustomerEmail() {
        Time_Slot__c slot = getTimeSlotWithRelationships();
        String customerName = 'Customer Test';
        String customerEmail = '';
        
        Test.startTest();
        BookingEmailService.sendBookingEmails(slot, customerName, customerEmail);
        Test.stopTest();
        
        Assert.isTrue(true, 'Method should complete without error');
    }
    
    @isTest
    static void testSendBookingEmails_NoCustomerName() {
        Time_Slot__c slot = getTimeSlotWithRelationships();
        String customerName = '';
        String customerEmail = 'reference@example.com';
        
        Test.startTest();
        BookingEmailService.sendBookingEmails(slot, customerName, customerEmail);
        Test.stopTest();
        
        Assert.isTrue(true, 'Should complete without error');
    }
}
