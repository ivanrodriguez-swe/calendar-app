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
            
            Assert.isNotNull(null, result, 'Result should not be null');
            Assert.isTrue(result.size() > 0, 'Should return time ranges');
            
            // Verify structure
            Map<String, Object> firstRange = result[0];
            Assert.isTrue(firstRange.containsKey('timeRangeLabel'), 'Should have timeRangeLabel');
            Assert.isTrue(firstRange.containsKey('slotDataList'), 'Should have slotDataList');
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
            
            Assert.isNotNull(null, result, 'Result should not be null');
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
            
            Assert.areEqual(true, result.get('success'), 'Should succeed');
            Assert.isNotNull(null, result.get('appointmentId'), 'Should have appointment ID');
            
            // Verify records created/updated
            List<Appointment__c> appointments = [SELECT Id FROM Appointment__c WHERE Time_Slot__c = :slot.Id];
            Assert.areEqual(1, appointments.size(), 'Should create appointment');
            
            Time_Slot__c updatedSlot = [SELECT Status__c FROM Time_Slot__c WHERE Id = :slot.Id];
            Assert.areEqual('Booked', updatedSlot.Status__c, 'Slot should be booked');
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
            
            Assert.areEqual(true, result.get('success'), 'Should succeed');
            
            Appointment_Request__c updatedRequest = [SELECT Status__c FROM Appointment_Request__c WHERE Id = :request.Id];
            Assert.areEqual('Reserved', updatedRequest.Status__c, 'Request should be reserved');
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
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
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
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
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
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
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
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
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
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
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
                Assert.fail( 'Should have thrown exception');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException, 'Should throw AuraHandledException');
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
            
            Assert.areEqual(true, result.get('success'), 'Should succeed');
            Integer slotsCreated = (Integer) result.get('slotsCreated');
            Assert.isTrue(slotsCreated > 0, 'Should create slots');
            
            // Verify slots created
            List<Time_Slot__c> createdSlots = [
                SELECT Id FROM Time_Slot__c 
                WHERE Day__c = :Date.today().addDays(10) 
                AND Volunteer__c = :volunteer.Id
            ];
            Assert.areEqual(slotsCreated, createdSlots.size(), 'Should match created count');
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
            
            Assert.areEqual(false, result.get('success'), 'Should fail');
            Assert.areEqual(0, result.get('slotsCreated'), 'Should create no slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_NullRanges() {
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(null, volunteer.Id);
            
            Assert.areEqual(false, result.get('success'), 'Should fail');
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
            Assert.areEqual(true, result.get('success'), 'Should succeed');
            Integer slotsCreated = (Integer) result.get('slotsCreated');
            // Should create new slots but skip the duplicate
            Assert.isTrue(slotsCreated >= 0, 'Should handle duplicates');
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
            Assert.isNotNull(null, result, 'Result should not be null');
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
            
            Assert.areEqual(true, result.get('success'), 'Should succeed');
            Integer slotsCreated = (Integer) result.get('slotsCreated');
            Assert.isTrue(slotsCreated > 0, 'Should create slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_EmptyContent() {
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV('');
            
            Assert.areEqual(false, result.get('success'), 'Should fail');
            Assert.areEqual(0, result.get('slotsCreated'), 'Should create no slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_NullContent() {
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV(null);
            
            Assert.areEqual(false, result.get('success'), 'Should fail');
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
            Assert.areEqual(true, result.get('success'), 'Should still succeed');
            Assert.areEqual(0, result.get('slotsCreated'), 'Should create no slots');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromCSV_NoValidRecords() {
        String csvContent = 'Invalid,CSV,Format';
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromCSV(csvContent);
            
            Assert.areEqual(false, result.get('success'), 'Should fail');
            Assert.isTrue(result.get('message').toString().contains('No valid records'), 'Should indicate no valid records');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_Success() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, 0, 50);
            
            Assert.isNotNull(null, result, 'Result should not be null');
            List<Map<String, Object>> rows = (List<Map<String, Object>>) result.get('rows');
            Assert.isNotNull(null, rows, 'Rows should not be null');
            Assert.isTrue(rows.size() > 0, 'Should return rows');
            
            // Verify structure
            for (Map<String, Object> row : rows) {
                Assert.isNotNull(null, row.get('volunteerId'), 'Should have volunteerId');
                Assert.isNotNull(null, row.get('volunteerName'), 'Should have volunteerName');
                Assert.isNotNull(null, row.get('date'), 'Should have date');
                List<Map<String, Object>> timeSlots = (List<Map<String, Object>>) row.get('timeSlots');
                Assert.isNotNull(null, timeSlots, 'Should have timeSlots list');
            }
            
            Integer totalCount = (Integer) result.get('totalCount');
            Assert.isNotNull(null, totalCount, 'Should have totalCount');
            Assert.isTrue(totalCount >= rows.size(), 'Total count should be >= rows returned');
            
            Boolean hasMore = (Boolean) result.get('hasMore');
            Assert.isNotNull(null, hasMore, 'Should have hasMore flag');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_WithPagination() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            // Get first page
            Map<String, Object> result1 = VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, 0, 2);
            List<Map<String, Object>> rows1 = (List<Map<String, Object>>) result1.get('rows');
            
            // Get second page
            Map<String, Object> result2 = VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, 2, 2);
            List<Map<String, Object>> rows2 = (List<Map<String, Object>>) result2.get('rows');
            
            Assert.areEqual(2, rows1.size(), 'First page should return 2 rows');
            Assert.isTrue(rows2.size() <= 2, 'Second page should return <= 2 rows');
            
            Integer totalCount1 = (Integer) result1.get('totalCount');
            Integer totalCount2 = (Integer) result2.get('totalCount');
            Assert.areEqual(totalCount1, totalCount2, 'Total count should be same');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_SingleDate() {
        Date singleDate = Date.today();
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.getVolunteerAvailabilityData(singleDate, singleDate, 0, 50);
            
            Assert.isNotNull(null, result, 'Result should not be null');
            List<Map<String, Object>> rows = (List<Map<String, Object>>) result.get('rows');
            
            // Verify all rows are for the single date
            for (Map<String, Object> row : rows) {
                Date rowDate = (Date) row.get('date');
                Assert.areEqual(singleDate, rowDate, 'All rows should be for the single date');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_SortedByVolunteerThenDate() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, 0, 50);
            List<Map<String, Object>> rows = (List<Map<String, Object>>) result.get('rows');
            
            // Verify sorting: volunteer name, then date
            for (Integer i = 0; i < rows.size() - 1; i++) {
                Map<String, Object> current = rows[i];
                Map<String, Object> next = rows[i + 1];
                
                String currentName = (String) current.get('volunteerName');
                String nextName = (String) next.get('volunteerName');
                
                if (currentName != nextName) {
                    Assert.isTrue(currentName <= nextName, 'Should be sorted by volunteer name');
                } else {
                    Date currentDate = (Date) current.get('date');
                    Date nextDate = (Date) next.get('date');
                    Assert.isTrue(currentDate <= nextDate, 'Should be sorted by date when volunteer name is same');
                }
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_TimeSlotsFormatted() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, 0, 50);
            List<Map<String, Object>> rows = (List<Map<String, Object>>) result.get('rows');
            
            // Verify time slots have formatted labels
            for (Map<String, Object> row : rows) {
                List<Map<String, Object>> timeSlots = (List<Map<String, Object>>) row.get('timeSlots');
                for (Map<String, Object> slot : timeSlots) {
                    String timeLabel = (String) slot.get('timeLabel');
                    Assert.isNotNull(null, timeLabel, 'Time slot should have formatted label');
                    Assert.isTrue(timeLabel.contains('AM') || timeLabel.contains('PM'), 'Label should contain AM or PM');
                    Assert.isTrue(timeLabel.contains('-'), 'Label should contain time range separator');
                }
            }
        }
        Test.stopTest();
    }
}

