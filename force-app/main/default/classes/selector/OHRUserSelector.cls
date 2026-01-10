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
            SELECT Id, Email, IsActive 
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
            SELECT Id, Name, Email 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ];
    }
    
    /**
     * @description Retrieves an active user by Id with additional details
     * @param userId The User Id
     * @return List containing the active user or empty if not found
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
     * @description Retrieves all active users ordered by name
     * @return List of all active users
     */
    public static List<User> getAllActiveUsers() {
        return [
            SELECT Id, Name, Email, IsActive, CreatedDate
            FROM User
            WHERE IsActive = true
            ORDER BY Name
        ];
    }
}
