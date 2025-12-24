/**
 * Controller for appointment request management
 * 
 * IMPORTANT: Controllers should NEVER call other controllers - only services.
 * Services can call other services, but controllers must remain independent.
 * 
 * Responsibilities:
 * - Expose @AuraEnabled methods for the LWC
 * - Handle exception handling and validation
 * - Convert service data (Maps) to wrapper classes for LWC consumption
 * - NO business logic - all logic is in the service layer
 */
public with sharing class AppointmentRequestController {
    
    /**
     * Upload CSV and create appointment requests
     * Delegates all business logic to AppointmentRequestService
     * 
     * @param csvContent CSV string content
     * @return UploadResult with success status, message, records created, and emails sent
     */
    @AuraEnabled
    public static UploadResult uploadCSV(String csvContent) {
        // Service handles all business logic
        Map<String, Object> serviceResult = AppointmentRequestService.uploadCSV(csvContent);
        
        // Controller converts to wrapper class (simple data transformation)
        UploadResult result = new UploadResult();
        result.success = (Boolean) serviceResult.get('success');
        result.message = (String) serviceResult.get('message');
        result.recordsCreated = (Integer) serviceResult.get('recordsCreated');
        result.emailsSent = (Integer) serviceResult.get('emailsSent');
        
        return result;
    }
    
    // Wrapper Classes for LWC communication (DTOs with @AuraEnabled)
    
    /**
     * Result class for upload operation
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
