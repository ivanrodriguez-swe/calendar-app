public with sharing class AppointmentRequestController {
    
    /**
     * Process file to create Selectees and Appointment Requests
     * @param fileContent The file content
     * @return ProcessFileResult with selecteesCreated and requestsCreated
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
    
    /**
     * Process file result
     */
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
     * Upload CSV and create appointment requests (legacy method)
     * @param csvContent CSV content
     * @return UploadResult
     */
    @AuraEnabled
    public static UploadResult uploadCSV(String csvContent) {
        Map<String, Object> serviceResult = AppointmentRequestService.uploadCSV(csvContent);
        
        UploadResult result = new UploadResult();
        result.success = (Boolean) serviceResult.get('success');
        result.message = (String) serviceResult.get('message');
        result.recordsCreated = (Integer) serviceResult.get('recordsCreated');
        result.emailsSent = (Integer) serviceResult.get('emailsSent');
        
        return result;
    }
    
    /**
     * Upload result (legacy)
     */
    public class UploadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer recordsCreated;
        @AuraEnabled public Integer emailsSent;
        
        public UploadResult() {
            this.success = false;
            this.recordsCreated = 0;
            this.emailsSent = 0;
        }
    }
    
    /**
     * Send invite emails to selected Appointment Requests
     * @param requestIds List of Appointment Request IDs
     * @return SendInvitesResult with emailsSent and errors
     */
    @AuraEnabled
    public static SendInvitesResult sendInviteEmails(List<Id> requestIds) {
        Map<String, Object> serviceResult = BookingEmailService.sendInviteEmails(requestIds);
        
        SendInvitesResult result = new SendInvitesResult();
        result.success = (Boolean) serviceResult.get('success');
        result.emailsSent = (Integer) serviceResult.get('emailsSent');
        result.errors = (List<String>) serviceResult.get('errors');
        
        return result;
    }
    
    /**
     * Send invites result
     */
    public class SendInvitesResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer emailsSent;
        @AuraEnabled public List<String> errors;
        
        public SendInvitesResult() {
            this.success = false;
            this.emailsSent = 0;
            this.errors = new List<String>();
        }
    }
    
    /**
     * Get Appointment Requests with New status for the Send Invites datatable
     * @return List of Appointment Requests with New status
     */
    @AuraEnabled(cacheable=true)
    public static List<Appointment_Request__c> getNewAppointmentRequests() {
        return [
            SELECT Id, Reference_First_Name__c, Reference_Email__c, 
                   Selectee__r.Name, Status__c, CreatedDate
            FROM Appointment_Request__c
            WHERE Status__c = 'New'
            ORDER BY CreatedDate DESC
        ];
    }
}
