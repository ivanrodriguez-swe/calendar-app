/**
 * @description Controller for appointment request operations exposed to LWC
 */
public with sharing class AppointmentRequestController {
    
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
     * @description Uploads CSV content to create appointment requests
     * @param csvContent The CSV file content as a string
     * @return UploadResult with counts of created records and emails sent
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
     * @description Sends invite emails to selected appointment requests
     * @param requestIds List of Appointment Request record Ids
     * @return SendInvitesResult with success status and email counts
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
     * @description Retrieves all appointment requests with New status
     * @return List of Appointment_Request__c records
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
