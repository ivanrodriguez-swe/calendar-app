// Service class for volunteer availability business logic
// Uses 'with sharing' for security
// Works with raw data (SObjects, primitives) - no wrapper classes
public with sharing class VolunteerAvailabilityService {
    
    /**
     * Get available time slots for a date range
     * Returns organized data structure ready for presentation layer
     */
    public static List<Map<String, Object>> getTimeslotsForRange(Date startDate, Date endDate) {
        List<Time_Slot__c> slots = TimeSlotSelector.getAvailableTimeSlotsForRange(startDate, endDate);
        List<Date> dates = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        List<String> timeRangeLabels = getTimeSlotStructureLabels();
        
        // Build lookup map: "date-timeRange" -> Time_Slot__c
        Map<String, Time_Slot__c> slotMap = buildSlotMap(slots);
        
        // Organize by time range
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
    
    // Private helper methods
    
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
            // From appointment request
            String firstName = appointmentRequest.Reference_First_Name__c != null ? appointmentRequest.Reference_First_Name__c : '';
            String lastName = appointmentRequest.Reference_Last_Name__c != null ? appointmentRequest.Reference_Last_Name__c : '';
            customerInfo.put('name', (firstName + ' ' + lastName).trim());
            customerInfo.put('email', appointmentRequest.Reference_Email__c);
        } else {
            // From customer user
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
                slots.addAll(generateTimeSlotsFromRange(slotDate, startTime, endTime, volunteerId));
            }
        }
        
        return slots;
    }
    
    private static Date parseDate(String dateValue) {
        try {
            return String.isNotBlank(dateValue) ? Date.valueOf(dateValue) : null;
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
            ts.Day__c = slotDate;
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
        // Deduplicate within submission
        Set<String> submissionKeys = new Set<String>();
        List<Time_Slot__c> deduplicated = new List<Time_Slot__c>();
        
        for (Time_Slot__c ts : potentialSlots) {
            String key = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
            if (!submissionKeys.contains(key)) {
                submissionKeys.add(key);
                deduplicated.add(ts);
            }
        }
        
        // Check existing in database - collect dates and volunteer IDs
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
        
        // Filter duplicates
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
}
