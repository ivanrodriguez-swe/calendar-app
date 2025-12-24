/**
 * Controller for volunteerAvailabilityDisplay LWC
 * 
 * IMPORTANT: Controllers should NEVER call other controllers - only services.
 * This controller calls VolunteerAvailabilityService, which can call other services if needed.
 * 
 * Responsibilities:
 * - Expose @AuraEnabled methods for the LWC
 * - Handle exception handling and validation
 * - Convert service data (Maps) to wrapper classes for LWC consumption
 * - NO business logic - all logic is in the service layer
 */
public without sharing class VolunteerAvailabilityDisplayController {
    
    /**
     * Get volunteer availability data for display table
     * If startDate and endDate are null, returns all records from database
     * 
     * @param startDate Start date for filtering (null to get all records) - accepts String to avoid timezone conversion
     * @param endDate End date for filtering (null to get all records) - accepts String to avoid timezone conversion
     * @param offset Pagination offset
     * @param pageSize Number of records per page
     * @return VolunteerAvailabilityResult with paginated rows
     */
    @AuraEnabled
    public static VolunteerAvailabilityResult getVolunteerAvailabilityData(String startDate, String endDate, Integer offset, Integer pageSize) {
        try {
            // Date filters are optional - if both are null, get all records
            
            // CRITICAL FIX: Accept dates as Strings and parse them ourselves to avoid timezone conversion
            // When JavaScript sends Date objects, Apex may convert them with timezone considerations.
            // By accepting String dates in YYYY-MM-DD format and parsing them with Date.valueOf(),
            // we ensure the date represents exactly what the user selected, without timezone shifts.
            Date normalizedStartDate = null;
            Date normalizedEndDate = null;
            
            System.debug('Method called with - startDate: ' + startDate + ', endDate: ' + endDate + ', offset: ' + offset + ', pageSize: ' + pageSize);
            
            if (String.isNotBlank(startDate)) {
                try {
                    // Parse the date string directly by extracting components to avoid ANY timezone conversion
                    // Format: YYYY-MM-DD (e.g., "2025-12-22")
                    List<String> dateParts = startDate.split('-');
                    if (dateParts.size() != 3) {
                        throw new AuraHandledException('Invalid start date format: ' + startDate + '. Expected YYYY-MM-DD format.');
                    }
                    Integer year = Integer.valueOf(dateParts[0]);
                    Integer month = Integer.valueOf(dateParts[1]);
                    Integer day = Integer.valueOf(dateParts[2]);
                    // Create date directly from components - no timezone conversion possible
                    normalizedStartDate = Date.newInstance(year, month, day);
                    System.debug('Date parsing - String startDate: ' + startDate + ' -> Direct parse: year=' + year + ', month=' + month + ', day=' + day + ' -> Normalized: ' + normalizedStartDate);
                } catch (Exception e) {
                    System.debug('Error parsing startDate string: ' + startDate + ' - ' + e.getMessage());
                    throw new AuraHandledException('Invalid start date format: ' + startDate + '. Expected YYYY-MM-DD format. Error: ' + e.getMessage());
                }
            }
            
            if (String.isNotBlank(endDate)) {
                try {
                    // Parse the date string directly by extracting components to avoid ANY timezone conversion
                    // Format: YYYY-MM-DD (e.g., "2025-12-22")
                    List<String> dateParts = endDate.split('-');
                    if (dateParts.size() != 3) {
                        throw new AuraHandledException('Invalid end date format: ' + endDate + '. Expected YYYY-MM-DD format.');
                    }
                    Integer year = Integer.valueOf(dateParts[0]);
                    Integer month = Integer.valueOf(dateParts[1]);
                    Integer day = Integer.valueOf(dateParts[2]);
                    // Create date directly from components - no timezone conversion possible
                    normalizedEndDate = Date.newInstance(year, month, day);
                    System.debug('Date parsing - String endDate: ' + endDate + ' -> Direct parse: year=' + year + ', month=' + month + ', day=' + day + ' -> Normalized: ' + normalizedEndDate);
                } catch (Exception e) {
                    System.debug('Error parsing endDate string: ' + endDate + ' - ' + e.getMessage());
                    throw new AuraHandledException('Invalid end date format: ' + endDate + '. Expected YYYY-MM-DD format. Error: ' + e.getMessage());
                }
            }
            
            // Debug logging for date values
            System.debug('Controller received dates - startDate string: ' + startDate + ' (normalized: ' + normalizedStartDate + '), endDate string: ' + endDate + ' (normalized: ' + normalizedEndDate + ')');
            if (normalizedStartDate != null && normalizedEndDate != null) {
                System.debug('Date comparison - normalizedStartDate == normalizedEndDate: ' + (normalizedStartDate == normalizedEndDate));
            }
            
            // Default pagination values
            Integer offsetValue = offset != null ? offset : 0;
            Integer pageSizeValue = (pageSize != null && pageSize > 0) ? pageSize : 50;
            
            // Service handles all logic and returns pre-organized data with pagination
            // Service can call other services if needed
            // Pass normalized dates to service
            Map<String, Object> serviceResult = 
                VolunteerAvailabilityService.getVolunteerAvailabilityData(normalizedStartDate, normalizedEndDate, offsetValue, pageSizeValue);
            
            // Controller just converts to wrapper classes (simple data transformation)
            List<Map<String, Object>> serviceRows = (List<Map<String, Object>>) serviceResult.get('rows');
            List<VolunteerAvailabilityRow> rows = convertToVolunteerAvailabilityRows(serviceRows);
            
            VolunteerAvailabilityResult result = new VolunteerAvailabilityResult();
            result.rows = rows;
            result.totalCount = (Integer) serviceResult.get('totalCount');
            result.hasMore = (Boolean) serviceResult.get('hasMore');
            
            return result;
        } catch (Exception e) {
            System.debug('Error in getVolunteerAvailabilityData: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving volunteer availability data: ' + e.getMessage());
        }
    }
    
    /**
     * Get volunteer information for display
     * Delegates to VolunteerAvailabilityService, which calls VolunteerDisplayService if needed
     * 
     * @param volunteerId Volunteer (User) ID
     * @return VolunteerInfoResult with volunteer information
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerInfoResult getVolunteerInfo(Id volunteerId) {
        if (volunteerId == null) {
            throw new AuraHandledException('volunteerId is required.');
        }
        
        // Service handles all logic - can call other services
        Map<String, Object> serviceResult = VolunteerAvailabilityService.getVolunteerInfo(volunteerId);
        
        if (serviceResult == null || !(Boolean) serviceResult.get('success')) {
            VolunteerInfoResult result = new VolunteerInfoResult();
            result.success = false;
            result.message = (String) serviceResult?.get('message') ?? 'Volunteer not found';
            return result;
        }
        
        // Controller converts to wrapper class (simple data transformation)
        Map<String, Object> serviceVolunteer = (Map<String, Object>) serviceResult.get('volunteer');
        VolunteerInfo volunteerInfo = new VolunteerInfo();
        volunteerInfo.id = (Id) serviceVolunteer.get('id');
        volunteerInfo.name = (String) serviceVolunteer.get('name');
        volunteerInfo.email = (String) serviceVolunteer.get('email');
        volunteerInfo.isActive = (Boolean) serviceVolunteer.get('isActive');
        volunteerInfo.createdDate = (DateTime) serviceVolunteer.get('createdDate');
        
        VolunteerInfoResult result = new VolunteerInfoResult();
        result.success = true;
        result.volunteer = volunteerInfo;
        
        return result;
    }
    
    /**
     * Get all volunteers for selection/filtering
     * Delegates to VolunteerAvailabilityService, which calls VolunteerDisplayService if needed
     * 
     * @return VolunteerListResult with list of volunteers
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerListResult getAllVolunteersForDisplay() {
        // Service handles all logic - can call other services
        Map<String, Object> serviceResult = VolunteerAvailabilityService.getAllVolunteersForDisplay();
        
        // Controller converts to wrapper classes (simple data transformation)
        List<Map<String, Object>> serviceVolunteers = (List<Map<String, Object>>) serviceResult.get('volunteers');
        List<VolunteerInfo> volunteers = new List<VolunteerInfo>();
        
        for (Map<String, Object> volunteerData : serviceVolunteers) {
            VolunteerInfo volunteer = new VolunteerInfo();
            volunteer.id = (Id) volunteerData.get('id');
            volunteer.name = (String) volunteerData.get('name');
            volunteer.email = (String) volunteerData.get('email');
            volunteer.isActive = (Boolean) volunteerData.get('isActive');
            volunteer.createdDate = (DateTime) volunteerData.get('createdDate');
            volunteers.add(volunteer);
        }
        
        VolunteerListResult result = new VolunteerListResult();
        result.volunteers = volunteers;
        result.totalCount = (Integer) serviceResult.get('totalCount');
        
        return result;
    }
    
    // Private conversion methods - simple data transformation, no business logic
    
    /**
     * Convert service's organized data structure to VolunteerAvailabilityRow list
     * Service provides pre-organized data, controller just converts format
     */
    private static List<VolunteerAvailabilityRow> convertToVolunteerAvailabilityRows(List<Map<String, Object>> serviceData) {
        List<VolunteerAvailabilityRow> rows = new List<VolunteerAvailabilityRow>();
        
        for (Map<String, Object> rowData : serviceData) {
            VolunteerAvailabilityRow row = new VolunteerAvailabilityRow();
            row.volunteerId = (Id) rowData.get('volunteerId');
            row.volunteerName = (String) rowData.get('volunteerName');
            row.volunteerEmail = (String) rowData.get('volunteerEmail');
            row.slotDate = (Date) rowData.get('date');
            
            List<Map<String, Object>> timeSlotDataList = (List<Map<String, Object>>) rowData.get('timeSlots');
            row.timeSlots = new List<TimeSlotData>();
            for (Map<String, Object> slotData : timeSlotDataList) {
                TimeSlotData tsd = new TimeSlotData();
                tsd.id = (Id) slotData.get('id');
                tsd.startTime = (Time) slotData.get('startTime');
                tsd.endTime = (Time) slotData.get('endTime');
                tsd.status = (String) slotData.get('status');
                tsd.timeLabel = (String) slotData.get('timeLabel'); // Service formats this
                row.timeSlots.add(tsd);
            }
            
            rows.add(row);
        }
        
        return rows;
    }

    // Wrapper Classes for LWC communication (DTOs with @AuraEnabled)
    
    public class VolunteerAvailabilityRow {
        @AuraEnabled public Id volunteerId;
        @AuraEnabled public String volunteerName;
        @AuraEnabled public String volunteerEmail;
        @AuraEnabled public Date slotDate;
        @AuraEnabled public List<TimeSlotData> timeSlots; // All time slots for this volunteer-date
    }
    
    public class TimeSlotData {
        @AuraEnabled public Id id;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String status; // 'Available' or 'Booked'
        @AuraEnabled public String timeLabel; // Formatted time range (e.g., "9:00 AM - 9:15 AM")
    }
    
    public class VolunteerAvailabilityResult {
        @AuraEnabled public List<VolunteerAvailabilityRow> rows;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean hasMore;
    }
    
    // Wrapper classes for volunteer information
    public class VolunteerInfoResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public VolunteerInfo volunteer;
    }
    
    public class VolunteerListResult {
        @AuraEnabled public List<VolunteerInfo> volunteers;
        @AuraEnabled public Integer totalCount;
    }
    
    public class VolunteerInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public DateTime createdDate;
    }
}


