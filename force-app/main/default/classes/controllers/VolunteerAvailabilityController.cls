public without sharing class VolunteerAvailabilityController {
    
    @AuraEnabled(cacheable=true)
    public static List<DayWrapper> getTimeslotsForRange(Date startDate, Date endDate, Id volunteerId) {
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('startDate and endDate are required.');
        }
        
        List<Map<String, Object>> organizedData = VolunteerAvailabilityService.getTimeslotsForRange(startDate, endDate, volunteerId);
        
        return convertToDayWrappers(organizedData);
    }
    @AuraEnabled
    public static BookingResult bookTimeSlot(Id timeSlotId, Id customerId, Id appointmentRequestId, String referencePhone) {
        try {
            Map<String, Object> serviceResult = VolunteerAvailabilityService.bookTimeSlot(timeSlotId, customerId, appointmentRequestId, referencePhone);
            return new BookingResult(
                (Boolean) serviceResult.get('success'),
                (String) serviceResult.get('message'),
                (Id) serviceResult.get('appointmentId')
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error booking time slot: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static CreateSlotsResult createTimeSlotsFromRanges(List<AvailabilityRange> ranges) {
        try {
            List<Map<String, String>> serviceRanges = convertToServiceRanges(ranges);
            
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

    @AuraEnabled
    public static CreateSlotsResult createTimeSlotsFromCSV(String csvContent) {
        try {
            Map<String, Object> serviceResult = VolunteerAvailabilityService.createTimeSlotsFromCSV(csvContent);
            List<String> warnings = (List<String>) serviceResult.get('warnings');
            return new CreateSlotsResult(
                (Boolean) serviceResult.get('success'),
                (String) serviceResult.get('message'),
                (Integer) serviceResult.get('slotsCreated'),
                warnings
            );
        } catch (Exception e) {
            CreateSlotsResult result = new CreateSlotsResult();
            result.success = false;
            result.message = 'Error processing CSV: ' + e.getMessage();
            return result;
        }
    }
    
    /**
     * Get all available time slots for a volunteer, organized by date
     * @param volunteerId Optional volunteer ID to filter by (null = all volunteers)
     * @return List of available time slot wrappers sorted by date and time
     */
    @AuraEnabled(cacheable=true)
    public static List<AvailableSlotWrapper> getAvailableSlotsByVolunteer(Id volunteerId) {
        Set<Id> volunteerIds = volunteerId != null ? new Set<Id>{ volunteerId } : null;
        Map<Id, List<Time_Slot__c>> slotsByVolunteer = TimeSlotSelector.getAvailableTimeSlotsForRange(null, null, volunteerIds);
        
        List<AvailableSlotWrapper> results = new List<AvailableSlotWrapper>();
        
        for (Id volId : slotsByVolunteer.keySet()) {
            for (Time_Slot__c slot : slotsByVolunteer.get(volId)) {
                results.add(new AvailableSlotWrapper(slot));
            }
        }
        
        return results;
    }
    
    public class AvailableSlotWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Date day;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public Id volunteerId;
        @AuraEnabled public String volunteerName;
        
        public AvailableSlotWrapper(Time_Slot__c slot) {
            this.id = slot.Id;
            this.day = slot.Day__c;
            this.startTime = slot.Start_Time__c;
            this.endTime = slot.End_Time__c;
            this.volunteerId = slot.Volunteer__c;
            this.volunteerName = slot.Volunteer__r != null ? slot.Volunteer__r.Name : null;
        }
    }
    
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
        @AuraEnabled public List<String> warnings;
        
        public CreateSlotsResult() {
            this.success = false;
            this.slotsCreated = 0;
            this.warnings = new List<String>();
        }
        
        public CreateSlotsResult(Boolean success, String message, Integer slotsCreated) {
            this.success = success;
            this.message = message;
            this.slotsCreated = slotsCreated;
            this.warnings = new List<String>();
        }
        
        public CreateSlotsResult(Boolean success, String message, Integer slotsCreated, List<String> warnings) {
            this.success = success;
            this.message = message;
            this.slotsCreated = slotsCreated;
            this.warnings = warnings != null ? warnings : new List<String>();
        }
    }
}
