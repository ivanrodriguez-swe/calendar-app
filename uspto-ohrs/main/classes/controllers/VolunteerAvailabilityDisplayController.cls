/**
 * @description Controller for volunteer availability display exposed to LWC
 */
public without sharing class VolunteerAvailabilityDisplayController {
    
    /**
     * @description Retrieves volunteer availability data with pagination
     * @param startDate Start date filter (YYYY-MM-DD format)
     * @param endDate End date filter (YYYY-MM-DD format)
     * @param offset Pagination offset
     * @param pageSize Number of records per page
     * @return VolunteerAvailabilityResult with rows and pagination info
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
}
