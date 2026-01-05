public with sharing class TimeSlotHelper {
    
    public static List<Time_Slot__c> generateTimeSlotsFromRange(Date slotDate, Time startTime, Time endTime, Id volunteerId) {
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
    
    public static List<Time_Slot__c> processTimeSlotsForInsert(List<Time_Slot__c> potentialSlots) {
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
    
    public static String buildTimeSlotKey(Date day, Time startTime, Time endTime, Id volunteerId) {
        String dayStr = day != null ? String.valueOf(day) : '';
        String startStr = startTime != null ? String.valueOf(startTime) : '';
        String endStr = endTime != null ? String.valueOf(endTime) : '';
        String volunteerStr = volunteerId != null ? String.valueOf(volunteerId) : '';
        return dayStr + '|' + startStr + '|' + endStr + '|' + volunteerStr;
    }
    
    public static List<String> getTimeSlotStructureLabels() {
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
    
    public static Date parseDate(String dateValue) {
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
}

