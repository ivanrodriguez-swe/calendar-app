/**
 * @description Helper class for parsing appointment request files and sending emails
 */
public without sharing class AppointmentRequestHelper {
    
    /**
     * @description Parses file content to extract selectee and reference data
     * @param fileContent The file content as a string
     * @return List of parsed data maps with selectee and references info
     */
    public static List<Map<String, Object>> parseFile(String fileContent) {
        List<Map<String, Object>> dataList = new List<Map<String, Object>>();
        
        if (String.isBlank(fileContent)) {
            return dataList;
        }
        
        String normalizedContent = fileContent.replace('\r\n', '\n').replace('\r', '\n');
        List<String> lines = normalizedContent.split('\n');
        
        Integer startIndex = 0;
        if (lines.size() > 0) {
            String firstLine = lines[0].trim().toLowerCase();
            Boolean looksLikeHeader = firstLine.contains('selectee') || 
                                      firstLine.contains('first name') || 
                                      firstLine.contains('last name') ||
                                      firstLine.contains('reference') ||
                                      firstLine.contains('discipline') ||
                                      firstLine.contains('eod');
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
            
            if (values.size() >= 5) {
                Map<String, Object> selecteeData = new Map<String, Object>();
                
                selecteeData.put('selecteeLastName', values[0].trim());
                selecteeData.put('selecteeFirstName', values[1].trim());
                selecteeData.put('selecteeEmail', values[2].trim());
                selecteeData.put('expectedEOD', values[3].trim());
                selecteeData.put('discipline', values[4].trim());
                
                List<Map<String, String>> references = new List<Map<String, String>>();
                
                if (values.size() >= 7 && String.isNotBlank(values[5].trim()) && String.isNotBlank(values[6].trim())) {
                    Map<String, String> ref1 = new Map<String, String>();
                    ref1.put('name', values[5].trim());
                    ref1.put('email', values[6].trim());
                    ref1.put('relationship', values.size() >= 8 ? values[7].trim() : '');
                    references.add(ref1);
                }
                
                if (values.size() >= 10 && String.isNotBlank(values[8].trim()) && String.isNotBlank(values[9].trim())) {
                    Map<String, String> ref2 = new Map<String, String>();
                    ref2.put('name', values[8].trim());
                    ref2.put('email', values[9].trim());
                    ref2.put('relationship', values.size() >= 11 ? values[10].trim() : '');
                    references.add(ref2);
                }
                
                if (values.size() >= 13 && String.isNotBlank(values[11].trim()) && String.isNotBlank(values[12].trim())) {
                    Map<String, String> ref3 = new Map<String, String>();
                    ref3.put('name', values[11].trim());
                    ref3.put('email', values[12].trim());
                    ref3.put('relationship', values.size() >= 14 ? values[13].trim() : '');
                    references.add(ref3);
                }
                
                selecteeData.put('references', references);
                
                if (String.isNotBlank((String)selecteeData.get('selecteeLastName')) && 
                    String.isNotBlank((String)selecteeData.get('selecteeFirstName'))) {
                    dataList.add(selecteeData);
                }
            }
        }
        
        return dataList;
    }
    
    /**
     * @description Parses CSV content to extract appointment request data
     * @param csvContent The CSV file content as a string
     * @return List of parsed data maps
     */
    public static List<Map<String, String>> parseCSV(String csvContent) {
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
    
    private static List<String> parseCSVLine(String line) {
        List<String> values = new List<String>();
        Boolean inQuotes = false;
        String currentValue = '';
        
        for (Integer i = 0; i < line.length(); i++) {
            String currentChar = line.substring(i, i + 1);
            
            if (currentChar == '"') {
                inQuotes = !inQuotes;
            } else if (currentChar == ',' && !inQuotes) {
                values.add(currentValue.trim());
                currentValue = '';
            } else {
                currentValue += currentChar;
            }
        }
        
        values.add(currentValue.trim());
        
        return values;
    }
    
    /**
     * @description Maps volunteer emails to User Ids
     * @param dataList List of data maps containing volunteerEmail
     * @return Map of email to User Id
     */
    public static Map<String, Id> getVolunteerEmailToIdMap(List<Map<String, String>> dataList) {
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
     * @description Sends referral emails to appointment request references
     * @param appointmentRequests List of appointment requests to send emails for
     * @return Number of emails sent successfully
     */
    public static Integer sendReferralEmails(List<Appointment_Request__c> appointmentRequests) {
        Integer emailsSent = 0;
        
        try {
            String publicSiteUrl = getPublicSiteUrl();
            
            if (String.isBlank(publicSiteUrl)) {
                return 0;
            }
            
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
                }
            }
        } catch (Exception e) {
        }
        
        return emailsSent;
    }
    
    /**
     * @description Gets the public site URL for calendar access
     * @return The public site URL string
     */
    public static String getPublicSiteUrl() {
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
