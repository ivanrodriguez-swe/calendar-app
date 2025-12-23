// Service class for sending booking confirmation emails
public class BookingEmailService {
    
    /**
     * Validate email format
     * @param email Email address to validate
     * @return True if email format is valid, false otherwise
     */
    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) return false;
        return email.contains('@') && email.contains('.');
    }
    
    /**
     * Send booking confirmation emails to volunteer and customer
     * @param slot Time slot that was booked
     * @param customerName Customer name
     * @param customerEmail Customer email address
     * @param appointment Appointment record
     * @param appointmentRequest Appointment request record
     */
    public static void sendBookingEmails(Time_Slot__c slot, String customerName, String customerEmail, Appointment__c appointment, Appointment_Request__c appointmentRequest) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Email to Volunteer
        if (slot.Volunteer__r != null && slot.Volunteer__r.Email != null) {
            Messaging.SingleEmailMessage volunteerEmail = new Messaging.SingleEmailMessage();
            volunteerEmail.setToAddresses(new List<String>{ slot.Volunteer__r.Email });
            volunteerEmail.setSubject('New Appointment Scheduled - ' + slot.Day__c.format());
            volunteerEmail.setPlainTextBody(
                'Hello ' + slot.Volunteer__r.Name + ',\n\n' +
                'A new appointment has been scheduled:\n\n' +
                'Customer: ' + (String.isNotBlank(customerName) ? customerName : 'Guest') + '\n' +
                'Customer Email: ' + (String.isNotBlank(customerEmail) ? customerEmail : 'N/A') + '\n' +
                'Date: ' + slot.Day__c.format() + '\n' +
                'Time: ' + TimeSlotFormatter.formatTime(slot.Start_Time__c) + ' - ' + TimeSlotFormatter.formatTime(slot.End_Time__c) + '\n\n' +
                'Thank you!'
            );
            emails.add(volunteerEmail);
        }

        // Email to Customer
        if (String.isNotBlank(customerEmail)) {
            Messaging.SingleEmailMessage customerEmailMsg = new Messaging.SingleEmailMessage();
            customerEmailMsg.setToAddresses(new List<String>{ customerEmail });
            customerEmailMsg.setSubject('Appointment Confirmed - ' + slot.Day__c.format());
            customerEmailMsg.setPlainTextBody(
                'Hello ' + (String.isNotBlank(customerName) ? customerName : 'Guest') + ',\n\n' +
                'Your appointment has been confirmed:\n\n' +
                'Volunteer: ' + (slot.Volunteer__r != null ? slot.Volunteer__r.Name : 'N/A') + '\n' +
                'Date: ' + slot.Day__c.format() + '\n' +
                'Time: ' + TimeSlotFormatter.formatTime(slot.Start_Time__c) + ' - ' + TimeSlotFormatter.formatTime(slot.End_Time__c) + '\n\n' +
                'We look forward to meeting with you!\n\n' +
                'Thank you!'
            );
            emails.add(customerEmailMsg);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }
}

