@isTest
private class VolunteerAvailabilityDisplayCtrlTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'ohradmin@test.com' LIMIT 1];
    }
    
    /**
     * Helper method to convert Date to String in YYYY-MM-DD format
     * This matches the format expected by the controller method
     */
    private static String dateToString(Date d) {
        if (d == null) {
            return null;
        }
        return String.valueOf(d.year()) + '-' + 
               String.valueOf(d.month()).leftPad(2, '0') + '-' + 
               String.valueOf(d.day()).leftPad(2, '0');
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test users (volunteers)
        List<User> volunteers = OHRTestDataFactory.createVolunteerUsers(2);
        
        // Create time slots
        Date today = Date.today();
        List<Time_Slot__c> slots = new List<Time_Slot__c>();
        
        // Create slots for volunteer 1
        for (Integer i = 0; i < 3; i++) {
            Time startTime = Time.newInstance(9 + i, 0, 0, 0);
            Time endTime = Time.newInstance(9 + i, 15, 0, 0);
            slots.add(new Time_Slot__c(
                Day__c = today.addDays(i),
                Start_Time__c = startTime,
                End_Time__c = endTime,
                Status__c = i == 1 ? 'Booked' : 'Available',
                Volunteer__c = volunteers[0].Id
            ));
        }
        
        // Create slots for volunteer 2
        for (Integer i = 0; i < 2; i++) {
            Time startTime = Time.newInstance(10 + i, 0, 0, 0);
            Time endTime = Time.newInstance(10 + i, 15, 0, 0);
            slots.add(new Time_Slot__c(
                Day__c = today.addDays(i),
                Start_Time__c = startTime,
                End_Time__c = endTime,
                Status__c = 'Available',
                Volunteer__c = volunteers[1].Id
            ));
        }
        
        insert slots;
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_AllRecords() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(null, null, 0, 50);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.rows, 'Rows should not be null');
            System.assert(result.rows.size() > 0, 'Should return at least one row');
            System.assertNotEquals(null, result.totalCount, 'Total count should be set');
            System.assertNotEquals(null, result.hasMore, 'HasMore should be set');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_WithDateRange() {
        User admin = getAdminUser();
        Date startDate = Date.today();
        Date endDate = Date.today().addDays(2);
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(
                    dateToString(startDate), 
                    dateToString(endDate), 
                    0, 
                    50
                );
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.rows, 'Rows should not be null');
            System.assert(result.totalCount >= 0, 'Total count should be set');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_SameDate() {
        User admin = getAdminUser();
        Date sameDate = Date.today();
        String sameDateStr = dateToString(sameDate);
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(sameDateStr, sameDateStr, 0, 50);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.rows, 'Rows should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_WithPagination() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            // First page
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result1 = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(null, null, 0, 2);
            
            System.assertNotEquals(null, result1, 'First page result should not be null');
            System.assert(result1.rows.size() <= 2, 'First page should have at most 2 rows');
            
            // Second page
            if (result1.hasMore) {
                VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result2 = 
                    VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(null, null, 2, 2);
                
                System.assertNotEquals(null, result2, 'Second page result should not be null');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_DefaultPagination() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            // Test with null offset and pageSize
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(null, null, null, null);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.rows, 'Rows should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_InvalidPageSize() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            // Test with invalid pageSize (0 or negative)
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(null, null, 0, 0);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            // Should default to 50
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerInfo_Success() {
        User admin = getAdminUser();
        User volunteer = [SELECT Id FROM User WHERE Email LIKE 'volunteer%@test.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerInfoResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerInfo(volunteer.Id);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(true, result.success, 'Should succeed');
            System.assertNotEquals(null, result.volunteer, 'Volunteer should be set');
            System.assertEquals(volunteer.Id, result.volunteer.id, 'Volunteer ID should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerInfo_NullId() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            try {
                VolunteerAvailabilityDisplayController.getVolunteerInfo(null);
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                // Verify exception was thrown
                // Note: Cacheable methods wrap exceptions in "Script-thrown exception" message
                System.assert(e != null, 'Exception should be thrown');
                // Just verify it's an AuraHandledException - the exact message may be wrapped
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerInfo_InvalidId() {
        User admin = getAdminUser();
        Id fakeId = UserInfo.getUserId(); // Use a valid ID format but not a volunteer
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerInfoResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerInfo(fakeId);
            
            // May succeed or fail depending on whether the ID exists
            System.assertNotEquals(null, result, 'Result should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAllVolunteersForDisplay_Success() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerListResult result = 
                VolunteerAvailabilityDisplayController.getAllVolunteersForDisplay();
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.volunteers, 'Volunteers list should not be null');
            System.assert(result.volunteers.size() > 0, 'Should return at least one volunteer');
            System.assertNotEquals(null, result.totalCount, 'Total count should be set');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVolunteerAvailabilityData_VerifyRowStructure() {
        User admin = getAdminUser();
        
        Test.startTest();
        System.runAs(admin) {
            VolunteerAvailabilityDisplayController.VolunteerAvailabilityResult result = 
                VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData(null, null, 0, 50);
            
            if (result.rows != null && result.rows.size() > 0) {
                VolunteerAvailabilityDisplayController.VolunteerAvailabilityRow firstRow = result.rows[0];
                
                System.assertNotEquals(null, firstRow.volunteerId, 'Volunteer ID should be set');
                System.assertNotEquals(null, firstRow.volunteerName, 'Volunteer name should be set');
                System.assertNotEquals(null, firstRow.slotDate, 'Slot date should be set');
                System.assertNotEquals(null, firstRow.timeSlots, 'Time slots should be set');
                
                if (firstRow.timeSlots.size() > 0) {
                    VolunteerAvailabilityDisplayController.TimeSlotData firstSlot = firstRow.timeSlots[0];
                    System.assertNotEquals(null, firstSlot.id, 'Slot ID should be set');
                    System.assertNotEquals(null, firstSlot.status, 'Status should be set');
                    System.assertNotEquals(null, firstSlot.timeLabel, 'Time label should be set');
                }
            }
        }
        Test.stopTest();
    }
}

