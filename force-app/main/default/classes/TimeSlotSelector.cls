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
    
    /**
     * Get all time slots (both Available and Booked) for a date range
     * If startDate and endDate are null, returns all time slots
     * @param startDate Start date (inclusive), null to get all records
     * @param endDate End date (inclusive), null to get all records
     * @return List of all time slots with volunteer information, ordered by volunteer name, date, and start time
     */
    public static List<Time_Slot__c> getAllTimeSlotsForRange(Date startDate, Date endDate) {
        if (startDate == null && endDate == null) {
            // Return all time slots if no date filter
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        } else if (startDate != null && endDate == null) {
            // Only startDate provided - single date or from startDate onwards
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                WHERE Day__c >= :startDate
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        } else if (startDate == null && endDate != null) {
            // Only endDate provided - up to endDate
            return [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                WHERE Day__c <= :endDate
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
        } else {
            // Both dates provided - filter by date range (inclusive on both ends)
            // If startDate equals endDate, returns records for that specific date
            // If startDate < endDate, returns records within the date range (inclusive)
            // Returns all time slots where Day__c is between startDate and endDate (inclusive)
            
            // Debug logging
            System.debug('Selector query - startDate: ' + startDate + ' (type: ' + (startDate != null ? String.valueOf(startDate) : 'null') + ')');
            System.debug('Selector query - endDate: ' + endDate + ' (type: ' + (endDate != null ? String.valueOf(endDate) : 'null') + ')');
            System.debug('Selector query - startDate == endDate: ' + (startDate == endDate));
            if (startDate != null && endDate != null) {
                System.debug('Selector query - startDate.compareTo(endDate): ' + startDate.daysBetween(endDate));
            }
            
            // Use inclusive range query - works for both single date and date range
            List<Time_Slot__c> results = [
                SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, 
                       Volunteer__c, Volunteer__r.Name, Volunteer__r.Email
                FROM Time_Slot__c
                WHERE Day__c >= :startDate AND Day__c <= :endDate
                ORDER BY Volunteer__r.Name, Day__c, Start_Time__c
            ];
            
            System.debug('Selector returned ' + results.size() + ' records');
            if (!results.isEmpty()) {
                System.debug('First record Day__c: ' + results[0].Day__c);
                System.debug('Last record Day__c: ' + results[results.size() - 1].Day__c);
            } else {
                // Debug: Check if there are any records at all for debugging
                List<Time_Slot__c> allSlots = [SELECT Id, Day__c FROM Time_Slot__c LIMIT 5];
                System.debug('Sample records in database (first 5):');
                for (Time_Slot__c slot : allSlots) {
                    System.debug('  Slot Day__c: ' + slot.Day__c);
                }
            }
            
            return results;
        }
    }
}

