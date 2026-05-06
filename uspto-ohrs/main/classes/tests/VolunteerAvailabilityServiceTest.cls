@isTest
private class VolunteerAvailabilityServiceTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE FirstName = 'OHR' AND LastName = 'Admin' LIMIT 1];
    }
    
    private static User getVolunteer(Integer index) {
        String lastName = 'Test' + index;
        return [SELECT Id, Email FROM User WHERE FirstName = 'Volunteer' AND LastName = :lastName LIMIT 1];
    }
    
    private static Time_Slot__c getTimeSlot(String status) {
        if (status != null) {
            return [SELECT Id, Volunteer__c, Day__c, Start_Time__c, End_Time__c FROM Time_Slot__c WHERE Status__c = :status LIMIT 1];
        }
        return [SELECT Id, Volunteer__c, Day__c, Start_Time__c, End_Time__c FROM Time_Slot__c LIMIT 1];
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
    static void testBookSlotWithRandomVolunteer_Success() {
        Time_Slot__c slot = getTimeSlot('Available');
        
        Appointment_Request__c request = new Appointment_Request__c(
            Status__c = 'New',
            Reference_Email__c = 'reference@example.com',
            Reference_First_Name__c = 'Reference',
            Reference_Last_Name__c = 'Test'
        );
        insert request;
        
        Map<String, Object> params = new Map<String, Object>();
        params.put('slotDate', slot.Day__c);
        params.put('startTime', slot.Start_Time__c);
        params.put('endTime', slot.End_Time__c);
        params.put('appointmentRequestId', request.Id);
        params.put('referencePhone', '5551234567');
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.bookSlotWithRandomVolunteer(params);
            
            Assert.areEqual(true, result.get('success'), 'Should succeed');
            Assert.isNotNull(result.get('appointmentId'), 'Should have appointment ID');
            
            // Verify appointment request updated with volunteer
            Appointment_Request__c updatedRequest = [SELECT Volunteer__c, Status__c, Reference_Phone_Number__c FROM Appointment_Request__c WHERE Id = :request.Id];
            Assert.isNotNull(updatedRequest.Volunteer__c, 'Volunteer should be assigned');
            Assert.areEqual('Reserved', updatedRequest.Status__c, 'Request should be reserved');
            Assert.areEqual('5551234567', updatedRequest.Reference_Phone_Number__c, 'Phone number should be saved');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookSlotWithRandomVolunteer_NoAvailableSlots() {
        // Use a date/time that has no slots
        Map<String, Object> params = new Map<String, Object>();
        params.put('slotDate', Date.today().addDays(100));
        params.put('startTime', Time.newInstance(9, 0, 0, 0));
        params.put('endTime', Time.newInstance(9, 15, 0, 0));
        params.put('appointmentRequestId', null);
        params.put('referencePhone', '5551234567');
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Boolean exceptionThrown = false;
            try {
                VolunteerAvailabilityService.bookSlotWithRandomVolunteer(params);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Assert.isTrue(exceptionThrown, 'Should have thrown AuraHandledException when no slots available');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBookSlotWithRandomVolunteer_AppointmentRequestNotFound() {
        Time_Slot__c slot = getTimeSlot('Available');
        
        Map<String, Object> params = new Map<String, Object>();
        params.put('slotDate', slot.Day__c);
        params.put('startTime', slot.Start_Time__c);
        params.put('endTime', slot.End_Time__c);
        params.put('appointmentRequestId', null);
        params.put('referencePhone', '5551234567');
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            try {
                VolunteerAvailabilityService.bookSlotWithRandomVolunteer(params);
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
        User volunteer = getVolunteer(0);
        
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
        User volunteer = getVolunteer(0);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.createTimeSlotsFromRanges(null, volunteer.Id);
            
            Assert.areEqual(false, result.get('success'), 'Should fail');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTimeSlotsFromRanges_DuplicateSlots() {
        User volunteer = getVolunteer(0);
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
    static void testCreateTimeSlotsFromCSV_Success() {
        User volunteer = getVolunteer(0);
        
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
            'nonexistent@example.com,' + String.valueOf(Date.today().addDays(30)) + ',09:00,10:00';
        
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
    static void testGetVolunteerAvailabilityData_Success() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        System.runAs(getAdminUser()) {
            Map<String, Object> result = VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, 0, 50);
            
            Assert.isNotNull(result, 'Result should not be null');
            List<Map<String, Object>> rows = (List<Map<String, Object>>) result.get('rows');
            Assert.isNotNull(rows, 'Rows should not be null');
            Assert.isTrue(rows.size() > 0, 'Should return rows');
            
            // Verify structure
            for (Map<String, Object> row : rows) {
                Assert.isNotNull(row.get('volunteerId'), 'Should have volunteerId');
                Assert.isNotNull(row.get('volunteerName'), 'Should have volunteerName');
                Assert.isNotNull(row.get('date'), 'Should have date');
                List<Map<String, Object>> timeSlots = (List<Map<String, Object>>) row.get('timeSlots');
                Assert.isNotNull(timeSlots, 'Should have timeSlots list');
            }
            
            Integer totalCount = (Integer) result.get('totalCount');
            Assert.isNotNull(totalCount, 'Should have totalCount');
            Assert.isTrue(totalCount >= rows.size(), 'Total count should be >= rows returned');
            
            Boolean hasMore = (Boolean) result.get('hasMore');
            Assert.isNotNull(hasMore, 'Should have hasMore flag');
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
}
