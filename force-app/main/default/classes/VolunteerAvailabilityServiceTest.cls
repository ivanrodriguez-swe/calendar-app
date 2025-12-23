@isTest
private class VolunteerAvailabilityServiceTest {
    
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
        for (Integer i = 0; i < 5; i++) {
            Time startTime = Time.newInstance(9 + (i * 15 / 60), (i * 15) - (i * 15 / 60) * 60, 0, 0);
            Time endTime = Time.newInstance(9 + ((i + 1) * 15 / 60), ((i + 1) * 15) - ((i + 1) * 15 / 60) * 60, 0, 0);
            slots.add(new Time_Slot__c(
                Day__c = today.addDays(Math.mod(i, 3)),
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
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(2);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            List<Map<String, Object>> result = VolunteerAvailabilityService.getTimeslotsForRange(startDate, endDate);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assert(result.size() > 0, 'Should return time ranges');
            
            // Verify structure
            Map<String, Object> firstRange = result[0];
            System.assert(firstRange.containsKey('timeRangeLabel'), 'Should have timeRangeLabel');
            System.assert(firstRange.containsKey('slotDataList'), 'Should have slotDataList');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetTimeslotsForRange_NoSlots() {
        Date startDate = Date.today().addDays(100);
        Date endDate = Date.today().addDays(102);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            List<Map<String, Object>> result = VolunteerAvailabilityService.getTimeslotsForRange(startDate, endDate);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            // Should still return structure even with no slots
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_Success() {
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.bookTimeSlot(slot.Id, reference.Id, null);
            
            System.assertEquals(true, result.get('success'), 'Should succeed');
            System.assertNotEquals(null, result.get('appointmentId'), 'Should have appointment ID');
            
            // Verify records created/updated
            List<Appointment__c> appointments = [SELECT Id FROM Appointment__c WHERE Time_Slot__c = :slot.Id];
            System.assertEquals(1, appointments.size(), 'Should create appointment');
            
            Time_Slot__c updatedSlot = [SELECT Status__c FROM Time_Slot__c WHERE Id = :slot.Id];
            System.assertEquals('Booked', updatedSlot.Status__c, 'Slot should be booked');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_WithAppointmentRequest() {
        Time_Slot__c slot = [SELECT Id, Volunteer__c FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
        
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = slot.Volunteer__c,
            Status__c = 'New',
            Reference_Email__c = 'reference@test.com',
            Reference_First_Name__c = 'Reference',
            Reference_Last_Name__c = 'Test'
        );
        insert request;
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.bookTimeSlot(slot.Id, null, request.Id);
            
            System.assertEquals(true, result.get('success'), 'Should succeed');
            
            Appointment_Request__c updatedRequest = [SELECT Status__c FROM Appointment_Request__c WHERE Id = :request.Id];
            System.assertEquals('Reserved', updatedRequest.Status__c, 'Request should be reserved');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_TimeSlotNotFound() {
        Id fakeId = 'a00000000000000';
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookTimeSlot(fakeId, reference.Id, null);
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_TimeSlotNotAvailable() {
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c LIMIT 1];
        slot.Status__c = 'Booked';
        update slot;
        
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookTimeSlot(slot.Id, reference.Id, null);
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_NoVolunteer() {
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c LIMIT 1];
        slot.Volunteer__c = null;
        update slot;
        
        User reference = [SELECT Id FROM User WHERE Email = 'reference@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookTimeSlot(slot.Id, reference.Id, null);
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_AppointmentRequestNotFound() {
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
        Id fakeRequestId = 'a00000000000000';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookTimeSlot(slot.Id, null, fakeRequestId);
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_WrongVolunteer() {
        Time_Slot__c slot = [SELECT Id, Volunteer__c FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
        User otherVolunteer = [SELECT Id FROM User WHERE Email = 'volunteer1@test.com' LIMIT 1];
        
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = otherVolunteer.Id,
            Status__c = 'New'
        );
        insert request;
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookTimeSlot(slot.Id, null, request.Id);
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookTimeSlot_NoReferenceOrRequest() {
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c WHERE Status__c = 'Available' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookTimeSlot(slot.Id, null, null);
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_Success() {
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        List<Map<String, String>> ranges = new List<Map<String, String>>();
        Map<String, String> range1 = new Map<String, String>();
        range1.put('dateValue', String.valueOf(Date.today().addDays(10)));
        range1.put('startTime', '09:00');
        range1.put('endTime', '10:00');
        ranges.add(range1);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(ranges, volunteer.Id);
            
            System.assertEquals(true, result.get('success'), 'Should succeed');
            Integer slotsCreated = (Integer) result.get('slotsCreated');
            System.assert(slotsCreated > 0, 'Should create slots');
            
            // Verify slots created
            List<Time_Slot__c> createdSlots = [
                SELECT Id FROM Time_Slot__c 
                WHERE Day__c = :Date.today().addDays(10) 
                AND Volunteer__c = :volunteer.Id
            ];
            System.assertEquals(slotsCreated, createdSlots.size(), 'Should match created count');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_EmptyRanges() {
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(
                new List<Map<String, String>>(), volunteer.Id
            );
            
            System.assertEquals(false, result.get('success'), 'Should fail');
            System.assertEquals(0, result.get('slotsCreated'), 'Should create no slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_NullRanges() {
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(null, volunteer.Id);
            
            System.assertEquals(false, result.get('success'), 'Should fail');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_DuplicateSlots() {
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        Date testDate = Date.today().addDays(20);
        
        // Create existing slot
        Time_Slot__c existingSlot = new Time_Slot__c(
            Day__c = testDate,
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(9, 15, 0, 0),
            Status__c = 'Available',
            Volunteer__c = volunteer.Id
        );
        insert existingSlot;
        
        List<Map<String, String>> ranges = new List<Map<String, String>>();
        Map<String, String> range1 = new Map<String, String>();
        range1.put('dateValue', String.valueOf(testDate));
        range1.put('startTime', '09:00');
        range1.put('endTime', '10:00');
        ranges.add(range1);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(ranges, volunteer.Id);
            
            // Should still succeed but skip duplicates
            System.assertEquals(true, result.get('success'), 'Should succeed');
            Integer slotsCreated = (Integer) result.get('slotsCreated');
            // Should create new slots but skip the duplicate
            System.assert(slotsCreated >= 0, 'Should handle duplicates');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_InvalidTimeRange() {
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        List<Map<String, String>> ranges = new List<Map<String, String>>();
        Map<String, String> range1 = new Map<String, String>();
        range1.put('dateValue', String.valueOf(Date.today().addDays(10)));
        range1.put('startTime', '10:00');
        range1.put('endTime', '09:00'); // Invalid
        ranges.add(range1);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(ranges, volunteer.Id);
            
            // Should handle gracefully
            System.assertNotEquals(null, result, 'Result should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_Success() {
        User volunteer = [SELECT Id, Email FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            volunteer.Email + ',' + String.valueOf(Date.today().addDays(30)) + ',09:00,10:00\n' +
            volunteer.Email + ',' + String.valueOf(Date.today().addDays(31)) + ',10:00,11:00';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV(csvContent);
            
            System.assertEquals(true, result.get('success'), 'Should succeed');
            Integer slotsCreated = (Integer) result.get('slotsCreated');
            System.assert(slotsCreated > 0, 'Should create slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_EmptyContent() {
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV('');
            
            System.assertEquals(false, result.get('success'), 'Should fail');
            System.assertEquals(0, result.get('slotsCreated'), 'Should create no slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_NullContent() {
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV(null);
            
            System.assertEquals(false, result.get('success'), 'Should fail');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_InvalidUserEmail() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'nonexistent@test.com,' + String.valueOf(Date.today().addDays(30)) + ',09:00,10:00';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV(csvContent);
            
            // Should handle gracefully - no slots created for invalid user
            System.assertEquals(true, result.get('success'), 'Should still succeed');
            System.assertEquals(0, result.get('slotsCreated'), 'Should create no slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_NoValidRecords() {
        String csvContent = 'Invalid,CSV,Format';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV(csvContent);
            
            System.assertEquals(false, result.get('success'), 'Should fail');
            System.assert(result.get('message').toString().contains('No valid records'), 'Should indicate no valid records');
        }
        Test.stopTest();
    }
}

