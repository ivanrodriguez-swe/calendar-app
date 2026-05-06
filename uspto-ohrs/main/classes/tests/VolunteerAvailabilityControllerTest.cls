@isTest
private class VolunteerAvailabilityControllerTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE FirstName = 'OHR' AND LastName = 'Admin' LIMIT 1];
    }
    
    private static User getVolunteer(Integer index) {
        String lastName = 'Test' + index;
        return [SELECT Id, Name, Email FROM User WHERE FirstName = 'Volunteer' AND LastName = :lastName LIMIT 1];
    }
    
    private static Time_Slot__c getTimeSlot() {
        return [SELECT Id, Volunteer__c, Day__c, Start_Time__c, End_Time__c FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
    }
    
    private static Long timeToMillis(Time t) {
        return ((t.hour() * 60 + t.minute()) * 60 + t.second()) * 1000L;
    }
    
    @TestSetup
    static void setupTestData() {
        OHRTestDataFactory.createOHRAdminUser();
        List<User> volunteers = OHRTestDataFactory.createVolunteerUsers(3);
        User reference = OHRTestDataFactory.createReferenceUser();
        
        Date today = Date.today();
        List<Time_Slot__c> slots = new List<Time_Slot__c>();
        for (Integer i = 0; i < 3; i++) {
            Time startTime = Time.newInstance(9 + i, 0, 0, 0);
            Time endTime = Time.newInstance(9 + i, 15, 0, 0);
            slots.add(new Time_Slot__c(
                Day__c = today.addDays(i),
                Start_Time__c = startTime,
                End_Time__c = endTime,
                Status__c = 'Available',
                Volunteer__c = volunteers[0].Id
            ));
        }
        insert slots;
    }
    
    @isTest
    static void testGetAllAvailableSlots_Success() {
        Test.startTest();
        System.runAs(getAdminUser()) {
            List<VolunteerAvailabilityController.AvailableSlotWrapper> result = 
                VolunteerAvailabilityController.getAllAvailableSlots();
            
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isTrue(result.size() > 0, 'Should return available slots');
            
            for (VolunteerAvailabilityController.AvailableSlotWrapper slot : result) {
                Assert.isNotNull(slot.id, 'Should have slot ID');
                Assert.isNotNull(slot.day, 'Should have day');
                Assert.isNotNull(slot.startTime, 'Should have start time');
                Assert.isNotNull(slot.endTime, 'Should have end time');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookSlotWithRandomVolunteer_Success() {
        Time_Slot__c slot = getTimeSlot();
        
        Appointment_Request__c request = new Appointment_Request__c(
            Status__c = 'New',
            Reference_Email__c = 'reference@example.com',
            Reference_First_Name__c = 'Reference',
            Reference_Last_Name__c = 'Test'
        );
        insert request;
        
        VolunteerAvailabilityController.BookingRequest bookingRequest = 
            new VolunteerAvailabilityController.BookingRequest();
        bookingRequest.slotDate = String.valueOf(slot.Day__c);
        bookingRequest.startTime = timeToMillis(slot.Start_Time__c);
        bookingRequest.endTime = timeToMillis(slot.End_Time__c);
        bookingRequest.appointmentRequestId = request.Id;
        bookingRequest.referencePhone = '5559876543';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            VolunteerAvailabilityController.BookingResult result = 
                VolunteerAvailabilityController.bookSlotWithRandomVolunteer(bookingRequest);
            
            Assert.areEqual(true, result.success, 'Booking should succeed');
            Assert.isNotNull(result.appointmentId, 'Should have appointment ID');
            
            Appointment_Request__c updatedRequest = [SELECT Status__c, Volunteer__c, Reference_Phone_Number__c FROM Appointment_Request__c WHERE Id = :request.Id];
            Assert.areEqual('Reserved', updatedRequest.Status__c, 'Request status should be Reserved');
            Assert.isNotNull(updatedRequest.Volunteer__c, 'Volunteer should be assigned');
            Assert.areEqual('5559876543', updatedRequest.Reference_Phone_Number__c, 'Phone number should be saved');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookSlotWithRandomVolunteer_NoAvailableSlots() {
        VolunteerAvailabilityController.BookingRequest bookingRequest = 
            new VolunteerAvailabilityController.BookingRequest();
        bookingRequest.slotDate = String.valueOf(Date.today().addDays(100));
        bookingRequest.startTime = timeToMillis(Time.newInstance(9, 0, 0, 0));
        bookingRequest.endTime = timeToMillis(Time.newInstance(9, 15, 0, 0));
        bookingRequest.appointmentRequestId = null;
        bookingRequest.referencePhone = '5551234567';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityController.bookSlotWithRandomVolunteer(bookingRequest);
                Assert.fail('Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException.class, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_Success() {
        User volunteer = getVolunteer(0);
        
        List<VolunteerAvailabilityController.AvailabilityRange> ranges = 
            new List<VolunteerAvailabilityController.AvailabilityRange>();
        
        VolunteerAvailabilityController.AvailabilityRange range1 = 
            new VolunteerAvailabilityController.AvailabilityRange();
        range1.dateValue = String.valueOf(Date.today().addDays(10));
        range1.startTime = '09:00';
        range1.endTime = '10:00';
        ranges.add(range1);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromRanges(ranges);
            
            Assert.areEqual(true, result.success, 'Should succeed');
            Assert.isTrue(result.slotsCreated > 0, 'Should create slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_EmptyRanges() {
        List<VolunteerAvailabilityController.AvailabilityRange> ranges = 
            new List<VolunteerAvailabilityController.AvailabilityRange>();
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromRanges(ranges);
            
            Assert.areEqual(false, result.success, 'Should fail with empty ranges');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_Success() {
        User volunteer = getVolunteer(0);
        
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            volunteer.Email + ',' + String.valueOf(Date.today().addDays(10)) + ',09:00,10:00\n' +
            volunteer.Email + ',' + String.valueOf(Date.today().addDays(11)) + ',10:00,11:00';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromCSV(csvContent);
            
            Assert.areEqual(true, result.success, 'Should succeed');
            Assert.isTrue(result.slotsCreated > 0, 'Should create slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_EmptyContent() {
        Test.startTest();
        System.runAs(getAdminUser()) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromCSV('');
            
            Assert.areEqual(false, result.success, 'Should fail with empty content');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testWrapperClasses() {
        Time_Slot__c testSlot = [SELECT Id, Volunteer__c, Volunteer__r.Name, Day__c, Start_Time__c, End_Time__c FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
        VolunteerAvailabilityController.AvailableSlotWrapper wrapper = 
            new VolunteerAvailabilityController.AvailableSlotWrapper(testSlot);
        Assert.isNotNull(wrapper.id, 'Should have ID');
        Assert.isNotNull(wrapper.day, 'Should have day');
        
        VolunteerAvailabilityController.BookingResult br = 
            new VolunteerAvailabilityController.BookingResult(true, 'Success', testSlot.Id);
        Assert.areEqual(true, br.success, 'Success should match');
        Assert.areEqual('Success', br.message, 'Message should match');
        
        VolunteerAvailabilityController.BookingRequest bookReq = 
            new VolunteerAvailabilityController.BookingRequest();
        bookReq.slotDate = String.valueOf(Date.today());
        bookReq.startTime = timeToMillis(Time.newInstance(9, 0, 0, 0));
        bookReq.endTime = timeToMillis(Time.newInstance(9, 15, 0, 0));
        bookReq.appointmentRequestId = null;
        bookReq.referencePhone = '5551234567';
        Assert.isNotNull(bookReq.slotDate, 'Should have slotDate');
        
        VolunteerAvailabilityController.AvailabilityRange range = 
            new VolunteerAvailabilityController.AvailabilityRange();
        range.dateValue = '2025-01-15';
        range.startTime = '09:00';
        range.endTime = '10:00';
        Assert.isNotNull(range.dateValue, 'Should have dateValue');
        
        VolunteerAvailabilityController.CreateSlotsResult csr1 = 
            new VolunteerAvailabilityController.CreateSlotsResult();
        Assert.areEqual(false, csr1.success, 'Default success should be false');
        Assert.areEqual(0, csr1.slotsCreated, 'Default slots created should be 0');
        
        VolunteerAvailabilityController.CreateSlotsResult csr2 = 
            new VolunteerAvailabilityController.CreateSlotsResult(true, 'Success', 5);
        Assert.areEqual(true, csr2.success, 'Success should match');
        Assert.areEqual(5, csr2.slotsCreated, 'Slots created should match');
        
        List<String> warnings = new List<String>{ 'Warning 1' };
        VolunteerAvailabilityController.CreateSlotsResult csr3 = 
            new VolunteerAvailabilityController.CreateSlotsResult(true, 'Success', 5, warnings);
        Assert.areEqual(1, csr3.warnings.size(), 'Should have warnings');
    }
}
