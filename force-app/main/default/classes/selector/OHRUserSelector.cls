public inherited sharing class OHRUserSelector {
    
    public static List<User> getUsersByEmails(Set<String> emails) {
        return [
            SELECT Id, Email, IsActive 
            FROM User 
            WHERE Email IN :emails 
            AND IsActive = true
        ];
    }
    
    public static List<User> getUserById(Id userId) {
        return [
            SELECT Id, Name, Email 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ];
    }
    
    public static List<User> getUserByIdWithDetails(Id userId) {
        return [
            SELECT Id, Name, Email, IsActive, CreatedDate
            FROM User 
            WHERE Id = :userId 
            AND IsActive = true
            LIMIT 1
        ];
    }
    
    public static List<User> getAllActiveUsers() {
        return [
            SELECT Id, Name, Email, IsActive, CreatedDate
            FROM User
            WHERE IsActive = true
            ORDER BY Name
        ];
    }
}
