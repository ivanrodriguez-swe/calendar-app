@isTest
private class OHRUserSelectorTest {
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE FirstName = 'OHR' AND LastName = 'Admin' LIMIT 1];
    }
    
    @TestSetup
    static void setupTestData() {
        // Create OHR Admin user with permissions already assigned
        OHRTestDataFactory.createOHRAdminUser();
        
        // Create test users
        List<User> users = new List<User>();
        for (Integer i = 0; i < 5; i++) {
            User u = new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'testuser' + i + '@example.com',
                Username = 'testuser' + i + '@example.com.' + System.now().getTime(),
                Alias = 'tuser' + i,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
                LanguageLocaleKey = 'en_US',
                IsActive = true
            );
            users.add(u);
        }
        
        // Create inactive user
        User inactiveUser = new User(
            FirstName = 'Inactive',
            LastName = 'User',
            Email = 'inactive@example.com',
            Username = 'inactive@example.com.' + System.now().getTime(),
            Alias = 'inact',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            IsActive = false
        );
        users.add(inactiveUser);
        
        insert users;
    }
    
    @isTest
    static void testGetUsersByEmails_Success() {
        Set<String> emails = new Set<String>{ 'testuser0@example.com', 'testuser1@example.com' };
        
        Test.startTest();
        List<User> result = OHRUserSelector.getUsersByEmails(emails);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(2, result.size(), 'Should return 2 users');
        
        for (User u : result) {
            Assert.isTrue(emails.contains(u.Email), 'Should match email');
            Assert.areEqual(true, u.IsActive, 'Should only return active users');
        }
    }
    
    @isTest
    static void testGetUsersByEmails_ExcludesInactive() {
        Set<String> emails = new Set<String>{ 'inactive@example.com' };
        
        Test.startTest();
        List<User> result = OHRUserSelector.getUsersByEmails(emails);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should not return inactive user');
    }
    
    @isTest
    static void testGetUsersByEmails_NoMatches() {
        Set<String> emails = new Set<String>{ 'nonexistent@example.com' };
        
        Test.startTest();
        List<User> result = OHRUserSelector.getUsersByEmails(emails);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testGetUsersByEmails_MultipleEmails() {
        Set<String> emails = new Set<String>{ 
            'testuser0@example.com', 
            'testuser1@example.com', 
            'testuser2@example.com',
            'nonexistent@example.com' 
        };
        
        Test.startTest();
        List<User> result = OHRUserSelector.getUsersByEmails(emails);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(3, result.size(), 'Should return 3 active users');
    }
    
    @isTest
    static void testGetUserById_Success() {
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User0' LIMIT 1];
        
        Test.startTest();
        List<User> result = OHRUserSelector.getUserById(testUser.Id);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(1, result.size(), 'Should return one user');
        Assert.areEqual(testUser.Id, result[0].Id, 'Should return correct user');
        Assert.isNotNull( result[0].Name, 'Should have name');
        Assert.isNotNull( result[0].Email, 'Should have email');
    }
    
    @isTest
    static void testGetUserById_NotFound() {
        // Test with null ID to verify method handles non-existent IDs gracefully
        Test.startTest();
        List<User> result = OHRUserSelector.getUserById(null);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list for null ID');
    }
}

