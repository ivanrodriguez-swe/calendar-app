public without sharing class AppointmentRequestService {
    
    public static Map<String, Object> processFile(String fileContent) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        result.put('selecteesCreated', 0);
        result.put('requestsCreated', 0);
        
        try {
            if (String.isBlank(fileContent)) {
                result.put('message', 'File content is empty');
                return result;
            }
            
            List<Map<String, Object>> parsedData = AppointmentRequestHelper.parseFile(fileContent);
            
            if (parsedData.isEmpty()) {
                result.put('message', 'No valid records found in file');
                return result;
            }
            
            List<Map<String, Object>> validData = new List<Map<String, Object>>();
            Set<String> selecteeEmails = new Set<String>();
            
            for (Map<String, Object> data : parsedData) {
                List<Map<String, String>> references = (List<Map<String, String>>)data.get('references');
                
                if (references == null || references.isEmpty()) {
                    continue;
                }
                
                validData.add(data);
                String email = (String)data.get('selecteeEmail');
                if (String.isNotBlank(email)) {
                    selecteeEmails.add(email.toLowerCase());
                }
            }
            
            if (validData.isEmpty()) {
                result.put('message', 'No valid records found. Each row must have at least one reference.');
                return result;
            }
            
            parsedData = validData;
            
            Map<String, Selectee__c> existingSelecteesByEmail = new Map<String, Selectee__c>();
            for (Selectee__c s : [SELECT Id, Email__c FROM Selectee__c WHERE Email__c IN :selecteeEmails]) {
                if (String.isNotBlank(s.Email__c)) {
                    existingSelecteesByEmail.put(s.Email__c.toLowerCase(), s);
                }
            }
            
            List<Selectee__c> newSelectees = new List<Selectee__c>();
            List<Integer> newSelecteeIndices = new List<Integer>();
            Map<Integer, Id> rowToSelecteeId = new Map<Integer, Id>();
            
            for (Integer i = 0; i < parsedData.size(); i++) {
                Map<String, Object> data = parsedData[i];
                String email = (String)data.get('selecteeEmail');
                String emailKey = String.isNotBlank(email) ? email.toLowerCase() : null;
                
                if (emailKey != null && existingSelecteesByEmail.containsKey(emailKey)) {
                    rowToSelecteeId.put(i, existingSelecteesByEmail.get(emailKey).Id);
                } else {
                    Selectee__c selectee = new Selectee__c();
                    selectee.Name = (String)data.get('selecteeFirstName') + ' ' + (String)data.get('selecteeLastName');
                    selectee.Email__c = (String)data.get('selecteeEmail');
                    selectee.Discipline__c = (String)data.get('discipline');
                    
                    String eodString = (String)data.get('expectedEOD');
                    if (String.isNotBlank(eodString)) {
                        try {
                            selectee.Expected_EOD__c = Date.valueOf(eodString);
                        } catch (Exception e) {
                        }
                    }
                    
                    newSelectees.add(selectee);
                    newSelecteeIndices.add(i);
                }
            }
            
            if (!newSelectees.isEmpty()) {
                insert newSelectees;
                
                for (Integer j = 0; j < newSelectees.size(); j++) {
                    Integer rowIndex = newSelecteeIndices[j];
                    rowToSelecteeId.put(rowIndex, newSelectees[j].Id);
                }
            }
            
            List<Appointment_Request__c> appointmentRequests = new List<Appointment_Request__c>();
            
            for (Integer i = 0; i < parsedData.size(); i++) {
                Map<String, Object> data = parsedData[i];
                Id selecteeId = rowToSelecteeId.get(i);
                
                List<Map<String, String>> references = (List<Map<String, String>>)data.get('references');
                
                if (references != null && selecteeId != null) {
                    for (Map<String, String> ref : references) {
                        Appointment_Request__c request = new Appointment_Request__c();
                        request.Selectee__c = selecteeId;
                        request.Status__c = 'New';
                        
                        String refName = ref.get('name');
                        if (String.isNotBlank(refName)) {
                            List<String> nameParts = refName.split(' ', 2);
                            request.Reference_First_Name__c = nameParts[0];
                            if (nameParts.size() > 1) {
                                request.Reference_Last_Name__c = nameParts[1];
                            }
                        }
                        
                        request.Reference_Email__c = ref.get('email');
                        request.Relationship_Reference__c = ref.get('relationship');
                        
                        appointmentRequests.add(request);
                    }
                }
            }
            
            if (!appointmentRequests.isEmpty()) {
                insert appointmentRequests;
            }
            
            Integer existingSelecteesUsed = parsedData.size() - newSelectees.size();
            result.put('success', true);
            result.put('selecteesCreated', newSelectees.size());
            result.put('requestsCreated', appointmentRequests.size());
            
            String message = 'Successfully created ' + newSelectees.size() + ' Selectee(s) and ' + appointmentRequests.size() + ' Appointment Request(s)';
            if (existingSelecteesUsed > 0) {
                message += '. ' + existingSelecteesUsed + ' existing Selectee(s) were reused.';
            }
            result.put('message', message);
            
        } catch (Exception e) {
            result.put('message', 'Error: ' + e.getMessage());
        }
        
        return result;
    }
    
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
