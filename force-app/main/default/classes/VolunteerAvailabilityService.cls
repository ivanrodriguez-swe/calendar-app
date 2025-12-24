public with sharing class VolunteerAvailabilityService {
    
    /**
     * Get available time slots for a date range
     */
    public static List<Map<String, Object>> getTimeslotsForRange(Date startDate, Date endDate) {
        List<Time_Slot__c> slots = TimeSlotSelector.getAvailableTimeSlotsForRange(startDate, endDate);
        List<Date> dates = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        List<String> timeRangeLabels = getTimeSlotStructureLabels();
        
        Map<String, Time_Slot__c> slotMap = buildSlotMap(slots);
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (String label : timeRangeLabels) {
            Map<String, Object> timeRangeData = new Map<String, Object>();
            timeRangeData.put('timeRangeLabel', label);
            
            List<Map<String, Object>> slotDataList = new List<Map<String, Object>>();
            for (Date day : dates) {
                String key = String.valueOf(day) + '-' + label;
                Time_Slot__c slot = slotMap.get(key);
                slotDataList.add(buildSlotData(slot, day));
            }
            
            timeRangeData.put('slotDataList', slotDataList);
            result.add(timeRangeData);
        }
        
        return result;
    }
    
    /**
     * Book a time slot
     */
    public static Map<String, Object> bookTimeSlot(Id timeSlotId, Id customerId, Id appointmentRequestId) {
        Time_Slot__c slot = getAndValidateTimeSlot(timeSlotId);
        Appointment_Request__c appointmentRequest = getOrCreateAppointmentRequest(slot, customerId, appointmentRequestId);
        Map<String, String> customerInfo = getCustomerInfo(appointmentRequest, customerId);
        
        Appointment__c appointment = new Appointment__c(
            Appointment_Request__c = appointmentRequest.Id,
            Time_Slot__c = timeSlotId,
            Status__c = 'Confirmed'
        );
        insert appointment;

        appointmentRequest.Status__c = 'Reserved';
        update appointmentRequest;
        slot.Status__c = 'Booked';
        update slot;

        BookingEmailService.sendBookingEmails(slot, customerInfo.get('name'), customerInfo.get('email'), appointment, appointmentRequest);

        return buildResult(true, 'Time slot booked successfully!', appointment.Id);
    }
    
    /**
     * Create time slots from availability ranges
     */
    public static Map<String, Object> createTimeSlotsFromRanges(List<Map<String, String>> ranges, Id volunteerId) {
        if (ranges == null || ranges.isEmpty()) {
            return buildResult(false, 'No availability ranges provided', 0);
        }
        
        List<Time_Slot__c> potentialSlots = buildSlotsFromRanges(ranges, volunteerId);
        List<Time_Slot__c> slotsToInsert = processTimeSlotsForInsert(potentialSlots);
        
        if (!slotsToInsert.isEmpty()) {
            insert slotsToInsert;
            return buildResult(true, 'Time slots processed successfully', slotsToInsert.size());
        }
        
        return buildResult(false, 'Availability for this time range was already set.', 0);
    }
    
    /**
     * Create time slots from CSV content
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
        List<Time_Slot__c> potentialSlots = buildSlotsFromCSVRows(csvRows, emailToUserIdMap);
        List<Time_Slot__c> slotsToInsert = processTimeSlotsForInsert(potentialSlots);
        
        if (!slotsToInsert.isEmpty()) {
            insert slotsToInsert;
        }
        
        return buildResult(true, 'Availability processed successfully', slotsToInsert.size());
    }
    
    /**
     * Get volunteer availability data organized by volunteer-date combination
     * Returns flattened structure: one row per volunteer-date with all time slots
     * All business logic handled here - controller just converts to wrappers
     * Supports pagination with offset and pageSize
     * 
     * @param startDate Start date for filtering (null to get all records)
     * @param endDate End date for filtering (null to get all records)
     * @param offset Number of records to skip (for pagination)
     * @param pageSize Maximum number of records to return (for pagination)
     * @return Map containing 'rows' (List of data), 'totalCount' (Integer), and 'hasMore' (Boolean)
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
            
            String timeLabel = TimeSlotFormatter.formatTime(slot.Start_Time__c) + 
                              ' - ' + 
                              TimeSlotFormatter.formatTime(slot.End_Time__c);
            
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
        Integer endIndex = (pageSize != null && pageSize > 0) ? 
                           Math.min(startIndex + pageSize, totalCount) : totalCount;
        
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
    
    /**
     * Comparator to sort by volunteer name, then by date
     */
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
            if (date1 == null && date2 == null) {
                return 0;
            }
            if (date1 == null) {
                return -1; // null dates come first
            }
            if (date2 == null) {
                return 1; // null dates come first
            }
            if (date1 < date2) {
                return -1;
            } else if (date1 > date2) {
                return 1;
            } else {
                return 0;
            }
        }
    }
    
    
    private static Map<String, Time_Slot__c> buildSlotMap(List<Time_Slot__c> slots) {
        Map<String, Time_Slot__c> slotMap = new Map<String, Time_Slot__c>();
        for (Time_Slot__c slot : slots) {
            String key = String.valueOf(slot.Day__c) + '-' + String.valueOf(slot.Start_Time__c) + '-' + String.valueOf(slot.End_Time__c);
            slotMap.put(key, slot);
        }
        return slotMap;
    }
    
    private static Map<String, Object> buildSlotData(Time_Slot__c slot, Date day) {
        Map<String, Object> slotData = new Map<String, Object>();
        if (slot != null) {
            slotData.put('id', slot.Id);
            slotData.put('startTime', slot.Start_Time__c);
            slotData.put('endTime', slot.End_Time__c);
            slotData.put('day', slot.Day__c);
            slotData.put('volunteerId', slot.Volunteer__c);
            slotData.put('volunteerName', slot.Volunteer__r != null ? slot.Volunteer__r.Name : null);
            slotData.put('isAvailable', true);
        } else {
            slotData.put('id', null);
            slotData.put('startTime', null);
            slotData.put('endTime', null);
            slotData.put('day', day);
            slotData.put('volunteerId', null);
            slotData.put('volunteerName', null);
            slotData.put('isAvailable', false);
        }
        return slotData;
    }
    
    private static Time_Slot__c getAndValidateTimeSlot(Id timeSlotId) {
        List<Time_Slot__c> slots = TimeSlotSelector.getTimeSlotById(timeSlotId);
        if (slots.isEmpty()) {
            throw new AuraHandledException('Time slot not found.');
        }
        
        Time_Slot__c slot = slots[0];
        if (slot.Status__c != 'Available') {
            throw new AuraHandledException('This time slot is no longer available.');
        }
        if (slot.Volunteer__c == null) {
            throw new AuraHandledException('No volunteer assigned to this time slot.');
        }
        return slot;
    }
    
    private static Appointment_Request__c getOrCreateAppointmentRequest(Time_Slot__c slot, Id customerId, Id appointmentRequestId) {
        if (appointmentRequestId != null) {
            List<Appointment_Request__c> requests = AppointmentRequestSelector.getAppointmentRequestById(appointmentRequestId);
            if (requests.isEmpty()) {
                throw new AuraHandledException('Appointment Request not found.');
            }
            
            Appointment_Request__c request = requests[0];
            if (request.Volunteer__c != slot.Volunteer__c) {
                throw new AuraHandledException('The selected time slot is not available for this appointment request.');
            }
            return request;
        }
        
        if (customerId == null) {
            throw new AuraHandledException('Appointment request information is required. Please use the link provided in your email.');
        }
        
        Appointment_Request__c request = new Appointment_Request__c(
            Volunteer__c = slot.Volunteer__c,
            Status__c = 'New'
        );
        insert request;
        return request;
    }
    
    private static Map<String, String> getCustomerInfo(Appointment_Request__c appointmentRequest, Id customerId) {
        Map<String, String> customerInfo = new Map<String, String>();
        
        if (appointmentRequest.Reference_Email__c != null) {
            String firstName = appointmentRequest.Reference_First_Name__c != null ? appointmentRequest.Reference_First_Name__c : '';
            String lastName = appointmentRequest.Reference_Last_Name__c != null ? appointmentRequest.Reference_Last_Name__c : '';
            customerInfo.put('name', (firstName + ' ' + lastName).trim());
            customerInfo.put('email', appointmentRequest.Reference_Email__c);
        } else {
            List<User> users = OHRUserSelector.getUserById(customerId);
            if (users.isEmpty()) {
                throw new AuraHandledException('Customer not found.');
            }
            customerInfo.put('name', users[0].Name);
            customerInfo.put('email', users[0].Email);
        }
        
        return customerInfo;
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
            
            Date slotDate = parseDate(dateValue);
            Time startTime = TimeSlotFormatter.parseTime(startTimeStr);
            Time endTime = TimeSlotFormatter.parseTime(endTimeStr);
            
            if (slotDate != null && startTime != null && endTime != null && 
                TimeSlotFormatter.isValidTimeRange(startTime, endTime)) {
                slots.addAll(generateTimeSlotsFromRange(slotDate, startTime, endTime, volunteerId));
            }
        }
        
        return slots;
    }
    
    private static Map<String, Id> buildEmailToUserIdMap(List<AvailabilityCSVParser.AvailabilityCSVRow> csvRows) {
        Set<String> emails = new Set<String>();
        for (AvailabilityCSVParser.AvailabilityCSVRow row : csvRows) {
            if (String.isNotBlank(row.volunteerEmail) && BookingEmailService.isValidEmail(row.volunteerEmail)) {
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
            
            Date slotDate = parseDate(row.dayValue);
            Time startTime = TimeSlotFormatter.parseTime(row.startTime);
            Time endTime = TimeSlotFormatter.parseTime(row.endTime);
            
            if (slotDate != null && startTime != null && endTime != null && 
                TimeSlotFormatter.isValidTimeRange(startTime, endTime)) {
                List<Time_Slot__c> generatedSlots = generateTimeSlotsFromRange(slotDate, startTime, endTime, volunteerId);
                slots.addAll(generatedSlots);
            }
        }
        
        return slots;
    }
    
    private static Date parseDate(String dateValue) {
        try {
            if (String.isBlank(dateValue)) {
                return null;
            }
            List<String> dateParts = dateValue.split('-');
            if (dateParts.size() != 3) {
                return null;
            }
            Date result = Date.newInstance(
                Integer.valueOf(dateParts[0]), 
                Integer.valueOf(dateParts[1]), 
                Integer.valueOf(dateParts[2])
            );
            return result;
        } catch (Exception e) {
            return null;
        }
    }
    
    private static List<String> getTimeSlotStructureLabels() {
        List<String> labels = new List<String>();
        Time businessStart = Time.newInstance(9, 0, 0, 0);
        Time businessEnd = Time.newInstance(16, 0, 0, 0);
        Integer slotMinutes = 15;
        Integer millis = slotMinutes * 60 * 1000;

        Time current = businessStart;
        while (current < businessEnd) {
            Time currentEnd = Time.newInstance(current.hour(), current.minute(), current.second(), current.millisecond()).addMilliseconds(millis);
            if (currentEnd > businessEnd) {
                currentEnd = businessEnd;
            }
            labels.add(String.valueOf(current) + '-' + String.valueOf(currentEnd));
            current = currentEnd;
        }
        return labels;
    }
    
    private static List<Time_Slot__c> generateTimeSlotsFromRange(Date slotDate, Time startTime, Time endTime, Id volunteerId) {
        List<Time_Slot__c> slots = new List<Time_Slot__c>();
        Integer slotMinutes = 15;
        
        Date normalizedDate = Date.newInstance(slotDate.year(), slotDate.month(), slotDate.day());
        
        Time currentStart = startTime;
        while (currentStart < endTime) {
            Integer startMinutes = currentStart.hour() * 60 + currentStart.minute();
            Integer endMinutes = startMinutes + slotMinutes;
            Integer endHour = endMinutes / 60;
            Integer endMinute = Math.mod(endMinutes, 60);
            
            if (endHour > 23) {
                endHour = 23;
                endMinute = 59;
            }
            
            Time calculatedEnd = Time.newInstance(endHour, endMinute, 0, 0);
            Time currentEnd = (calculatedEnd > endTime) ? endTime : calculatedEnd;
            
            Time_Slot__c ts = new Time_Slot__c();
            ts.Start_Time__c = currentStart;
            ts.End_Time__c = currentEnd;
            ts.Day__c = normalizedDate;
            ts.Status__c = 'Available';
            ts.Volunteer__c = volunteerId;
            
            slots.add(ts);
            currentStart = calculatedEnd;
            
            if (currentStart >= endTime) {
                break;
            }
        }
        
        return slots;
    }
    
    private static List<Time_Slot__c> processTimeSlotsForInsert(List<Time_Slot__c> potentialSlots) {
        Set<String> submissionKeys = new Set<String>();
        List<Time_Slot__c> deduplicated = new List<Time_Slot__c>();
        
        for (Time_Slot__c ts : potentialSlots) {
            String key = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
            if (!submissionKeys.contains(key)) {
                submissionKeys.add(key);
                deduplicated.add(ts);
            }
        }
        
        Set<Date> dates = new Set<Date>();
        Set<Id> volunteerIds = new Set<Id>();
        for (Time_Slot__c ts : deduplicated) {
            if (ts.Day__c != null) {
                dates.add(ts.Day__c);
            }
            if (ts.Volunteer__c != null) {
                volunteerIds.add(ts.Volunteer__c);
            }
        }
        
        List<Time_Slot__c> existing = new List<Time_Slot__c>();
        if (!dates.isEmpty() && !volunteerIds.isEmpty()) {
            existing = TimeSlotSelector.getExistingTimeSlotsByDatesAndVolunteers(dates, volunteerIds);
        }
        
        Set<String> existingKeys = new Set<String>();
        for (Time_Slot__c ts : existing) {
            existingKeys.add(buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c));
        }
        
        List<Time_Slot__c> toInsert = new List<Time_Slot__c>();
        Set<String> finalKeys = new Set<String>();
        
        for (Time_Slot__c ts : deduplicated) {
            String key = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
            if (!existingKeys.contains(key) && !finalKeys.contains(key)) {
                finalKeys.add(key);
                toInsert.add(ts);
            }
        }
        
        return toInsert;
    }
    
    private static String buildTimeSlotKey(Date day, Time startTime, Time endTime, Id volunteerId) {
        String dayStr = day != null ? String.valueOf(day) : '';
        String startStr = startTime != null ? String.valueOf(startTime) : '';
        String endStr = endTime != null ? String.valueOf(endTime) : '';
        String volunteerStr = volunteerId != null ? String.valueOf(volunteerId) : '';
        return dayStr + '|' + startStr + '|' + endStr + '|' + volunteerStr;
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
    
    /**
     * Get volunteer information for display
     * This service calls VolunteerDisplayService to get volunteer details
     * Services can call other services for business logic
     * @param volunteerId Volunteer (User) ID
     * @return Map containing success flag, message, and volunteer information
     */
    public static Map<String, Object> getVolunteerInfo(Id volunteerId) {
        if (volunteerId == null) {
            Map<String, Object> result = new Map<String, Object>();
            result.put('success', false);
            result.put('message', 'volunteerId is required');
            return result;
        }
        
        Map<String, Object> volunteerData = VolunteerDisplayService.getVolunteerById(volunteerId);
        
        if (volunteerData == null) {
            Map<String, Object> result = new Map<String, Object>();
            result.put('success', false);
            result.put('message', 'Volunteer not found');
            return result;
        }
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        result.put('volunteer', volunteerData);
        return result;
    }
    
    /**
     * Get all volunteers for selection/filtering
     * This service calls VolunteerDisplayService to get all volunteers
     * Services can call other services for business logic
     * @return Map containing list of volunteers and total count
     */
    public static Map<String, Object> getAllVolunteersForDisplay() {
        return VolunteerDisplayService.getAllVolunteers();
    }
}
