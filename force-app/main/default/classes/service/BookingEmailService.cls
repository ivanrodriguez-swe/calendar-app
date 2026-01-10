/**
 * @description Service class for handling booking and invite email operations
 */
public without sharing class BookingEmailService {
    
    /**
     * @description Validates if the provided string is a valid email format
     * @param email The email address to validate
     * @return Boolean indicating if the email is valid
     */
    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) return false;
        return email.contains('@') && email.contains('.');
    }
    
    /**
     * @description Retrieves the first verified Org-Wide Email Address Id
     * @return The OWA Id or null if none exists
     */
    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owas = [
            SELECT Id FROM OrgWideEmailAddress WHERE IsVerified = true LIMIT 1
        ];
        return owas.isEmpty() ? null : owas[0].Id;
    }
    
    /**
     * @description Creates a SingleEmailMessage with the provided parameters
     * @param toAddress The recipient email address
     * @param content The email content (subject, htmlBody, plainTextBody)
     * @param owaId The Org-Wide Email Address Id to use as sender
     * @return Configured SingleEmailMessage
     */
    private static Messaging.SingleEmailMessage createEmail(String toAddress, EmailTemplates.EmailContent content, Id owaId) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toAddress });
        email.setSubject(content.subject);
        email.setHtmlBody(content.htmlBody);
        email.setPlainTextBody(content.plainTextBody);
        if (owaId != null) {
            email.setOrgWideEmailAddressId(owaId);
        }
        return email;
    }
    
    /**
     * @description Sends booking confirmation emails to both volunteer and customer
     * @param slot The booked time slot with volunteer relationship
     * @param customerName The customer's full name
     * @param customerEmail The customer's email address
     */
    public static void sendBookingEmails(Time_Slot__c slot, String customerName, String customerEmail) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String timeRange = TimeSlotFormatter.formatTime(slot.Start_Time__c) + ' - ' + TimeSlotFormatter.formatTime(slot.End_Time__c);
        Id owaId = getOrgWideEmailAddressId();

        if (slot.Volunteer__r != null && String.isNotBlank(slot.Volunteer__r.Email)) {
            EmailTemplates.EmailContent content = EmailTemplates.getVolunteerConfirmationEmail(
                slot.Volunteer__r.Name,
                customerName,
                customerEmail,
                slot.Day__c,
                timeRange
            );
            emails.add(createEmail(slot.Volunteer__r.Email, content, owaId));
        }

        if (String.isNotBlank(customerEmail)) {
            String volunteerName = slot.Volunteer__r != null ? slot.Volunteer__r.Name : null;
            EmailTemplates.EmailContent content = EmailTemplates.getCustomerConfirmationEmail(
                customerName,
                volunteerName,
                slot.Day__c,
                timeRange
            );
            emails.add(createEmail(customerEmail, content, owaId));
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception e) {
            }
        }
    }
    
    /**
     * @description Sends invite emails to appointment requests with New status
     * @param requestIds List of Appointment Request record Ids to send invites to
     * @return Map containing success status, emailsSent count, and any errors
     */
    public static Map<String, Object> sendInviteEmails(List<Id> requestIds) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        result.put('emailsSent', 0);
        result.put('errors', new List<String>());
        
        if (requestIds == null || requestIds.isEmpty()) {
            result.put('errors', new List<String>{ 'No records selected' });
            return result;
        }
        
        List<Appointment_Request__c> requests = [
            SELECT Id, Reference_Email__c, Reference_First_Name__c, URL_Invite__c, Status__c
            FROM Appointment_Request__c
            WHERE Id IN :requestIds AND Status__c = 'New'
        ];
        
        Integer skippedCount = requestIds.size() - requests.size();
        
        if (requests.isEmpty()) {
            String errorMsg = skippedCount > 0 
                ? 'All ' + skippedCount + ' selected record(s) have already been sent or processed. Only records with "New" status can receive invites.'
                : 'No appointment requests found';
            result.put('errors', new List<String>{ errorMsg });
            return result;
        }
        
        Id owaId = getOrgWideEmailAddressId();
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<String> errors = new List<String>();
        Map<Integer, Id> emailIndexToRequestId = new Map<Integer, Id>();
        
        Integer emailIndex = 0;
        for (Appointment_Request__c request : requests) {
            if (!isValidEmail(request.Reference_Email__c)) {
                String referenceName = String.isNotBlank(request.Reference_First_Name__c) 
                    ? request.Reference_First_Name__c 
                    : 'Unknown';
                String invalidEmail = String.isNotBlank(request.Reference_Email__c) 
                    ? '"' + request.Reference_Email__c + '"'
                    : 'missing';
                errors.add(referenceName + ': email is ' + invalidEmail);
                continue;
            }
            
            String inviteUrl = request.URL_Invite__c;
            EmailTemplates.EmailContent content = EmailTemplates.getAppointmentInviteEmail(
                request.Reference_First_Name__c,
                inviteUrl
            );
            
            emails.add(createEmail(request.Reference_Email__c, content, owaId));
            emailIndexToRequestId.put(emailIndex, request.Id);
            emailIndex++;
        }
        
        if (emails.isEmpty()) {
            result.put('errors', errors);
            return result;
        }
        
        if (emails.size() > 100) {
            result.put('errors', new List<String>{ 'Cannot send more than 100 emails at once. Please select fewer records.' });
            return result;
        }
        
        Integer emailsSent = 0;
        List<Appointment_Request__c> requestsToUpdate = new List<Appointment_Request__c>();
        
        try {
            List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(emails, false);
            
            for (Integer i = 0; i < sendResults.size(); i++) {
                if (sendResults[i].isSuccess()) {
                    emailsSent++;
                    requestsToUpdate.add(new Appointment_Request__c(
                        Id = emailIndexToRequestId.get(i),
                        Status__c = 'Sent'
                    ));
                } else {
                    for (Messaging.SendEmailError err : sendResults[i].getErrors()) {
                        errors.add('Failed to send: ' + err.getMessage());
                    }
                }
            }
            
            if (!requestsToUpdate.isEmpty()) {
                update requestsToUpdate;
            }
        } catch (Exception e) {
            errors.add('Error sending emails: ' + e.getMessage());
        }
        
        if (skippedCount > 0) {
            errors.add(skippedCount + ' record(s) already sent or processed');
        }
        
        result.put('success', emailsSent > 0);
        result.put('emailsSent', emailsSent);
        result.put('errors', errors);
        
        return result;
    }
}
