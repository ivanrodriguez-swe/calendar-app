public without sharing class AppointmentRequestService {
    
    /**
     * Process CSV and create appointment requests
     * @param csvContent CSV content
     * @return Map with success, message, recordsCreated, emailsSent, skippedRecords
     */
    public static Map<String, Object> uploadCSV(String csvContent) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        result.put('recordsCreated', 0);
        result.put('emailsSent', 0);
        result.put('skippedRecords', new List<String>());
        
        try {
            if (String.isBlank(csvContent)) {
                result.put('message', 'CSV content is empty');
                return result;
            }
            
            List<Map<String, String>> requestDataList = AppointmentRequestHelper.parseCSV(csvContent);
            
            if (requestDataList.isEmpty()) {
                result.put('message', 'No valid records found in CSV');
                return result;
            }
            
            Map<String, Id> volunteerEmailToIdMap = AppointmentRequestHelper.getVolunteerEmailToIdMap(requestDataList);
            
            List<Appointment_Request__c> appointmentRequests = new List<Appointment_Request__c>();
            List<String> skippedRecords = new List<String>();
            
            for (Map<String, String> data : requestDataList) {
                Appointment_Request__c request = new Appointment_Request__c();
                
                String volunteerEmail = data.get('volunteerEmail');
                String volunteerId = data.get('volunteerId');
                
                if (String.isNotBlank(volunteerEmail)) {
                    Id volunteerIdFromEmail = volunteerEmailToIdMap.get(volunteerEmail.toLowerCase());
                    if (volunteerIdFromEmail != null) {
                        request.Volunteer__c = volunteerIdFromEmail;
                    } else {
                        if (volunteerEmail.startsWith('005') && (volunteerEmail.length() == 15 || volunteerEmail.length() == 18)) {
                            try {
                                request.Volunteer__c = Id.valueOf(volunteerEmail);
                            } catch (Exception e) {
                                skippedRecords.add('Volunteer email/ID not found: ' + volunteerEmail);
                                continue;
                            }
                        } else {
                            skippedRecords.add('Volunteer email not found: ' + volunteerEmail);
                            continue;
                        }
                    }
                } else if (String.isNotBlank(volunteerId)) {
                    try {
                        request.Volunteer__c = Id.valueOf(volunteerId);
                    } catch (Exception e) {
                        skippedRecords.add('Invalid volunteer ID: ' + volunteerId);
                        continue;
                    }
                } else {
                    skippedRecords.add('Missing volunteer email/ID');
                    continue;
                }
                
                request.Reference_First_Name__c = data.get('referenceFirstName');
                request.Reference_Last_Name__c = data.get('referenceLastName');
                request.Reference_Email__c = data.get('referenceEmail');
                request.Status__c = 'New';
                
                appointmentRequests.add(request);
            }
            
            if (appointmentRequests.isEmpty()) {
                String errorMsg = 'No valid appointment requests to create. ';
                if (!skippedRecords.isEmpty()) {
                    errorMsg += 'Issues: ' + String.join(skippedRecords, '; ');
                }
                result.put('message', errorMsg);
                result.put('skippedRecords', skippedRecords);
                return result;
            }
            
            insert appointmentRequests;
            Integer emailsSent = AppointmentRequestHelper.sendReferralEmails(appointmentRequests);
            
            result.put('success', true);
            result.put('recordsCreated', appointmentRequests.size());
            result.put('emailsSent', emailsSent);
            result.put('skippedRecords', skippedRecords);
            
            String successMsg = 'Successfully created ' + appointmentRequests.size() + ' appointment request(s)';
            if (!skippedRecords.isEmpty()) {
                successMsg += '. ' + skippedRecords.size() + ' record(s) skipped: ' + String.join(skippedRecords, '; ');
            }
            result.put('message', successMsg);
            
                    } catch (Exception e) {
                        result.put('message', 'Error: ' + e.getMessage());
                    }
        
        return result;
    }
    
}


