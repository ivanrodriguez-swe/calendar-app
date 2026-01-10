public class BookingEmailService {
    
    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) return false;
        return email.contains('@') && email.contains('.');
    }
    
    public static void sendBookingEmails(Time_Slot__c slot, String customerName, String customerEmail, Appointment__c appointment, Appointment_Request__c appointmentRequest) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String timeRange = TimeSlotFormatter.formatTime(slot.Start_Time__c) + ' - ' + TimeSlotFormatter.formatTime(slot.End_Time__c);

        if (slot.Volunteer__r != null && slot.Volunteer__r.Email != null) {
            EmailTemplates.EmailContent content = EmailTemplates.getVolunteerNotificationEmail(
                slot.Volunteer__r.Name,
                customerName,
                customerEmail,
                slot.Day__c,
                timeRange
            );
            
            Messaging.SingleEmailMessage volunteerEmail = new Messaging.SingleEmailMessage();
            volunteerEmail.setToAddresses(new List<String>{ slot.Volunteer__r.Email });
            volunteerEmail.setSubject(content.subject);
            volunteerEmail.setHtmlBody(content.htmlBody);
            volunteerEmail.setPlainTextBody(content.plainTextBody);
            emails.add(volunteerEmail);
        }

        if (String.isNotBlank(customerEmail)) {
            String volunteerName = slot.Volunteer__r != null ? slot.Volunteer__r.Name : null;
            EmailTemplates.EmailContent content = EmailTemplates.getCustomerConfirmationEmail(
                customerName,
                volunteerName,
                slot.Day__c,
                timeRange
            );
            
            Messaging.SingleEmailMessage customerEmailMsg = new Messaging.SingleEmailMessage();
            customerEmailMsg.setToAddresses(new List<String>{ customerEmail });
            customerEmailMsg.setSubject(content.subject);
            customerEmailMsg.setHtmlBody(content.htmlBody);
            customerEmailMsg.setPlainTextBody(content.plainTextBody);
            emails.add(customerEmailMsg);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
            }
        }
    }
    
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
        
        String baseUrl = System.Label.OHRS_Site_Base_URL;
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Appointment_Request__c> requestsToUpdate = new List<Appointment_Request__c>();
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
            
            String inviteUrl = baseUrl + request.Id;
            
            EmailTemplates.EmailContent content = EmailTemplates.getAppointmentInviteEmail(
                request.Reference_First_Name__c,
                inviteUrl
            );
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ request.Reference_Email__c });
            email.setSubject(content.subject);
            email.setHtmlBody(content.htmlBody);
            email.setPlainTextBody(content.plainTextBody);
            emails.add(email);
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
        try {
            List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(emails, false);
            
            for (Integer i = 0; i < sendResults.size(); i++) {
                if (sendResults[i].isSuccess()) {
                    emailsSent++;
                    Id requestId = emailIndexToRequestId.get(i);
                    requestsToUpdate.add(new Appointment_Request__c(
                        Id = requestId,
                        Status__c = 'Sent'
                    ));
                } else {
                    Id requestId = emailIndexToRequestId.get(i);
                    for (Messaging.SendEmailError err : sendResults[i].getErrors()) {
                        errors.add('Failed to send email for request ' + requestId + ': ' + err.getMessage());
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
