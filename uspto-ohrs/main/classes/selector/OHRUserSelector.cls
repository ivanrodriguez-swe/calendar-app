/**
 * @description Selector class for User queries
 */
public inherited sharing class OHRUserSelector {
    
    /**
     * @description Retrieves active users by email addresses
     * @param emails Set of email addresses to search
     * @return List of matching active users
     */
    public static List<User> getUsersByEmails(Set<String> emails) {
        return [
            SELECT Id, Email, IsActive, FirstName, LastName
            FROM User 
            WHERE Email IN :emails 
            AND IsActive = true
        ];
    }
    
    /**
     * @description Retrieves a user by Id
     * @param userId The User Id
     * @return List containing the user or empty if not found
     */
    public static List<User> getUserById(Id userId) {
        return [
            SELECT Id, Name, FirstName, LastName, Email 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ];
    }
}
