/**
 * Service for appointment request business logic
 */
public without sharing class AppointmentRequestService {
    
    /**
     * Process CSV upload and create appointment requests
     * @param csvContent CSV string content
     * @return Map with success, message, recordsCreated, emailsSent, and skippedRecords
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
            
            List<Map<String, String>> requestDataList = parseCSV(csvContent);
            
            if (requestDataList.isEmpty()) {
                result.put('message', 'No valid records found in CSV');
                return result;
            }
            
            Map<String, Id> volunteerEmailToIdMap = getVolunteerEmailToIdMap(requestDataList);
            
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
                
                // Set reference fields
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
            Integer emailsSent = sendReferralEmails(appointmentRequests);
            
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
    
    /**
     * Parse CSV content into list of maps
     * @param csvContent CSV string content
     * @return List of maps with parsed data
     */
    private static List<Map<String, String>> parseCSV(String csvContent) {
        List<Map<String, String>> dataList = new List<Map<String, String>>();
        
        if (String.isBlank(csvContent)) {
            return dataList;
        }
        
        String normalizedContent = csvContent.replace('\r\n', '\n').replace('\r', '\n');
        List<String> lines = normalizedContent.split('\n');
        
        Integer startIndex = 0;
        if (lines.size() > 0) {
            String firstLine = lines[0].trim().toLowerCase();
            Boolean looksLikeHeader = (firstLine.contains('volunteer email') || 
                                      firstLine.contains('first name') || 
                                      firstLine.contains('last name') ||
                                      firstLine.contains('reference email')) ||
                                     (firstLine.startsWith('volunteer') && !firstLine.contains('@')) ||
                                     (firstLine.startsWith('email') && !firstLine.contains('@')) ||
                                     (firstLine.startsWith('first') && !firstLine.contains(',')) ||
                                     (firstLine.startsWith('last') && !firstLine.contains(','));
            if (looksLikeHeader) {
                startIndex = 1;
            }
        }
        
        for (Integer i = startIndex; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) {
                continue;
            }
            
            List<String> values = parseCSVLine(line);
            
            if (values.size() >= 4) {
                Map<String, String> data = new Map<String, String>();
                data.put('volunteerEmail', values[0].trim());
                data.put('referenceFirstName', values[1].trim());
                data.put('referenceLastName', values[2].trim());
                data.put('referenceEmail', values[3].trim());
                
                if (String.isNotBlank(data.get('volunteerEmail')) && 
                    String.isNotBlank(data.get('referenceFirstName')) && 
                    String.isNotBlank(data.get('referenceLastName')) && 
                    String.isNotBlank(data.get('referenceEmail'))) {
                    dataList.add(data);
                }
            }
        }
        
        return dataList;
    }
    
    /**
     * Parse a single CSV line handling quoted values
     * @param line CSV line to parse
     * @return List of parsed values (trimmed)
     */
    private static List<String> parseCSVLine(String line) {
        List<String> values = new List<String>();
        Boolean inQuotes = false;
        String currentValue = '';
        
        for (Integer i = 0; i < line.length(); i++) {
            String currentChar = line.substring(i, i + 1);
            
            if (currentChar == '"') {
                inQuotes = !inQuotes;
                // Don't add quote to currentValue
            } else if (currentChar == ',' && !inQuotes) {
                // Trim value before adding
                values.add(currentValue.trim());
                currentValue = '';
            } else {
                currentValue += currentChar;
            }
        }
        
        // Add last value (trimmed)
        values.add(currentValue.trim());
        
        return values;
    }
    
    /**
     * Get volunteer email to ID mapping using selector
     * @param dataList List of parsed CSV data
     * @return Map of email (lowercase) to User ID
     */
    private static Map<String, Id> getVolunteerEmailToIdMap(List<Map<String, String>> dataList) {
        Set<String> volunteerEmails = new Set<String>();
        
        for (Map<String, String> data : dataList) {
            String volunteerEmail = data.get('volunteerEmail');
            if (String.isNotBlank(volunteerEmail)) {
                if (volunteerEmail.contains('@') || 
                    (volunteerEmail.startsWith('005') && (volunteerEmail.length() == 15 || volunteerEmail.length() == 18))) {
                    volunteerEmails.add(volunteerEmail.toLowerCase());
                }
            }
        }
        
        Map<String, Id> emailToIdMap = new Map<String, Id>();
        
        if (!volunteerEmails.isEmpty()) {
            List<User> volunteers = OHRUserSelector.getUsersByEmails(volunteerEmails);
            
            for (User volunteer : volunteers) {
                emailToIdMap.put(volunteer.Email.toLowerCase(), volunteer.Id);
            }
        }
        
        return emailToIdMap;
    }
    
    /**
     * Send referral emails to references
     * @param appointmentRequests List of appointment requests
     * @return Number of emails sent
     */
    private static Integer sendReferralEmails(List<Appointment_Request__c> appointmentRequests) {
        Integer emailsSent = 0;
        
        try {
            String publicSiteUrl = getPublicSiteUrl();
            
            if (String.isBlank(publicSiteUrl)) {
                return 0;
            }
            
            // Send individual email to each appointment request's referral email
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Appointment_Request__c request : appointmentRequests) {
                if (String.isBlank(request.Reference_Email__c) || 
                    !BookingEmailService.isValidEmail(request.Reference_Email__c)) {
                    continue;
                }
                
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ request.Reference_Email__c });
                email.setSubject('Appointment Request Calendar - Request Created');
                
                String firstName = request.Reference_First_Name__c;
                String greeting = String.isNotBlank(firstName) ? 'Dear ' + firstName + ',' : 'Dear Referral,';
                
                String calendarUrl = publicSiteUrl;
                if (!calendarUrl.contains('?')) {
                    calendarUrl += '?requestId=' + request.Id;
                } else {
                    calendarUrl += '&requestId=' + request.Id;
                }
                
                String emailBody = greeting + '\n\n';
                emailBody += 'We have successfully created an appointment request for you.\n\n';
                emailBody += 'Please use the following link to access the calendar and select your preferred time slot:\n\n';
                emailBody += calendarUrl + '\n\n';
                emailBody += 'Appointment Request Details:\n';
                emailBody += '- Request Number: ' + request.Name + '\n';
                
                if (String.isNotBlank(request.Reference_First_Name__c) || 
                    String.isNotBlank(request.Reference_Last_Name__c)) {
                    emailBody += '- Name: ' + request.Reference_First_Name__c + ' ' + 
                                 request.Reference_Last_Name__c + '\n';
                }
                
                emailBody += '\nThank you for using our appointment scheduling system.\n\n';
                emailBody += 'Best regards,\n';
                emailBody += 'Appointment Scheduling Team';
                
                email.setPlainTextBody(emailBody);
                emails.add(email);
            }
            
            if (!emails.isEmpty()) {
                try {
                    Messaging.sendEmail(emails);
                    emailsSent = emails.size();
                } catch (Exception e) {
                    // Email sending failed - log error but don't throw to avoid breaking upload flow
                    // In production, consider logging to a custom object or using Platform Events
                }
            }
        } catch (Exception e) {
            // Public site URL retrieval failed - return 0 emails sent
        }
        
        return emailsSent;
    }
    
    /**
     * Get public site URL for Experience Cloud
     * @return Public site URL string
     */
    private static String getPublicSiteUrl() {
        try {
            Organization org = [SELECT InstanceName FROM Organization LIMIT 1];
            String myDomain = org.InstanceName.toLowerCase();
            String urlPathPrefix = 'ohrscheduler';
            String domain = myDomain.contains('--') ? 'sandbox.lightning.force.com' : 'lightning.force.com';
            return 'https://' + myDomain + '.' + domain + '/' + urlPathPrefix;
        } catch (Exception e) {
            return 'https://login.salesforce.com';
        }
    }
}


