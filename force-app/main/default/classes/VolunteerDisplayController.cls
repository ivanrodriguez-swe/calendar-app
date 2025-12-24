// Controller for volunteer display
// Using 'without sharing' to allow guest users on public sites to access volunteer information
// Thin layer that delegates to VolunteerDisplayService and converts to wrapper classes for LWC
// 
// IMPORTANT: Controllers should NEVER call other controllers - only services.
// Services can call other services, but controllers must remain independent.
public without sharing class VolunteerDisplayController {
    
    /**
     * Get all volunteers (active users)
     * @return VolunteerResult containing list of volunteers and total count
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerResult getAllVolunteers() {
        // Service handles all logic and returns structured data
        Map<String, Object> serviceResult = VolunteerDisplayService.getAllVolunteers();
        
        // Controller converts to wrapper classes (simple data transformation)
        return convertServiceResultToVolunteerResult(serviceResult);
    }
    
    /**
     * Get volunteers by IDs
     * @param volunteerIds List of volunteer (User) IDs
     * @return VolunteerResult containing list of volunteers and total count
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerResult getVolunteersByIds(List<Id> volunteerIds) {
        if (volunteerIds == null || volunteerIds.isEmpty()) {
            return buildEmptyVolunteerResult();
        }
        
        Set<Id> volunteerIdSet = new Set<Id>(volunteerIds);
        
        // Service handles all logic and returns structured data
        Map<String, Object> serviceResult = VolunteerDisplayService.getVolunteersByIds(volunteerIdSet);
        
        // Controller converts to wrapper classes (simple data transformation)
        return convertServiceResultToVolunteerResult(serviceResult);
    }
    
    /**
     * Get volunteer by ID
     * @param volunteerId Volunteer (User) ID
     * @return VolunteerWrapper containing volunteer information or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerWrapper getVolunteerById(Id volunteerId) {
        if (volunteerId == null) {
            return null;
        }
        
        // Service handles all logic and returns structured data
        Map<String, Object> serviceVolunteer = VolunteerDisplayService.getVolunteerById(volunteerId);
        
        if (serviceVolunteer == null) {
            return null;
        }
        
        // Controller converts to wrapper class (simple data transformation)
        return convertToVolunteerWrapper(serviceVolunteer);
    }
    
    /**
     * Get volunteers with time slot statistics
     * @param startDate Optional start date for time slot filtering
     * @param endDate Optional end date for time slot filtering
     * @return VolunteerResult containing list of volunteers with statistics
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerResult getVolunteersWithStatistics(Date startDate, Date endDate) {
        // Service handles all logic and returns structured data
        Map<String, Object> serviceResult = VolunteerDisplayService.getVolunteersWithStatistics(startDate, endDate);
        
        // Controller converts to wrapper classes (simple data transformation)
        List<Map<String, Object>> serviceVolunteers = (List<Map<String, Object>>) serviceResult.get('volunteers');
        List<VolunteerWrapper> volunteers = convertToVolunteerWrappersWithStatistics(serviceVolunteers);
        
        return buildVolunteerResult(volunteers, (Integer) serviceResult.get('totalCount'));
    }
    
    // Private conversion methods - simple data transformation, no business logic
    
    /**
     * Convert service result to VolunteerResult
     * Reusable method to avoid code duplication
     */
    private static VolunteerResult convertServiceResultToVolunteerResult(Map<String, Object> serviceResult) {
        List<Map<String, Object>> serviceVolunteers = (List<Map<String, Object>>) serviceResult.get('volunteers');
        List<VolunteerWrapper> volunteers = convertToVolunteerWrappers(serviceVolunteers);
        return buildVolunteerResult(volunteers, (Integer) serviceResult.get('totalCount'));
    }
    
    /**
     * Build VolunteerResult from volunteers list and total count
     * Reusable method to avoid code duplication
     */
    private static VolunteerResult buildVolunteerResult(List<VolunteerWrapper> volunteers, Integer totalCount) {
        VolunteerResult result = new VolunteerResult();
        result.volunteers = volunteers;
        result.totalCount = totalCount;
        return result;
    }
    
    /**
     * Build empty VolunteerResult
     * Reusable method to avoid code duplication
     */
    private static VolunteerResult buildEmptyVolunteerResult() {
        return buildVolunteerResult(new List<VolunteerWrapper>(), 0);
    }
    
    /**
     * Convert service's volunteer data structure to VolunteerWrapper list
     */
    private static List<VolunteerWrapper> convertToVolunteerWrappers(List<Map<String, Object>> serviceData) {
        List<VolunteerWrapper> wrappers = new List<VolunteerWrapper>();
        
        for (Map<String, Object> volunteerData : serviceData) {
            wrappers.add(convertToVolunteerWrapper(volunteerData));
        }
        
        return wrappers;
    }
    
    /**
     * Convert service's volunteer data structure to VolunteerWrapper
     */
    private static VolunteerWrapper convertToVolunteerWrapper(Map<String, Object> volunteerData) {
        VolunteerWrapper wrapper = new VolunteerWrapper();
        wrapper.id = (Id) volunteerData.get('id');
        wrapper.name = (String) volunteerData.get('name');
        wrapper.email = (String) volunteerData.get('email');
        wrapper.isActive = (Boolean) volunteerData.get('isActive');
        wrapper.createdDate = (DateTime) volunteerData.get('createdDate');
        
        return wrapper;
    }
    
    /**
     * Convert service's volunteer data structure with statistics to VolunteerWrapper list
     */
    private static List<VolunteerWrapper> convertToVolunteerWrappersWithStatistics(List<Map<String, Object>> serviceData) {
        List<VolunteerWrapper> wrappers = new List<VolunteerWrapper>();
        
        for (Map<String, Object> volunteerData : serviceData) {
            VolunteerWrapper wrapper = convertToVolunteerWrapper(volunteerData);
            
            // Add statistics if available
            if (volunteerData.containsKey('statistics')) {
                Map<String, Object> statsMap = (Map<String, Object>) volunteerData.get('statistics');
                VolunteerStatistics stats = new VolunteerStatistics();
                stats.available = (Integer) statsMap.get('available');
                stats.booked = (Integer) statsMap.get('booked');
                stats.total = (Integer) statsMap.get('total');
                wrapper.statistics = stats;
            }
            
            wrappers.add(wrapper);
        }
        
        return wrappers;
    }
    
    // Wrapper classes for LWC
    
    public class VolunteerResult {
        @AuraEnabled public List<VolunteerWrapper> volunteers;
        @AuraEnabled public Integer totalCount;
    }
    
    public class VolunteerWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public VolunteerStatistics statistics;
    }
    
    public class VolunteerStatistics {
        @AuraEnabled public Integer available;
        @AuraEnabled public Integer booked;
        @AuraEnabled public Integer total;
    }
}

