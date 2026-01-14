/**
 * @description Selector class for Appointment_Request__c queries
 */
public inherited sharing class AppointmentRequestSelector {
    
    /**
     * @description Retrieves an appointment request by Id with related fields
     * @param requestId The Appointment Request record Id
     * @return List containing the appointment request or empty if not found
     */
    public static List<Appointment_Request__c> getAppointmentRequestById(Id requestId) {
        return [
            SELECT Id, Name, Volunteer__c, Status__c, Reference_First_Name__c, 
                   Reference_Last_Name__c, Reference_Email__c
            FROM Appointment_Request__c 
            WHERE Id = :requestId 
            LIMIT 1
        ];
    }
    
    /**
     * @description Retrieves appointment requests by Ids with New status
     * @param requestIds List of Appointment Request record Ids
     * @return List of appointment requests with New status
     */
    public static List<Appointment_Request__c> getNewAppointmentRequestsByIds(List<Id> requestIds) {
        return [
            SELECT Id, Reference_Email__c, Reference_First_Name__c, Status__c
            FROM Appointment_Request__c
            WHERE Id IN :requestIds AND Status__c = 'New'
        ];
    }
    
    /**
     * @description Retrieves all appointment requests with New status
     * @return List of appointment requests ordered by created date
     */
    public static List<Appointment_Request__c> getAllNewAppointmentRequests() {
        return [
            SELECT Id, Reference_First_Name__c, Reference_Email__c, 
                   Selectee__r.Name, Status__c, CreatedDate
            FROM Appointment_Request__c
            WHERE Status__c = 'New'
            ORDER BY CreatedDate DESC
        ];
    }
    
    /**
     * @description Retrieves appointment request info for scheduler component
     * @param requestId The Appointment Request record Id
     * @return List containing the appointment request or empty if not found
     */
    public static List<Appointment_Request__c> getAppointmentRequestInfoById(Id requestId) {
        return [
            SELECT Id, Reference_First_Name__c, Status__c 
            FROM Appointment_Request__c 
            WHERE Id = :requestId
            LIMIT 1
        ];
    }
}
