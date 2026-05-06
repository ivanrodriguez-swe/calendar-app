/**
 * @description Service class for processing appointment requests from file uploads
 */
public inherited sharing class AppointmentRequestService {
    
    /**
     * @description Processes file content to create selectees and appointment requests
     * @param fileContent The file content as a string
     * @return Map with success status, counts, and message
     */
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
            
            Map<String, Selectee__c> existingSelecteesByEmail = SelecteeSelector.getSelecteesByEmails(selecteeEmails);
            
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
                            // Invalid date format - leave field null and continue processing
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
                        //Generate token
                        request.URL_Token__c = UUIDCodeGenerator.generateCode(32);
                        
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
}
