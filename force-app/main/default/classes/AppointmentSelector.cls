public inherited sharing class AppointmentSelector {
    
    /**
     * Get appointment by ID
     * @param appointmentId Appointment record ID
     * @return Appointment record
     */
    public static List<Appointment__c> getAppointmentById(Id appointmentId) {
        return [
            SELECT Id, Appointment_Request__c, Time_Slot__c, Status__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            LIMIT 1
        ];
    }
}

