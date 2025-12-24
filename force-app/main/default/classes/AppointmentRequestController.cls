public with sharing class AppointmentRequestController {
    
    /**
     * Upload CSV and create appointment requests
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
     * Upload result
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
