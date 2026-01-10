public inherited sharing class TimeSlotSelector {
    
    public static Map<Id, List<Time_Slot__c>> getAvailableTimeSlotsForRange(Date startDate, Date endDate, Set<Id> volunteerIds) {
        String query = 'SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, Volunteer__c, Volunteer__r.Name ' +
                       'FROM Time_Slot__c ' +
                       'WHERE Status__c = \'Available\'';
        
        if (startDate != null) {
            query += ' AND Day__c >= :startDate';
        }
        if (endDate != null) {
            query += ' AND Day__c <= :endDate';
        }
        if (volunteerIds != null && !volunteerIds.isEmpty()) {
            query += ' AND Volunteer__c IN :volunteerIds';
        }
        query += ' ORDER BY Day__c, Start_Time__c';
        
        DateTime nowDT = DateTime.now().addMinutes(15);
        Date today = Date.today();
        Time currentTime = Time.newInstance(nowDT.hour(), nowDT.minute(), 0, 0);
        
        Map<Id, List<Time_Slot__c>> result = new Map<Id, List<Time_Slot__c>>();
        for (Time_Slot__c slot : Database.query(query)) {
            if (slot.Day__c < today) {
                continue;
            }
            if (slot.Day__c == today && slot.Start_Time__c != null && slot.Start_Time__c <= currentTime) {
                continue;
            }
            
            if (!result.containsKey(slot.Volunteer__c)) {
                result.put(slot.Volunteer__c, new List<Time_Slot__c>());
            }
            result.get(slot.Volunteer__c).add(slot);
        }
        return result;
    }
    
    public static List<Time_Slot__c> getTimeSlotById(Id timeSlotId) {
        return [
            SELECT Id, Volunteer__c, Volunteer__r.Email, Volunteer__r.Name, 
                   Day__c, Start_Time__c, End_Time__c, Status__c
            FROM Time_Slot__c
            WHERE Id = :timeSlotId
            LIMIT 1
        ];
    }
    
    public static List<Time_Slot__c> getExistingTimeSlotsByDatesAndVolunteers(Set<Date> dates, Set<Id> volunteerIds) {
        return [
            SELECT Day__c, Start_Time__c, End_Time__c, Volunteer__c
            FROM Time_Slot__c
            WHERE Day__c IN :dates
            AND Volunteer__c IN :volunteerIds
        ];
    }
    
    public static List<Time_Slot__c> getAllTimeSlotsForRange(Date startDate, Date endDate) {
        if (startDate == null && endDate == null) {
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        } else if (startDate != null && endDate == null) {
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                WHERE Day__c >= :startDate
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        } else if (startDate == null && endDate != null) {
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                WHERE Day__c <= :endDate
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        } else {
            Date normalizedStartDate = Date.newInstance(startDate.year(), startDate.month(), startDate.day());
            Date normalizedEndDate = Date.newInstance(endDate.year(), endDate.month(), endDate.day());
            
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                WHERE Day__c >= :normalizedStartDate AND Day__c <= :normalizedEndDate
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        }
    }
    
    public static List<Time_Slot__c> getAvailableSlotsByDateTime(Date slotDate, Time startTime, Time endTime) {
        return [
            SELECT Id, Volunteer__c, Volunteer__r.Email, Volunteer__r.Name, 
                   Day__c, Start_Time__c, End_Time__c
            FROM Time_Slot__c
            WHERE Day__c = :slotDate
            AND Start_Time__c = :startTime
            AND End_Time__c = :endTime
            AND Status__c = 'Available'
        ];
    }
}
