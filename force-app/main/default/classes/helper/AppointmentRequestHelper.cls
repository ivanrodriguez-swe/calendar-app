public without sharing class AppointmentRequestHelper {
    
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

