// Service class for volunteer display business logic
// Uses 'with sharing' for security
// Works with raw data (SObjects, primitives) - no wrapper classes
// 
// NOTE: Services CAN call other services if needed for business logic.
// This is different from controllers, which must remain independent.
public with sharing class VolunteerDisplayService {
    
    /**
     * Get all volunteers (active users) with their information
     * Returns structured data ready for presentation layer
     * @return Map containing list of volunteers and total count
     */
    public static Map<String, Object> getAllVolunteers() {
        // Use selector to get all active users
        List<User> users = OHRUserSelector.getAllActiveUsers();
        
        // Convert to structured data using reusable method
        List<Map<String, Object>> volunteerData = convertUsersToMaps(users);
        
        return buildResult(volunteerData);
    }
    
    /**
     * Get volunteers by IDs
     * @param volunteerIds Set of volunteer (User) IDs
     * @return Map containing list of volunteers
     */
    public static Map<String, Object> getVolunteersByIds(Set<Id> volunteerIds) {
        if (volunteerIds == null || volunteerIds.isEmpty()) {
            return buildResult(new List<Map<String, Object>>());
        }
        
        // Use selector to get users by IDs
        List<User> users = OHRUserSelector.getUsersByIds(volunteerIds);
        
        // Convert to structured data using reusable method
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
        
        // Use selector to get user by ID
        List<User> users = OHRUserSelector.getUserByIdWithDetails(volunteerId);
        
        if (users.isEmpty()) {
            return null;
        }
        
        // Convert to structured data using reusable method
        List<Map<String, Object>> volunteerData = convertUsersToMaps(users);
        return volunteerData[0];
    }
    
    /**
     * Get volunteers with time slot statistics
     * Returns volunteers with count of available and booked time slots
     * @param startDate Optional start date for time slot filtering
     * @param endDate Optional end date for time slot filtering
     * @return Map containing list of volunteers with statistics
     */
    public static Map<String, Object> getVolunteersWithStatistics(Date startDate, Date endDate) {
        // Use selector to get all active volunteers
        List<User> users = OHRUserSelector.getAllActiveUsers();
        
        // Get time slot statistics if date range is provided
        Map<Id, Map<String, Integer>> statisticsMap = new Map<Id, Map<String, Integer>>();
        if (startDate != null && endDate != null && !users.isEmpty()) {
            Set<Id> volunteerIds = new Map<Id, User>(users).keySet();
            
            // Use selector to get time slots for the date range
            List<Time_Slot__c> slots = TimeSlotSelector.getAllTimeSlotsForRange(startDate, endDate);
            
            // Filter slots for the volunteers we're interested in
            for (Time_Slot__c slot : slots) {
                if (volunteerIds.contains(slot.Volunteer__c)) {
                    if (!statisticsMap.containsKey(slot.Volunteer__c)) {
                        statisticsMap.put(slot.Volunteer__c, new Map<String, Integer>{
                            'available' => 0,
                            'booked' => 0,
                            'total' => 0
                        });
                    }
                    
                    Map<String, Integer> stats = statisticsMap.get(slot.Volunteer__c);
                    stats.put('total', stats.get('total') + 1);
                    if (slot.Status__c == 'Available') {
                        stats.put('available', stats.get('available') + 1);
                    } else if (slot.Status__c == 'Booked') {
                        stats.put('booked', stats.get('booked') + 1);
                    }
                }
            }
        }
        
        // Build result with statistics
        List<Map<String, Object>> volunteerData = new List<Map<String, Object>>();
        for (User u : users) {
            Map<String, Object> volunteer = convertUserToMap(u);
            
            // Add statistics if available
            if (statisticsMap.containsKey(u.Id)) {
                volunteer.put('statistics', statisticsMap.get(u.Id));
            } else {
                volunteer.put('statistics', new Map<String, Integer>{
                    'available' => 0,
                    'booked' => 0,
                    'total' => 0
                });
            }
            
            volunteerData.add(volunteer);
        }
        
        return buildResult(volunteerData);
    }
    
    // Private helper methods - reusable logic
    
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

