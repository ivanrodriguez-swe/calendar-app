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
            SELECT Id, Email 
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
}

