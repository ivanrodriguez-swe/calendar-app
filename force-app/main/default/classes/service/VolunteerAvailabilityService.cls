/**
 * @description Service class for managing volunteer availability and time slot booking
 */
public without sharing class VolunteerAvailabilityService {
    
    /**
     * @description Books a time slot with a randomly selected volunteer
     * @param bookingParams Map containing slotDate, startTime, endTime, appointmentRequestId, referencePhone
     * @return Map with success status, message, and appointmentId
     */
    public static Map<String, Object> bookSlotWithRandomVolunteer(Map<String, Object> bookingParams) {
        Date slotDate = (Date) bookingParams.get('slotDate');
        Time startTime = (Time) bookingParams.get('startTime');
        Time endTime = (Time) bookingParams.get('endTime');
        Id appointmentRequestId = (Id) bookingParams.get('appointmentRequestId');
        String referencePhone = (String) bookingParams.get('referencePhone');
        
        List<Time_Slot__c> availableSlots = TimeSlotSelector.getAvailableSlotsByDateTime(slotDate, startTime, endTime);
        
        if (availableSlots.isEmpty()) {
            throw new AuraHandledException('This time slot is no longer available. Please refresh and select another.');
        }
        
        Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), availableSlots.size());
        Time_Slot__c selectedSlot = availableSlots[randomIndex];
        
        List<Appointment_Request__c> requests = AppointmentRequestSelector.getAppointmentRequestById(appointmentRequestId);
        if (requests.isEmpty()) {
            throw new AuraHandledException('Appointment Request not found.');
        }
        Appointment_Request__c appointmentRequest = requests[0];
        
        Appointment__c appointment = new Appointment__c(
            Appointment_Request__c = appointmentRequest.Id,
            Time_Slot__c = selectedSlot.Id,
            Status__c = 'Confirmed',
            Reference_Email__c = appointmentRequest.Reference_Email__c,
            Volunteer_Email__c = selectedSlot.Volunteer__r.Email
        );
        insert appointment;
        
        appointmentRequest.Volunteer__c = selectedSlot.Volunteer__c;
        appointmentRequest.Status__c = 'Reserved';
        if (String.isNotBlank(referencePhone)) {
            appointmentRequest.Reference_Phone_Number__c = referencePhone;
        }
        update appointmentRequest;
        
        selectedSlot.Status__c = 'Booked';
        update selectedSlot;
        
        return buildResult(true, 'Time slot booked successfully!', appointment.Id);
    }
    
    /**
     * @description Creates time slots from availability ranges for a volunteer
     * @param ranges List of maps containing dateValue, startTime, endTime
     * @param volunteerId The volunteer's User Id
     * @return Map with success status, message, and slotsCreated count
     */
    public static Map<String, Object> createTimeSlotsFromRanges(List<Map<String, String>> ranges, Id volunteerId) {
        if (ranges == null || ranges.isEmpty()) {
            return buildResult(false, 'No availability ranges provided', 0);
        }
        
        List<Time_Slot__c> potentialSlots = buildSlotsFromRanges(ranges, volunteerId);
        List<Time_Slot__c> slotsToInsert = TimeSlotHelper.processTimeSlotsForInsert(potentialSlots);
        
        if (!slotsToInsert.isEmpty()) {
            insert slotsToInsert;
            return buildResult(true, 'Time slots processed successfully', slotsToInsert.size());
        }
        
        return buildResult(false, 'Availability for this time range was already set.', 0);
    }
    
    /**
     * @description Creates time slots from CSV content for multiple volunteers
     * @param csvContent The CSV file content as a string
     * @return Map with success status, message, slotsCreated count, and warnings
     */
    public static Map<String, Object> createTimeSlotsFromCSV(String csvContent) {
        if (String.isBlank(csvContent)) {
            return buildResult(false, 'CSV content is empty', 0);
        }
        
        List<AvailabilityCSVParser.AvailabilityCSVRow> csvRows = AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        if (csvRows.isEmpty()) {
            return buildResult(false, 'No valid records found in CSV', 0);
        }
        
        Map<String, Id> emailToUserIdMap = buildEmailToUserIdMap(csvRows);
        
        List<String> warnings = new List<String>();
        Set<String> notFoundEmails = new Set<String>();
        for (AvailabilityCSVParser.AvailabilityCSVRow row : csvRows) {
            String emailKey = row.volunteerEmail.toLowerCase();
            if (!emailToUserIdMap.containsKey(emailKey) && !notFoundEmails.contains(emailKey)) {
                notFoundEmails.add(emailKey);
                warnings.add(row.volunteerEmail);
            }
        }
        
        List<Time_Slot__c> potentialSlots = buildSlotsFromCSVRows(csvRows, emailToUserIdMap);
        List<Time_Slot__c> slotsToInsert = TimeSlotHelper.processTimeSlotsForInsert(potentialSlots);
        
        if (!slotsToInsert.isEmpty()) {
            insert slotsToInsert;
        }
        
        Map<String, Object> result = buildResult(true, 'Availability processed successfully', slotsToInsert.size());
        result.put('warnings', warnings);
        return result;
    }
    
    /**
     * @description Retrieves volunteer availability data with pagination
     * @param startDate Start of date range filter
     * @param endDate End of date range filter
     * @param offset Pagination offset
     * @param pageSize Number of records per page
     * @return Map with rows, totalCount, and hasMore flag
     */
    public static Map<String, Object> getVolunteerAvailabilityData(Date startDate, Date endDate, Integer offset, Integer pageSize) {
        List<Time_Slot__c> slots = TimeSlotSelector.getAllTimeSlotsForRange(startDate, endDate);
        
        Map<String, Map<String, Object>> volunteerDateMap = new Map<String, Map<String, Object>>();
        
        for (Time_Slot__c slot : slots) {
            String key = String.valueOf(slot.Volunteer__c) + '-' + String.valueOf(slot.Day__c);
            
            if (!volunteerDateMap.containsKey(key)) {
                Map<String, Object> rowData = new Map<String, Object>();
                rowData.put('volunteerId', slot.Volunteer__c);
                rowData.put('volunteerName', slot.Volunteer__r != null ? slot.Volunteer__r.Name : null);
                rowData.put('volunteerEmail', slot.Volunteer__r != null ? slot.Volunteer__r.Email : null);
                rowData.put('date', slot.Day__c);
                rowData.put('timeSlots', new List<Map<String, Object>>());
                volunteerDateMap.put(key, rowData);
            }
            
            Map<String, Object> rowData = volunteerDateMap.get(key);
            List<Map<String, Object>> timeSlots = (List<Map<String, Object>>) rowData.get('timeSlots');
            
            String timeLabel = TimeSlotFormatter.formatTime(slot.Start_Time__c) + ' - ' + TimeSlotFormatter.formatTime(slot.End_Time__c);
            
            Map<String, Object> slotData = new Map<String, Object>();
            slotData.put('id', slot.Id);
            slotData.put('startTime', slot.Start_Time__c);
            slotData.put('endTime', slot.End_Time__c);
            slotData.put('status', slot.Status__c);
            slotData.put('timeLabel', timeLabel);
            timeSlots.add(slotData);
        }
        
        List<Map<String, Object>> allRows = new List<Map<String, Object>>(volunteerDateMap.values());
        allRows.sort(new VolunteerDateComparator());
        
        Integer totalCount = allRows.size();
        Integer startIndex = offset != null ? offset : 0;
        Integer endIndex = (pageSize != null && pageSize > 0) ? Math.min(startIndex + pageSize, totalCount) : totalCount;
        
        List<Map<String, Object>> paginatedRows = new List<Map<String, Object>>();
        for (Integer i = startIndex; i < endIndex; i++) {
            paginatedRows.add(allRows[i]);
        }
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('rows', paginatedRows);
        result.put('totalCount', totalCount);
        result.put('hasMore', endIndex < totalCount);
        
        return result;
    }
    
    private class VolunteerDateComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> m1, Map<String, Object> m2) {
            String name1 = (String) m1.get('volunteerName');
            String name2 = (String) m2.get('volunteerName');
            if (name1 == null) name1 = '';
            if (name2 == null) name2 = '';
            Integer nameCompare = name1.compareTo(name2);
            if (nameCompare != 0) {
                return nameCompare;
            }
            Date date1 = (Date) m1.get('date');
            Date date2 = (Date) m2.get('date');
            if (date1 == null && date2 == null) return 0;
            if (date1 == null) return -1;
            if (date2 == null) return 1;
            if (date1 < date2) return -1;
            if (date1 > date2) return 1;
            return 0;
        }
    }
    
    private static List<Time_Slot__c> buildSlotsFromRanges(List<Map<String, String>> ranges, Id volunteerId) {
        List<Time_Slot__c> slots = new List<Time_Slot__c>();
        
        for (Map<String, String> range : ranges) {
            String dateValue = range.get('dateValue');
            String startTimeStr = range.get('startTime');
            String endTimeStr = range.get('endTime');
            
            if (String.isBlank(dateValue) || String.isBlank(startTimeStr) || String.isBlank(endTimeStr)) {
                continue;
            }
            
            Date slotDate = TimeSlotHelper.parseDate(dateValue);
            Time startTime = TimeSlotFormatter.parseTime(startTimeStr);
            Time endTime = TimeSlotFormatter.parseTime(endTimeStr);
            
            if (slotDate != null && startTime != null && endTime != null && TimeSlotFormatter.isValidTimeRange(startTime, endTime)) {
                slots.addAll(TimeSlotHelper.generateTimeSlotsFromRange(slotDate, startTime, endTime, volunteerId));
            }
        }
        
        return slots;
    }
    
    private static Map<String, Id> buildEmailToUserIdMap(List<AvailabilityCSVParser.AvailabilityCSVRow> csvRows) {
        Set<String> emails = new Set<String>();
        for (AvailabilityCSVParser.AvailabilityCSVRow row : csvRows) {
            if (String.isNotBlank(row.volunteerEmail) && AppointmentRequestStatusService.isValidEmail(row.volunteerEmail)) {
                emails.add(row.volunteerEmail.toLowerCase());
            }
        }
        
        Map<String, Id> emailMap = new Map<String, Id>();
        if (!emails.isEmpty()) {
            for (User u : OHRUserSelector.getUsersByEmails(emails)) {
                emailMap.put(u.Email.toLowerCase(), u.Id);
            }
        }
        return emailMap;
    }
    
    private static List<Time_Slot__c> buildSlotsFromCSVRows(List<AvailabilityCSVParser.AvailabilityCSVRow> csvRows, Map<String, Id> emailToUserIdMap) {
        List<Time_Slot__c> slots = new List<Time_Slot__c>();
        
        for (AvailabilityCSVParser.AvailabilityCSVRow row : csvRows) {
            Id volunteerId = emailToUserIdMap.get(String.isNotBlank(row.volunteerEmail) ? row.volunteerEmail.toLowerCase() : '');
            if (volunteerId == null) {
                continue;
            }
            
            Date slotDate = TimeSlotHelper.parseDate(row.dayValue);
            Time startTime = TimeSlotFormatter.parseTime(row.startTime);
            Time endTime = TimeSlotFormatter.parseTime(row.endTime);
            
            if (slotDate != null && startTime != null && endTime != null && TimeSlotFormatter.isValidTimeRange(startTime, endTime)) {
                slots.addAll(TimeSlotHelper.generateTimeSlotsFromRange(slotDate, startTime, endTime, volunteerId));
            }
        }
        
        return slots;
    }
    
    private static Map<String, Object> buildResult(Boolean success, String message, Integer slotsCreated) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', success);
        result.put('message', message);
        result.put('slotsCreated', slotsCreated);
        return result;
    }
    
    private static Map<String, Object> buildResult(Boolean success, String message, Id appointmentId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', success);
        result.put('message', message);
        result.put('appointmentId', appointmentId);
        return result;
    }
}
