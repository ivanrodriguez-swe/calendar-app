// Selector class for User object
// Uses inherited sharing to inherit sharing context from caller
public inherited sharing class OHRUserSelector {
    
    /**
     * Get users by email addresses
     * @param emails Set of email addresses to query
     * @return List of active users matching the email addresses
     */
    public static List<User> getUsersByEmails(Set<String> emails) {
        return [
            SELECT Id, Email, IsActive 
            FROM User 
            WHERE Email IN :emails 
            AND IsActive = true
        ];
    }
    
    /**
     * Get user by ID
     * @param userId User record ID
     * @return User record with name and email
     */
    public static List<User> getUserById(Id userId) {
        return [
            SELECT Id, Name, Email 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ];
    }
    
    /**
     * Get user by ID with full details
     * @param userId User record ID
     * @return User record with full details including IsActive and CreatedDate
     */
    public static List<User> getUserByIdWithDetails(Id userId) {
        return [
            SELECT Id, Name, Email, IsActive, CreatedDate
            FROM User 
            WHERE Id = :userId 
            AND IsActive = true
            LIMIT 1
        ];
    }
    
    /**
     * Get all active users (volunteers)
     * @return List of all active users ordered by name
     */
    public static List<User> getAllActiveUsers() {
        return [
            SELECT Id, Name, Email, IsActive, CreatedDate
            FROM User
            WHERE IsActive = true
            ORDER BY Name
        ];
    }
    
    /**
     * Get users by IDs
     * @param userIds Set of user IDs to query
     * @return List of active users matching the IDs, ordered by name
     */
    public static List<User> getUsersByIds(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new List<User>();
        }
        
        return [
            SELECT Id, Name, Email, IsActive, CreatedDate
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            ORDER BY Name
        ];
    }
}

