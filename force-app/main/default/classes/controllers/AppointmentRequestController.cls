public with sharing class AppointmentRequestController {
    
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
