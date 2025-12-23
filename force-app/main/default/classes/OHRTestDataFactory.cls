/**
 * Test Data Factory for OHR Scheduler App
 * Creates test users with appropriate permissions for testing
 */
@isTest
public class OHRTestDataFactory {
    
    /**
     * Create an OHR Admin user with OHR_Scheduler_Admin permission set group
     * The permission set group is assigned internally to avoid MIXED_DML_OPERATION
     * @return User with admin permissions already assigned, ready to use in System.runAs()
     */
    public static User createOHRAdminUser() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User adminUser = new User(
            FirstName = 'OHR',
            LastName = 'Admin',
            Email = 'ohradmin@test.com',
            Username = 'ohradmin@test.com.' + System.now().getTime() + (Integer)(Math.random() * 1000),
            Alias = 'ohradm',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert adminUser;
        
        // Assign permission set group in a separate context to avoid MIXED_DML_OPERATION
        System.runAs(new User(Id = UserInfo.getUserId())) {
            assignPermissionSetGroupToUser(adminUser.Id);
        }
        
        return adminUser;
    }
    
    /**
     * Assign OHR Scheduler Admin permission set group to a user
     * This is called internally by createOHRAdminUser() in a separate context
     * 
     * @param userId User ID to assign permission set group to
     */
    private static void assignPermissionSetGroupToUser(Id userId) {
        // Get the permission set group ID
        Id permissionSetGroupId = getPermissionSetGroupId('OHR_Scheduler_Admin');
        
        if (permissionSetGroupId != null) {
            // Assign permission set group using PermissionSetAssignment with PermissionSetGroupId
            PermissionSetAssignment permAssignment = new PermissionSetAssignment();
            permAssignment.AssigneeId = userId;
            permAssignment.PermissionSetGroupId = permissionSetGroupId;
            insert permAssignment;
        }
    }
    
    /**
     * Get permission set group ID by developer name
     * Ensures the permission set group is calculated if needed
     * @param developerName Developer name of the permission set group
     * @return Permission set group ID
     */
    private static Id getPermissionSetGroupId(String developerName) {
        PermissionSetGroup permSetGroup = [
            SELECT Id, DeveloperName, Status 
            FROM PermissionSetGroup 
            WHERE DeveloperName = :developerName 
            LIMIT 1
        ];
        
        if (permSetGroup != null) {
            // Ensure permission set group is calculated
            if (permSetGroup.Status != 'Updated') {
                Test.calculatePermissionSetGroup(permSetGroup.Id);
            }
            return permSetGroup.Id;
        }
        
        return null;
    }
    
    /**
     * Create a volunteer user for testing
     * @return User volunteer
     */
    public static User createVolunteerUser(Integer index) {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User volunteer = new User(
            FirstName = 'Volunteer',
            LastName = 'Test' + index,
            Email = 'volunteer' + index + '@test.com',
            Username = 'volunteer' + index + '@test.com.' + System.now().getTime() + (Integer)(Math.random() * 1000),
            Alias = 'vol' + index,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert volunteer;
        
        return volunteer;
    }
    
    /**
     * Create a reference user for testing
     * @return User reference
     */
    public static User createReferenceUser() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User reference = new User(
            FirstName = 'Reference',
            LastName = 'Test',
            Email = 'reference@test.com',
            Username = 'reference@test.com.' + System.now().getTime() + (Integer)(Math.random() * 1000),
            Alias = 'ref',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert reference;
        
        return reference;
    }
    
    /**
     * Create multiple volunteer users
     * @param count Number of volunteers to create
     * @return List of volunteer users
     */
    public static List<User> createVolunteerUsers(Integer count) {
        List<User> volunteers = new List<User>();
        for (Integer i = 0; i < count; i++) {
            volunteers.add(createVolunteerUser(i));
        }
        return volunteers;
    }
    
    /**
     * Create a time slot for testing
     * @param day Date for the time slot
     * @param startTime Start time
     * @param endTime End time
     * @param volunteerId Volunteer user ID
     * @return Time_Slot__c record
     */
    public static Time_Slot__c createTimeSlot(Date day, Time startTime, Time endTime, Id volunteerId) {
        Time_Slot__c slot = new Time_Slot__c(
            Day__c = day,
            Start_Time__c = startTime,
            End_Time__c = endTime,
            Status__c = 'Available',
            Volunteer__c = volunteerId
        );
        insert slot;
        return slot;
    }
    
    /**
     * Create an appointment request for testing
     * @param volunteerId Volunteer user ID
     * @return Appointment_Request__c record
     */
    public static Appointment_Request__c createAppointmentRequest(Id volunteerId) {
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = volunteerId,
            Status__c = 'New'
        );
        insert request;
        return request;
    }
}

