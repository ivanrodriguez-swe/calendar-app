// Controller for volunteer availability and time slot management
// Using 'without sharing' to allow guest users on public sites to access time slots and book appointments
// Thin layer that delegates to VolunteerAvailabilityService and converts to wrapper classes for LWC
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
}
