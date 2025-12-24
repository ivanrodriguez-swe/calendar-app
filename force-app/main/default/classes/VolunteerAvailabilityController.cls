// Controller for volunteer availability and time slot management
// Using 'without sharing' to allow guest users on public sites to access time slots and book appointments
// Thin layer that delegates to VolunteerAvailabilityService and converts to wrapper classes for LWC
// 
// IMPORTANT: Controllers should NEVER call other controllers - only services.
// Services can call other services, but controllers must remain independent.
public without sharing class VolunteerAvailabilityController {
    
    // Get available time slots for a date range (used by appointmentScheduler LWC)
    @AuraEnabled(cacheable=true)
    public static List<DayWrapper> getTimeslotsForRange(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('startDate and endDate are required.');
        }
        
        // Get organized data from service (service handles all business logic)
        List<Map<String, Object>> organizedData = VolunteerAvailabilityService.getTimeslotsForRange(startDate, endDate);
        
        // Convert organized data to wrapper classes (simple conversion, no business logic)
        return convertToDayWrappers(organizedData);
    }

    // Book a time slot (used by appointmentScheduler LWC)
    @AuraEnabled
    public static BookingResult bookTimeSlot(Id timeSlotId, Id customerId, Id appointmentRequestId) {
        try {
            Map<String, Object> serviceResult = VolunteerAvailabilityService.bookTimeSlot(timeSlotId, customerId, appointmentRequestId);
            return new BookingResult(
                (Boolean) serviceResult.get('success'),
                (String) serviceResult.get('message'),
                (Id) serviceResult.get('appointmentId')
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error booking time slot: ' + e.getMessage());
        }
    }

    // Create time slots from availability ranges (used by volunteerAvailability LWC)
    @AuraEnabled
    public static CreateSlotsResult createTimeSlotsFromRanges(List<AvailabilityRange> ranges) {
        try {
            // Convert controller wrappers to service input format
            List<Map<String, String>> serviceRanges = convertToServiceRanges(ranges);
            
            // Delegate to service
            Map<String, Object> serviceResult = VolunteerAvailabilityService.createTimeSlotsFromRanges(serviceRanges, UserInfo.getUserId());
            
            return new CreateSlotsResult(
                (Boolean) serviceResult.get('success'),
                (String) serviceResult.get('message'),
                (Integer) serviceResult.get('slotsCreated')
            );
        } catch (Exception e) {
            CreateSlotsResult result = new CreateSlotsResult();
            result.success = false;
            result.message = 'Error creating time slots: ' + e.getMessage();
            return result;
        }
    }

    // Create time slots from CSV file (used by volunteerAvailabilityUploader LWC)
    @AuraEnabled
    public static CreateSlotsResult createTimeSlotsFromCSV(String csvContent) {
        try {
            Map<String, Object> serviceResult = VolunteerAvailabilityService.createTimeSlotsFromCSV(csvContent);
            return new CreateSlotsResult(
                (Boolean) serviceResult.get('success'),
                (String) serviceResult.get('message'),
                (Integer) serviceResult.get('slotsCreated')
            );
        } catch (Exception e) {
            CreateSlotsResult result = new CreateSlotsResult();
            result.success = false;
            result.message = 'Error processing CSV: ' + e.getMessage();
            return result;
        }
    }
    
    // Get volunteer availability data for display table (used by volunteerAvailabilityDisplay LWC)
    // If startDate and endDate are null, returns all records from database
    @AuraEnabled
    public static VolunteerAvailabilityResult getVolunteerAvailabilityData(Date startDate, Date endDate, Integer offset, Integer pageSize) {
        // Date filters are optional - if both are null, get all records
        
        // Debug logging for date values
        System.debug('Controller received dates - startDate: ' + startDate + ', endDate: ' + endDate);
        if (startDate != null && endDate != null) {
            System.debug('Date comparison - startDate == endDate: ' + (startDate == endDate));
        }
        
        // Default pagination values
        Integer offsetValue = offset != null ? offset : 0;
        Integer pageSizeValue = (pageSize != null && pageSize > 0) ? pageSize : 50;
        
        // Service handles all logic and returns pre-organized data with pagination
        Map<String, Object> serviceResult = 
            VolunteerAvailabilityService.getVolunteerAvailabilityData(startDate, endDate, offsetValue, pageSizeValue);
        
        // Controller just converts to wrapper classes (simple data transformation)
        List<Map<String, Object>> serviceRows = (List<Map<String, Object>>) serviceResult.get('rows');
        List<VolunteerAvailabilityRow> rows = convertToVolunteerAvailabilityRows(serviceRows);
        
        VolunteerAvailabilityResult result = new VolunteerAvailabilityResult();
        result.rows = rows;
        result.totalCount = (Integer) serviceResult.get('totalCount');
        result.hasMore = (Boolean) serviceResult.get('hasMore');
        
        return result;
    }
    
    // Get volunteer information for display (used by volunteerAvailabilityDisplay LWC)
    // Delegates to VolunteerAvailabilityService, which calls VolunteerDisplayService if needed
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
    
    // Get all volunteers for selection/filtering (used by volunteerAvailabilityDisplay LWC)
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
     * Convert service's organized data structure to DayWrapper list
     * Service provides pre-organized data, controller just converts format
     */
    private static List<DayWrapper> convertToDayWrappers(List<Map<String, Object>> organizedData) {
        List<DayWrapper> results = new List<DayWrapper>();
        
        for (Map<String, Object> timeRangeData : organizedData) {
            String label = (String) timeRangeData.get('timeRangeLabel');
            DayWrapper dw = new DayWrapper(label);
            
            List<Map<String, Object>> slotDataList = (List<Map<String, Object>>) timeRangeData.get('slotDataList');
            for (Map<String, Object> slotData : slotDataList) {
                Boolean isAvailable = (Boolean) slotData.get('isAvailable');
                Date day = (Date) slotData.get('day');
                
                if (isAvailable) {
                    dw.slots.add(new TimeslotWrapper(
                        (Id) slotData.get('id'),
                        (Time) slotData.get('startTime'),
                        (Time) slotData.get('endTime'),
                        day,
                        (Id) slotData.get('volunteerId'),
                        (String) slotData.get('volunteerName')
                    ));
                } else {
                    dw.slots.add(new TimeslotWrapper(label, day));
                }
            }
            
            results.add(dw);
        }
        
        return results;
    }
    
    /**
     * Convert controller AvailabilityRange wrappers to service input format
     */
    private static List<Map<String, String>> convertToServiceRanges(List<AvailabilityRange> ranges) {
        List<Map<String, String>> serviceRanges = new List<Map<String, String>>();
        for (AvailabilityRange range : ranges) {
            Map<String, String> serviceRange = new Map<String, String>();
            serviceRange.put('dateValue', range.dateValue);
            serviceRange.put('startTime', range.startTime);
            serviceRange.put('endTime', range.endTime);
            serviceRanges.add(serviceRange);
        }
        return serviceRanges;
    }
    
    /**
     * Convert service's organized data to wrapper classes
     * Simple data transformation - no business logic
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
    public class DayWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public List<TimeslotWrapper> slots;
        
        public DayWrapper(String label) {
            this.label = label;
            this.slots = new List<TimeslotWrapper>();
        }
    }

    public class TimeslotWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public Date day;
        @AuraEnabled public String label;
        @AuraEnabled public Id volunteerId;
        @AuraEnabled public String volunteerName;
        @AuraEnabled public Boolean isAvailable;
        @AuraEnabled public Boolean isUnavailable;

        public TimeslotWrapper(Id id, Time startTime, Time endTime, Date day, Id volunteerId, String volunteerName) {
            this.id = id;
            this.startTime = startTime;
            this.endTime = endTime;
            this.day = day;
            this.label = day + '-' + startTime + '-' + endTime;
            this.volunteerId = volunteerId;
            this.volunteerName = volunteerName;
            this.isAvailable = true;
            this.isUnavailable = false;
        }

        public TimeslotWrapper(String label, Date day) {
            this.id = null;
            this.startTime = null;
            this.endTime = null;
            this.day = day;
            this.label = label;
            this.volunteerId = null;
            this.volunteerName = null;
            this.isAvailable = false;
            this.isUnavailable = true;
        }
    }

    public class BookingResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id appointmentId;

        public BookingResult(Boolean success, String message, Id appointmentId) {
            this.success = success;
            this.message = message;
            this.appointmentId = appointmentId;
        }
    }

    public class AvailabilityRange {
        @AuraEnabled public String dateValue { get; set; }
        @AuraEnabled public String startTime { get; set; }
        @AuraEnabled public String endTime { get; set; }
    }

    public class CreateSlotsResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer slotsCreated;
        
        public CreateSlotsResult() {
            this.success = false;
            this.slotsCreated = 0;
        }
        
        public CreateSlotsResult(Boolean success, String message, Integer slotsCreated) {
            this.success = success;
            this.message = message;
            this.slotsCreated = slotsCreated;
        }
    }
    
    // Wrapper classes for volunteer availability display LWC
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
    
    // Wrapper classes for volunteer information (used by volunteerAvailabilityDisplay LWC)
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
