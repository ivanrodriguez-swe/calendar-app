public inherited sharing class AppointmentRequestSelector {
    
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
