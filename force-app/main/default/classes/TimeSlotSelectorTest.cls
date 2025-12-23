@isTest
private class TimeSlotSelectorTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test volunteer user
        User volunteer = OHRTestDataFactory.createVolunteerUser(0);
        
        // Create time slots
        Date today = Date.today();
        List<Time_Slot__c> slots = new List<Time_Slot__c>();
        
        // Available slots
        for (Integer i = 0; i < 5; i++) {
            Time startTime = Time.newInstance(9 + (i * 15 / 60), (i * 15) - (i * 15 / 60) * 60, 0, 0);
            Time endTime = Time.newInstance(9 + ((i + 1) * 15 / 60), ((i + 1) * 15) - ((i + 1) * 15 / 60) * 60, 0, 0);
            slots.add(new Time_Slot__c(
                Day__c = today.addDays(i),
                Start_Time__c = startTime,
                End_Time__c = endTime,
                Status__c = 'Available',
                Volunteer__c = volunteer.Id
            ));
        }
        
        // Booked slots
        for (Integer i = 0; i < 3; i++) {
            Time startTime = Time.newInstance(10 + (i * 15 / 60), (i * 15) - (i * 15 / 60) * 60, 0, 0);
            Time endTime = Time.newInstance(10 + ((i + 1) * 15 / 60), ((i + 1) * 15) - ((i + 1) * 15 / 60) * 60, 0, 0);
            slots.add(new Time_Slot__c(
                Day__c = today.addDays(i),
                Start_Time__c = startTime,
                End_Time__c = endTime,
                Status__c = 'Booked',
                Volunteer__c = volunteer.Id
            ));
        }
        
        insert slots;
    }
    
    @isTest
    static void testGetAvailableTimeSlotsForRange_Success() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getAvailableTimeSlotsForRange(startDate, endDate);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(5, result.size(), 'Should return 5 available slots');
        
        // Verify all are available
        for (Time_Slot__c slot : result) {
            System.assertEquals('Available', slot.Status__c, 'All slots should be available');
            System.assert(slot.Day__c >= startDate && slot.Day__c <= endDate, 'Should be in date range');
        }
    }
    
    @isTest
    static void testGetAvailableTimeSlotsForRange_NoResults() {
        Date startDate = Date.today().addDays(100);
        Date endDate = Date.today().addDays(104);
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getAvailableTimeSlotsForRange(startDate, endDate);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return no slots');
    }
    
    @isTest
    static void testGetAvailableTimeSlotsForRange_ExcludesBooked() {
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(4);
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getAvailableTimeSlotsForRange(startDate, endDate);
        Test.stopTest();
        
        // Should only return available slots, not booked ones
        System.assertEquals(5, result.size(), 'Should only return available slots');
        for (Time_Slot__c slot : result) {
            System.assertEquals('Available', slot.Status__c, 'Should only return available slots');
        }
    }
    
    @isTest
    static void testGetTimeSlotById_Success() {
        Time_Slot__c slot = [SELECT Id FROM Time_Slot__c LIMIT 1];
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getTimeSlotById(slot.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return one slot');
        System.assertEquals(slot.Id, result[0].Id, 'Should return correct slot');
        System.assertNotEquals(null, result[0].Volunteer__c, 'Should have volunteer');
    }
    
    @isTest
    static void testGetTimeSlotById_NotFound() {
        Id fakeId = 'a00000000000000';
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getTimeSlotById(fakeId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testGetExistingTimeSlotsByDatesAndVolunteers_Success() {
        Date testDate = Date.today();
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        Set<Date> dates = new Set<Date>{ testDate };
        Set<Id> volunteerIds = new Set<Id>{ volunteer.Id };
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getExistingTimeSlotsByDatesAndVolunteers(dates, volunteerIds);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return slots');
        
        for (Time_Slot__c slot : result) {
            System.assert(dates.contains(slot.Day__c), 'Should match date');
            System.assert(volunteerIds.contains(slot.Volunteer__c), 'Should match volunteer');
        }
    }
    
    @isTest
    static void testGetExistingTimeSlotsByDatesAndVolunteers_NoMatches() {
        Date testDate = Date.today().addDays(100);
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        Set<Date> dates = new Set<Date>{ testDate };
        Set<Id> volunteerIds = new Set<Id>{ volunteer.Id };
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getExistingTimeSlotsByDatesAndVolunteers(dates, volunteerIds);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return no slots');
    }
    
    @isTest
    static void testGetExistingTimeSlotsByDatesAndVolunteers_MultipleDates() {
        Date date1 = Date.today();
        Date date2 = Date.today().addDays(1);
        User volunteer = [SELECT Id FROM User WHERE Email = 'volunteer0@test.com' LIMIT 1];
        Set<Date> dates = new Set<Date>{ date1, date2 };
        Set<Id> volunteerIds = new Set<Id>{ volunteer.Id };
        
        Test.startTest();
        List<Time_Slot__c> result = TimeSlotSelector.getExistingTimeSlotsByDatesAndVolunteers(dates, volunteerIds);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return slots for multiple dates');
    }
}

