/**
 * @description Service class for handling appointment request status updates
 */
public without sharing class AppointmentRequestStatusService {
    
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
     * @description Updates appointment requests status to Sent for valid records
     * @param requestIds List of Appointment Request record Ids to process
     * @return Map containing success status, recordsUpdated count, and any errors
     */
    public static Map<String, Object> updateStatusToSent(List<Id> requestIds) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        result.put('recordsUpdated', 0);
        result.put('errors', new List<String>());
        
        if (requestIds == null || requestIds.isEmpty()) {
            result.put('errors', new List<String>{ 'No records selected' });
            return result;
        }
        
        List<Appointment_Request__c> requests = AppointmentRequestSelector.getNewAppointmentRequestsByIds(requestIds);
        Integer skippedCount = requestIds.size() - requests.size();
        
        if (requests.isEmpty()) {
            String errorMsg = skippedCount > 0 
                ? 'All ' + skippedCount + ' selected record(s) have already been sent or processed. Only records with "New" status can receive invites.'
                : 'No appointment requests found';
            result.put('errors', new List<String>{ errorMsg });
            return result;
        }
        
        List<String> errors = new List<String>();
        List<Appointment_Request__c> requestsToUpdate = new List<Appointment_Request__c>();
        
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
            
            requestsToUpdate.add(new Appointment_Request__c(
                Id = request.Id,
                Status__c = 'Sent'
            ));
        }
        
        if (requestsToUpdate.isEmpty()) {
            result.put('errors', errors);
            return result;
        }
        
        try {
            update requestsToUpdate;
        } catch (Exception e) {
            errors.add('Error updating records: ' + e.getMessage());
            result.put('errors', errors);
            return result;
        }
        
        if (skippedCount > 0) {
            errors.add(skippedCount + ' record(s) already sent or processed');
        }
        
        result.put('success', true);
        result.put('recordsUpdated', requestsToUpdate.size());
        result.put('errors', errors);
        
        return result;
    }
}

