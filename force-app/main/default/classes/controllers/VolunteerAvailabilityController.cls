public without sharing class VolunteerAvailabilityController {
    
    @AuraEnabled
    public static BookingResult bookSlotWithRandomVolunteer(BookingRequest request) {
        try {
            Date slotDate = Date.valueOf(request.slotDate);
            Time startTime = convertMillisToTime(request.startTime);
            Time endTime = convertMillisToTime(request.endTime);
            
            Map<String, Object> params = new Map<String, Object>();
            params.put('slotDate', slotDate);
            params.put('startTime', startTime);
            params.put('endTime', endTime);
            params.put('appointmentRequestId', request.appointmentRequestId);
            params.put('referencePhone', request.referencePhone);
            
            Map<String, Object> serviceResult = VolunteerAvailabilityService.bookSlotWithRandomVolunteer(params);
            return new BookingResult(
                (Boolean) serviceResult.get('success'),
                (String) serviceResult.get('message'),
                (Id) serviceResult.get('appointmentId')
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static Time convertMillisToTime(Long millis) {
        Integer totalSeconds = (Integer) (millis / 1000);
        Integer hours = totalSeconds / 3600;
        Integer minutes = Math.mod(totalSeconds / 60, 60);
        Integer seconds = Math.mod(totalSeconds, 60);
        return Time.newInstance(hours, minutes, seconds, 0);
    }
    
    @AuraEnabled(cacheable=true)
    public static AppointmentRequestInfo getAppointmentRequestInfo(Id requestId) {
        if (requestId == null) {
            return null;
        }
        List<Appointment_Request__c> requests = [
            SELECT Id, Reference_First_Name__c, Status__c 
            FROM Appointment_Request__c 
            WHERE Id = :requestId
            LIMIT 1
        ];
        if (requests.isEmpty()) {
            return null;
        }
        return new AppointmentRequestInfo(requests[0]);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AvailableSlotWrapper> getAllAvailableSlots() {
        Map<Id, List<Time_Slot__c>> slotsByVolunteer = TimeSlotSelector.getAvailableTimeSlotsForRange(null, null, null);
        List<AvailableSlotWrapper> results = new List<AvailableSlotWrapper>();
        
        for (Id volId : slotsByVolunteer.keySet()) {
            for (Time_Slot__c slot : slotsByVolunteer.get(volId)) {
                results.add(new AvailableSlotWrapper(slot));
            }
        }
        
        return results;
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
    
    public class AppointmentRequestInfo {
        @AuraEnabled public String referenceName;
        @AuraEnabled public String status;
        
        public AppointmentRequestInfo(Appointment_Request__c request) {
            this.referenceName = request.Reference_First_Name__c;
            this.status = request.Status__c;
        }
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
    
    public class BookingRequest {
        @AuraEnabled public String slotDate { get; set; }
        @AuraEnabled public Long startTime { get; set; }
        @AuraEnabled public Long endTime { get; set; }
        @AuraEnabled public Id appointmentRequestId { get; set; }
        @AuraEnabled public String referencePhone { get; set; }
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
