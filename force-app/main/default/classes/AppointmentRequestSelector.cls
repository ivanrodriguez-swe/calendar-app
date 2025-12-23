// Selector class for Appointment_Request__c object
// Uses inherited sharing to inherit sharing context from caller
public inherited sharing class AppointmentRequestSelector {
    
    /**
     * Get appointment request by ID with all necessary fields
     * @param requestId Appointment request record ID
     * @return Appointment request with volunteer and reference information
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

