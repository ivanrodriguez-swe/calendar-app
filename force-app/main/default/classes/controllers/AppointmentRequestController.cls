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
}
