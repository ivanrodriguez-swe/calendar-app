@isTest
private class VolunteerAvailabilityControllerTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test users (volunteers)
        List<User> volunteers = OHRTestDataFactory.createVolunteerUsers(3);
        
        // Create test reference user
        User reference = OHRTestDataFactory.createReferenceUser();
        
        // Create time slots
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
    static void testGetTimeslotsForRange_Success() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(2);
        
        Test.startTest();
        System.runAs(admin) {
            List<VolunteerAvailabilityController.DayWrapper> result = 
                VolunteerAvailabilityController.getTimeslotsForRange(startDate, endDate);
            
            Assert.isNotNull(null, result, 'Result should not be null');
            Assert.isTrue(result.size() > 0, 'Should return at least one day wrapper');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetTimeslotsForRange_NullStartDate() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        Date endDate = Date.today();
        
        Test.startTest();
        System.runAs(admin) {
            try {
                VolunteerAvailabilityController.getTimeslotsForRange(null, endDate);
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetTimeslotsForRange_NullEndDate() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        Date startDate = Date.today();
        
        Test.startTest();
        System.runAs(admin) {
            try {
                VolunteerAvailabilityController.getTimeslotsForRange(startDate, null);
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_Success() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c LIMIT 1];
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.BookingResult result = 
                VolunteerAvailabilityController.bookTimeSlot(slot.Id, reference.Id, null);
            
            Assert.areEqual(true, result.success, 'Booking should succeed');
            Assert.isNotNull(null, result.appointmentId, 'Appointment ID should be set');
            
            // Verify slot status updated
            Time_Slot__c updatedSlot = [SELECT Status__c FROM Time_Slot__c WHERE Id = :slot.Id];
            Assert.areEqual('Booked', updatedSlot.Status__c, 'Slot status should be Booked');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_WithAppointmentRequest() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        Time_Slot__c slot = [SELECT Id, Volunteer__c FROM Time_Slot__c LIMIT 1];
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        
        // Create appointment request
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = slot.Volunteer__c,
            Status__c = 'New',
            Reference_Email__c = 'reference@test.com',
            Reference_First_Name__c = 'Reference',
            Reference_Last_Name__c = 'Test'
        );
        insert request;
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.BookingResult result = 
                VolunteerAvailabilityController.bookTimeSlot(slot.Id, null, request.Id);
            
            Assert.areEqual(true, result.success, 'Booking should succeed');
            
            // Verify appointment request status updated
            Appointment_Request__c updatedRequest = [SELECT Status__c FROM Appointment_Request__c WHERE Id = :request.Id];
            Assert.areEqual('Reserved', updatedRequest.Status__c, 'Request status should be Reserved');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_InvalidTimeSlot() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        Id fakeId = 'a00000000000000';
        
        Test.startTest();
        System.runAs(admin) {
            try {
                VolunteerAvailabilityController.bookTimeSlot(fakeId, reference.Id, null);
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_Success() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        List<VolunteerAvailabilityController.AvailabilityRange> ranges = 
            new List<VolunteerAvailabilityController.AvailabilityRange>();
        
        VolunteerAvailabilityController.AvailabilityRange range1 = 
            new VolunteerAvailabilityController.AvailabilityRange();
        range1.dateValue = String.valueOf(Date.today().addDays(10));
        range1.startTime = '09:00';
        range1.endTime = '10:00';
        ranges.add(range1);
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromRanges(ranges);
            
            Assert.areEqual(true, result.success, 'Should succeed');
            Assert.isTrue(result.slotsCreated > 0, 'Should create slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_EmptyRanges() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        List<VolunteerAvailabilityController.AvailabilityRange> ranges = 
            new List<VolunteerAvailabilityController.AvailabilityRange>();
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromRanges(ranges);
            
            Assert.areEqual(false, result.success, 'Should fail with empty ranges');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_InvalidTimeRange() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        List<VolunteerAvailabilityController.AvailabilityRange> ranges = 
            new List<VolunteerAvailabilityController.AvailabilityRange>();
        
        VolunteerAvailabilityController.AvailabilityRange range1 = 
            new VolunteerAvailabilityController.AvailabilityRange();
        range1.dateValue = String.valueOf(Date.today().addDays(10));
        range1.startTime = '10:00';
        range1.endTime = '09:00'; // Invalid: end before start
        ranges.add(range1);
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromRanges(ranges);
            
            // Should handle gracefully
            Assert.isNotNull(null, result, 'Result should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_Success() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        User volunteer = [SELECT Id, Email FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            volunteer.Email + ',' + String.valueOf(Date.today().addDays(10)) + ',09:00,10:00\n' +
            volunteer.Email + ',' + String.valueOf(Date.today().addDays(11)) + ',10:00,11:00';
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromCSV(csvContent);
            
            Assert.areEqual(true, result.success, 'Should succeed');
            Assert.isTrue(result.slotsCreated > 0, 'Should create slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_EmptyContent() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromCSV('');
            
            Assert.areEqual(false, result.success, 'Should fail with empty content');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_InvalidFormat() {
        User admin = [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
        String csvContent = 'Invalid,CSV,Format';
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityController.CreateSlotsResult result = 
                VolunteerAvailabilityController.createTimeSlotsFromCSV(csvContent);
            
            // Should handle gracefully
            Assert.isNotNull(null, result, 'Result should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testWrapperClasses() {
        // Test DayWrapper
        VolunteerAvailabilityController.DayWrapper dw = 
            new VolunteerAvailabilityController.DayWrapper('09:00-09:15');
        Assert.areEqual('09:00-09:15', dw.label, 'Label should match');
        Assert.isNotNull(null, dw.slots, 'Slots list should be initialized');
        
        // Test TimeslotWrapper - available slot
        Date testDate = Date.today();
        Time startTime = Time.newInstance(9, 0, 0, 0);
        Time endTime = Time.newInstance(9, 15, 0, 0);
        User volunteer = [SELECT Id, Name FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        VolunteerAvailabilityController.TimeslotWrapper tw1 = 
            new VolunteerAvailabilityController.TimeslotWrapper(
                'a00000000000000', startTime, endTime, testDate, volunteer.Id, volunteer.Name
            );
        Assert.areEqual(true, tw1.isAvailable, 'Should be available');
        Assert.areEqual(false, tw1.isUnavailable, 'Should not be unavailable');
        
        // Test TimeslotWrapper - unavailable slot
        VolunteerAvailabilityController.TimeslotWrapper tw2 = 
            new VolunteerAvailabilityController.TimeslotWrapper('09:00-09:15', testDate);
        Assert.areEqual(false, tw2.isAvailable, 'Should not be available');
        Assert.areEqual(true, tw2.isUnavailable, 'Should be unavailable');
        
        // Test BookingResult
        VolunteerAvailabilityController.BookingResult br = 
            new VolunteerAvailabilityController.BookingResult(true, 'Success', 'a00000000000000');
        Assert.areEqual(true, br.success, 'Success should match');
        Assert.areEqual('Success', br.message, 'Message should match');
        
        // Test CreateSlotsResult - default constructor
        VolunteerAvailabilityController.CreateSlotsResult csr1 = 
            new VolunteerAvailabilityController.CreateSlotsResult();
        Assert.areEqual(false, csr1.success, 'Default success should be false');
        Assert.areEqual(0, csr1.slotsCreated, 'Default slots created should be 0');
        
        // Test CreateSlotsResult - parameterized constructor
        VolunteerAvailabilityController.CreateSlotsResult csr2 = 
            new VolunteerAvailabilityController.CreateSlotsResult(true, 'Success', 5);
        Assert.areEqual(true, csr2.success, 'Success should match');
        Assert.areEqual(5, csr2.slotsCreated, 'Slots created should match');
    }
}

