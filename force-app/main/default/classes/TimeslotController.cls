public with sharing class TimeslotController {
    @AuraEnabled(cacheable=true)
    public static List<DayWrapper> getTimeslotsForRange(Date startDate, Date endDate) {

        List<DayWrapper> results = createSlotShell();
        
        
        // Defensive checks
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('startDate and endDate are required.');
        }
        // Query timeslots whose day__c is between startDate and endDate and status__c == 'Available'
        List<Time_Slot__c> slots = [
            SELECT Id, Start_Time__c, End_Time__c, Day__c, Number_Available__c, Status__c, Agent__c, Agent__r.Name, Agent__r.Email
            FROM Time_Slot__c
            WHERE Day__c >= :startDate AND Day__c <= :endDate
            AND Status__c = 'Available'
            ORDER BY Start_Time__c
        ];

        Map<string,TimeslotWrapper> timeSlotMap = new Map<string,TimeslotWrapper>();

        for (Time_Slot__c t : slots) {
            timeSlotMap.put(t.Day__c+'-'+t.Start_Time__c+'-'+t.End_Time__c, new TimeslotWrapper(t.Id, t.Start_Time__c, t.End_Time__c, t.Day__c, Integer.valueOf(t.Number_Available__c), t.Agent__c, t.Agent__r.Name));
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
        @AuraEnabled public Id agentId;
        @AuraEnabled public String agentName;


        public TimeslotWrapper(Id id, Time startTime, Time endTime, Date day, Integer numberAvailable, Id agentId, String agentName) {
            this.id = id;
            this.startTime = startTime;
            this.endTime = endTime;
            this.day = day;
            this.numberAvailable = numberAvailable;
            this.label = day+'-'+startTime+'-'+endTime;
            this.agentId = agentId;
            this.agentName = agentName;
        }

        public TimeslotWrapper(string label, Date day) {
            this.id = null;
            this.startTime = null;
            this.endTime = null;
            this.day = day;
            this.numberAvailable = 0;
            this.label = label;
            this.agentId = null;
            this.agentName = null;
        }
    }

    // Get list of available agents (Users with specific profile or permission set)
    @AuraEnabled(cacheable=true)
    public static List<User> getAvailableAgents() {
        // Query users who are agents - you may want to filter by profile or permission set
        // For now, returning all active users. Adjust based on your requirements
        return [
            SELECT Id, Name, Email
            FROM User
            WHERE IsActive = true
            ORDER BY Name
            LIMIT 100
        ];
    }

    // Book a time slot
    @AuraEnabled
    public static BookingResult bookTimeSlot(Id timeSlotId, Id customerId, Id appointmentRequestId) {
        try {
            // Query the time slot with agent information
            List<Time_Slot__c> slots = [
                SELECT Id, Agent__c, Agent__r.Email, Agent__r.Name, 
                       Day__c, Start_Time__c, End_Time__c, 
                       Number_Available__c, Status__c
                FROM Time_Slot__c
                WHERE Id = :timeSlotId
                LIMIT 1
            ];

            if (slots.isEmpty()) {
                throw new AuraHandledException('Time slot not found.');
            }

            Time_Slot__c slot = slots[0];

            if (slot.Status__c != 'Available' || slot.Number_Available__c <= 0) {
                throw new AuraHandledException('This time slot is no longer available.');
            }

            if (slot.Agent__c == null) {
                throw new AuraHandledException('No agent assigned to this time slot.');
            }

            // Get customer information
            User customer = [SELECT Id, Name, Email FROM User WHERE Id = :customerId LIMIT 1];

            // Use existing Appointment Request if provided, otherwise create new one
            Appointment_Request__c appointmentRequest;
            if (appointmentRequestId != null) {
                // Query existing appointment request
                List<Appointment_Request__c> existingRequests = [
                    SELECT Id, Agent__c, Status__c 
                    FROM Appointment_Request__c 
                    WHERE Id = :appointmentRequestId 
                    LIMIT 1
                ];
                
                if (existingRequests.isEmpty()) {
                    throw new AuraHandledException('Appointment Request not found.');
                }
                
                appointmentRequest = existingRequests[0];
                
                // Verify the agent matches
                if (appointmentRequest.Agent__c != slot.Agent__c) {
                    throw new AuraHandledException('The selected time slot is not available for this appointment request.');
                }
            } else {
                // Create new Appointment Request
                appointmentRequest = new Appointment_Request__c(
                    Agent__c = slot.Agent__c,
                    Status__c = 'New'
                );
                insert appointmentRequest;
            }

            // Create appointment record as junction between Appointment Request and Time Slot
            Appointment__c appointment = new Appointment__c(
                Appointment_Request__c = appointmentRequest.Id,
                Time_Slot__c = timeSlotId,
                Appointment_Date__c = slot.Day__c,
                Status__c = 'Confirmed'
            );
            insert appointment;

            // Update Appointment Request status to Reserved (time slot has been booked)
            appointmentRequest.Status__c = 'Reserved';
            update appointmentRequest;

            // Update time slot availability
            slot.Number_Available__c = slot.Number_Available__c - 1;
            if (slot.Number_Available__c <= 0) {
                slot.Status__c = 'Booked';
            }
            update slot;

            // Send email notifications
            sendBookingEmails(slot, customer, appointment, appointmentRequest);

            return new BookingResult(true, 'Time slot booked successfully!', appointment.Id);
        } catch (Exception e) {
            throw new AuraHandledException('Error booking time slot: ' + e.getMessage());
        }
    }

    // Send email notifications to agent and customer
    private static void sendBookingEmails(Time_Slot__c slot, User customer, Appointment__c appointment, Appointment_Request__c appointmentRequest) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Email to Agent
        if (slot.Agent__r.Email != null) {
            Messaging.SingleEmailMessage agentEmail = new Messaging.SingleEmailMessage();
            agentEmail.setToAddresses(new List<String>{ slot.Agent__r.Email });
            agentEmail.setSubject('New Appointment Scheduled - ' + slot.Day__c.format());
            agentEmail.setPlainTextBody(
                'Hello ' + slot.Agent__r.Name + ',\n\n' +
                'A new appointment has been scheduled:\n\n' +
                'Customer: ' + customer.Name + '\n' +
                'Date: ' + slot.Day__c.format() + '\n' +
                'Time: ' + formatTime(slot.Start_Time__c) + ' - ' + formatTime(slot.End_Time__c) + '\n' +
                'Appointment Request: ' + appointmentRequest.Name + '\n' +
                'Appointment ID: ' + appointment.Name + '\n\n' +
                'Please confirm your availability.\n\n' +
                'Thank you!'
            );
            emails.add(agentEmail);
        }

        // Email to Customer
        if (customer.Email != null) {
            Messaging.SingleEmailMessage customerEmail = new Messaging.SingleEmailMessage();
            customerEmail.setToAddresses(new List<String>{ customer.Email });
            customerEmail.setSubject('Appointment Confirmed - ' + slot.Day__c.format());
            customerEmail.setPlainTextBody(
                'Hello ' + customer.Name + ',\n\n' +
                'Your appointment has been confirmed:\n\n' +
                'Agent: ' + slot.Agent__r.Name + '\n' +
                'Date: ' + slot.Day__c.format() + '\n' +
                'Time: ' + formatTime(slot.Start_Time__c) + ' - ' + formatTime(slot.End_Time__c) + '\n' +
                'Appointment Request: ' + appointmentRequest.Name + '\n' +
                'Appointment ID: ' + appointment.Name + '\n\n' +
                'We look forward to meeting with you!\n\n' +
                'Thank you!'
            );
            emails.add(customerEmail);
        }

        // Send emails if any were created
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                // Log error but don't fail the booking
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }

    // Helper method to format Time to readable string
    private static String formatTime(Time t) {
        if (t == null) return '';
        Integer hours = t.hour();
        Integer minutes = t.minute();
        String ampm = hours >= 12 ? 'PM' : 'AM';
        if (hours > 12) hours = hours - 12;
        if (hours == 0) hours = 12;
        String minutesStr = String.valueOf(minutes);
        if (minutesStr.length() == 1) {
            minutesStr = '0' + minutesStr;
        }
        return String.valueOf(hours) + ':' + minutesStr + ' ' + ampm;
    }

    // Wrapper class for booking result
    public class BookingResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id appointmentId;

        public BookingResult(Boolean success, String message, Id appointmentId) {
            this.success = success;
            this.message = message;
            this.appointmentId = appointmentId;
        }
    }
}