// Selector class for Time_Slot__c object
// Uses inherited sharing to inherit sharing context from caller
public inherited sharing class TimeSlotSelector {
    
    /**
     * Get available time slots for a date range
     * @param startDate Start date (inclusive)
     * @param endDate End date (inclusive)
     * @return List of available time slots with volunteer information
     */
    public static List<Time_Slot__c> getAvailableTimeSlotsForRange(Date startDate, Date endDate) {
        return [
            SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, Volunteer__c, Volunteer__r.Name
            FROM Time_Slot__c
            WHERE Day__c >= :startDate AND Day__c <= :endDate
            AND Status__c = 'Available'
            ORDER BY Start_Time__c
        ];
    }
    
    /**
     * Get a single time slot by ID with volunteer details
     * @param timeSlotId Time slot record ID
     * @return Time slot with volunteer email and name
     */
    public static List<Time_Slot__c> getTimeSlotById(Id timeSlotId) {
        return [
            SELECT Id, Volunteer__c, Volunteer__r.Email, Volunteer__r.Name, 
                   Day__c, Start_Time__c, End_Time__c, Status__c
            FROM Time_Slot__c
            WHERE Id = :timeSlotId
            LIMIT 1
        ];
    }
    
    /**
     * Get existing time slots by dates and volunteer IDs
     * @param dates Set of dates to query
     * @param volunteerIds Set of volunteer IDs to query
     * @return List of existing time slots matching the criteria
     */
    public static List<Time_Slot__c> getExistingTimeSlotsByDatesAndVolunteers(Set<Date> dates, Set<Id> volunteerIds) {
        return [
            SELECT Day__c, Start_Time__c, End_Time__c, Volunteer__c
            FROM Time_Slot__c
            WHERE Day__c IN :dates
            AND Volunteer__c IN :volunteerIds
        ];
    }
}

