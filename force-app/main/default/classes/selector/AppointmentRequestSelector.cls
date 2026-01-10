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
}
