public without sharing class VolunteerAvailabilityDisplayController {
    
    /**
     * Get volunteer availability data
     * @param startDate Start date (YYYY-MM-DD) or null
     * @param endDate End date (YYYY-MM-DD) or null
     * @param offset Pagination offset
     * @param pageSize Page size
     * @return VolunteerAvailabilityResult
     */
    @AuraEnabled
    public static VolunteerAvailabilityResult getVolunteerAvailabilityData(String startDate, String endDate, Integer offset, Integer pageSize) {
        try {
            Date normalizedStartDate = null;
            Date normalizedEndDate = null;
            
            if (String.isNotBlank(startDate)) {
                try {
                    List<String> dateParts = startDate.split('-');
                    if (dateParts.size() != 3) {
                        throw new AuraHandledException('Invalid start date format: ' + startDate + '. Expected YYYY-MM-DD format.');
                    }
                    normalizedStartDate = Date.newInstance(
                        Integer.valueOf(dateParts[0]), 
                        Integer.valueOf(dateParts[1]), 
                        Integer.valueOf(dateParts[2])
                    );
                } catch (Exception e) {
                    throw new AuraHandledException('Invalid start date format: ' + startDate + '. Expected YYYY-MM-DD format. Error: ' + e.getMessage());
                }
            }
            
            if (String.isNotBlank(endDate)) {
                try {
                    List<String> dateParts = endDate.split('-');
                    if (dateParts.size() != 3) {
                        throw new AuraHandledException('Invalid end date format: ' + endDate + '. Expected YYYY-MM-DD format.');
                    }
                    normalizedEndDate = Date.newInstance(
                        Integer.valueOf(dateParts[0]), 
                        Integer.valueOf(dateParts[1]), 
                        Integer.valueOf(dateParts[2])
                    );
                } catch (Exception e) {
                    throw new AuraHandledException('Invalid end date format: ' + endDate + '. Expected YYYY-MM-DD format. Error: ' + e.getMessage());
                }
            }
            
            Integer offsetValue = offset != null ? offset : 0;
            Integer pageSizeValue = (pageSize != null && pageSize > 0) ? pageSize : 50;
            
            Map<String, Object> serviceResult = 
                VolunteerAvailabilityService.getVolunteerAvailabilityData(normalizedStartDate, normalizedEndDate, offsetValue, pageSizeValue);
            
            List<Map<String, Object>> serviceRows = (List<Map<String, Object>>) serviceResult.get('rows');
            List<VolunteerAvailabilityRow> rows = convertToVolunteerAvailabilityRows(serviceRows);
            
            VolunteerAvailabilityResult result = new VolunteerAvailabilityResult();
            result.rows = rows;
            result.totalCount = (Integer) serviceResult.get('totalCount');
            result.hasMore = (Boolean) serviceResult.get('hasMore');
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving volunteer availability data: ' + e.getMessage());
        }
    }
    
    /**
     * Get volunteer information
     * @param volunteerId Volunteer ID
     * @return VolunteerInfoResult
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerInfoResult getVolunteerInfo(Id volunteerId) {
        if (volunteerId == null) {
            throw new AuraHandledException('volunteerId is required.');
        }
        
        Map<String, Object> serviceResult = VolunteerAvailabilityService.getVolunteerInfo(volunteerId);
        
        if (serviceResult == null || !(Boolean) serviceResult.get('success')) {
            VolunteerInfoResult result = new VolunteerInfoResult();
            result.success = false;
            result.message = (String) serviceResult?.get('message') ?? 'Volunteer not found';
            return result;
        }
        
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
     * Get all volunteers
     * @return VolunteerListResult
     */
    @AuraEnabled(cacheable=true)
    public static VolunteerListResult getAllVolunteersForDisplay() {
        Map<String, Object> serviceResult = VolunteerAvailabilityService.getAllVolunteersForDisplay();
        
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
                tsd.timeLabel = (String) slotData.get('timeLabel');
                row.timeSlots.add(tsd);
            }
            
            rows.add(row);
        }
        
        return rows;
    }

    public class VolunteerAvailabilityRow {
        @AuraEnabled public Id volunteerId;
        @AuraEnabled public String volunteerName;
        @AuraEnabled public String volunteerEmail;
        @AuraEnabled public Date slotDate;
        @AuraEnabled public List<TimeSlotData> timeSlots;
    }
    
    public class TimeSlotData {
        @AuraEnabled public Id id;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String status;
        @AuraEnabled public String timeLabel;
    }
    
    public class VolunteerAvailabilityResult {
        @AuraEnabled public List<VolunteerAvailabilityRow> rows;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean hasMore;
    }
    
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


