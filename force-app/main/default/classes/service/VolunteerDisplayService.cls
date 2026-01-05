public with sharing class VolunteerDisplayService {
    
    /**
     * Get all volunteers (active users) with their information
     * Returns structured data ready for presentation layer
     * @return Map containing list of volunteers and total count
     */
    public static Map<String, Object> getAllVolunteers() {
        List<User> users = OHRUserSelector.getAllActiveUsers();
        
        List<Map<String, Object>> volunteerData = convertUsersToMaps(users);
        
        return buildResult(volunteerData);
    }
    
    /**
     * Get volunteer by ID
     * @param volunteerId Volunteer (User) ID
     * @return Map containing volunteer information or null if not found
     */
    public static Map<String, Object> getVolunteerById(Id volunteerId) {
        if (volunteerId == null) {
            return null;
        }
        
        List<User> users = OHRUserSelector.getUserByIdWithDetails(volunteerId);
        
        if (users.isEmpty()) {
            return null;
        }
        
        List<Map<String, Object>> volunteerData = convertUsersToMaps(users);
        return volunteerData[0];
    }
    
    /**
     * Convert list of User records to list of Maps
     * Reusable method to avoid code duplication
     */
    private static List<Map<String, Object>> convertUsersToMaps(List<User> users) {
        List<Map<String, Object>> volunteerData = new List<Map<String, Object>>();
        for (User u : users) {
            volunteerData.add(convertUserToMap(u));
        }
        return volunteerData;
    }
    
    /**
     * Convert single User record to Map
     * Reusable method to avoid code duplication
     */
    private static Map<String, Object> convertUserToMap(User u) {
        Map<String, Object> volunteer = new Map<String, Object>();
        volunteer.put('id', u.Id);
        volunteer.put('name', u.Name);
        volunteer.put('email', u.Email);
        volunteer.put('isActive', u.IsActive);
        volunteer.put('createdDate', u.CreatedDate);
        return volunteer;
    }
    
    /**
     * Build result map with volunteers and total count
     * Reusable method to avoid code duplication
     */
    private static Map<String, Object> buildResult(List<Map<String, Object>> volunteerData) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('volunteers', volunteerData);
        result.put('totalCount', volunteerData.size());
        return result;
    }
}

