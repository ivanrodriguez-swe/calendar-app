public with sharing class TimeslotController {
    @AuraEnabled(cacheable=true)
    public static List<DayWrapper> getTimeslotsForRange(Date startDate, Date endDate) {

        List<DayWrapper> results = createSlotShell();
        
        
        // Defensive checks
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('startDate and endDate are required.');
        }
        // Query timeslots whose day__c is between startDate and endDate and status__c == 'Available'
        List<time_slot__c> slots = [
            SELECT Id, Start_Time__c, End_Time__c, Day__c, Number_Available__c, Status__c
            FROM time_slot__c
            WHERE Day__c >= :startDate AND Day__c <= :endDate
            AND Status__c = 'Available'
            ORDER BY Start_Time__c
        ];

        Map<string,TimeslotWrapper> timeSlotMap = new Map<string,TimeslotWrapper>();

        for (time_slot__c t : slots) {
            timeSlotMap.put(t.Day__c+'-'+t.Start_Time__c+'-'+t.End_Time__c, new TimeslotWrapper(t.Id, t.Start_Time__c, t.End_Time__c, t.Day__c, Integer.valueOf(t.Number_Available__c)));
        }

        system.debug(timeSlotMap);


        List<Date> avilabledates = getDatesBetween(startDate, endDate, true);
        system.debug(avilabledates);
        for (DayWrapper dw : results) {
            For(date day: avilabledates){
                system.debug(day);
                if(timeSlotMap.get(day+'-'+dw.label)!=null){
                    dw.slots.add(timeSlotMap.get(day+'-'+dw.label));
                }else{
                    dw.slots.add(new TimeslotWrapper(dw.label,day));
                }
            }
        }


        return results;
    }


    public static List<DayWrapper> createSlotShell(){
        List<DayWrapper> result =  new List<DayWrapper>();
        Time businessStart = Time.newInstance(9, 0, 0, 0);   // 9:00 AM
        Time businessEnd   = Time.newInstance(17, 0, 0, 0);  // 5:00 PM
        Integer slotMinutes = 20;

        Time currentStart = businessStart;
        while (currentStart < businessEnd) {
            // compute end time for this slot
            Integer millis = slotMinutes * 60 * 1000;
            Time currentEnd = Time.newInstance(currentStart.hour(), currentStart.minute(), currentStart.second(), currentStart.millisecond()).addMilliseconds(millis);

            // Ensure we do not create a slot that extends beyond businessEnd
            if (currentEnd > businessEnd) {
                currentEnd = businessEnd;
            }
            result.add(new DayWrapper(currentStart, currentEnd));
            // advance to next slot
            currentStart = currentEnd;
        }

        return result;
    }

    public static List<Date> getDatesBetween(Date startDate, Date endDate, Boolean inclusive) {
        if (startDate == null || endDate == null) {
            throw new IllegalArgumentException('startDate and endDate must not be null.');
        }
        if (inclusive == null) {
            inclusive = true;
        }
        // If startDate > endDate swap or throw depending on desired behavior. Here we'll throw.
        if (startDate > endDate) {
            throw new IllegalArgumentException('startDate must be on or before endDate.');
        }

        // Compute number of days difference (inclusive or exclusive)
        Integer daysDiff = startDate.daysBetween(endDate); // daysBetween returns positive when endDate > startDate
        // daysBetween is (end - start) in days; if inclusive we add 1
        Integer totalDays = daysDiff + (inclusive ? 1 : 0);
        System.debug(daysDiff);
        System.debug(totalDays);
        if (totalDays <= 0) {
            // no days to return (possible when start==end and inclusive=false)
            return new List<Date>();
        }

        List<Date> result = new List<Date>();
        Date cursor = startDate;
        for (Integer i = 0; i < totalDays; i++) {
            result.add(cursor);
            cursor = cursor.addDays(1);
        }
        return result;
    }


    // Simple serializable wrapper

    public class DayWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public List<TimeslotWrapper> slots;
        
        public DayWrapper(Time startTime, Time endTime){
            this.label = startTime+'-'+endTime;
            this.slots = new List<TimeslotWrapper>();
        }
    }


    public class TimeslotWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public Date day;
        @AuraEnabled public Integer numberAvailable;
        @AuraEnabled public String label;


        public TimeslotWrapper(Id id, Time startTime, Time endTime, Date day, Integer numberAvailable) {
            this.id = id;
            this.startTime = startTime;
            this.endTime = endTime;
            this.day = day;
            this.numberAvailable = numberAvailable;
            this.label = day+'-'+startTime+'-'+endTime;
        }

        public TimeslotWrapper(string label, Date day) {
            this.id = null;
            this.startTime = null;
            this.endTime = null;
            this.day = day;
            this.numberAvailable = 0;
            this.label = label;
        }
    }
}