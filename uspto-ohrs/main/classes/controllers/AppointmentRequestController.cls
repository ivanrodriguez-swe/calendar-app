/**
 * @description Controller for appointment request operations exposed to LWC
 */
public without sharing class AppointmentRequestController {
    
    /**
     * @description Processes uploaded file content to create selectees and appointment requests
     * @param fileContent The file content as a string
     * @return ProcessFileResult with counts of created records
     */
    @AuraEnabled
    public static ProcessFileResult processFile(String fileContent) {
        Map<String, Object> serviceResult = AppointmentRequestService.processFile(fileContent);
        
        ProcessFileResult result = new ProcessFileResult();
        result.success = (Boolean) serviceResult.get('success');
        result.message = (String) serviceResult.get('message');
        result.selecteesCreated = (Integer) serviceResult.get('selecteesCreated');
        result.requestsCreated = (Integer) serviceResult.get('requestsCreated');
        
        return result;
    }
    
    public class ProcessFileResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer selecteesCreated;
        @AuraEnabled public Integer requestsCreated;
        
        public ProcessFileResult() {
            this.success = false;
            this.selecteesCreated = 0;
            this.requestsCreated = 0;
        }
    }
    
    /**
     * @description Updates appointment requests status to Sent for sending invites via Flow
     * @param requestIds List of Appointment Request record Ids
     * @return SendInvitesResult with success status and records updated count
     */
    @AuraEnabled
    public static SendInvitesResult sendInviteEmails(List<Id> requestIds) {
        Map<String, Object> serviceResult = AppointmentRequestStatusService.updateStatusToSent(requestIds);
        
        SendInvitesResult result = new SendInvitesResult();
        result.success = (Boolean) serviceResult.get('success');
        result.recordsUpdated = (Integer) serviceResult.get('recordsUpdated');
        result.errors = (List<String>) serviceResult.get('errors');
        
        return result;
    }
    
    public class SendInvitesResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer recordsUpdated;
        @AuraEnabled public List<String> errors;
        
        public SendInvitesResult() {
            this.success = false;
            this.recordsUpdated = 0;
            this.errors = new List<String>();
        }
    }
    
    /**
     * @description Retrieves all appointment requests with New status
     * @return List of Appointment_Request__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Appointment_Request__c> getNewAppointmentRequests() {
        return AppointmentRequestSelector.getAllNewAppointmentRequests();
    }
}
