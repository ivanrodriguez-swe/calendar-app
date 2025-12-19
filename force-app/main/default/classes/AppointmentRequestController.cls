public with sharing class AppointmentRequestController {
    
    @AuraEnabled
    public static UploadResult uploadCSV(String csvContent) {
        UploadResult result = new UploadResult();
        
        try {
            if (String.isBlank(csvContent)) {
                result.success = false;
                result.message = 'CSV content is empty';
                return result;
            }
            
            // Parse CSV
            List<AppointmentRequestData> requestDataList = parseCSV(csvContent);
            
            if (requestDataList.isEmpty()) {
                result.success = false;
                result.message = 'No valid records found in CSV';
                return result;
            }
            
            // Create Appointment Request records
            List<Appointment_Request__c> appointmentRequests = new List<Appointment_Request__c>();
            Map<String, Id> agentEmailToIdMap = getAgentEmailToIdMap(requestDataList);
            List<String> skippedRecords = new List<String>(); // Track records that couldn't be processed
            
            for (AppointmentRequestData data : requestDataList) {
                Appointment_Request__c request = new Appointment_Request__c();
                
                // Set Agent - match by email first
                if (String.isNotBlank(data.agentEmail)) {
                    Id agentId = agentEmailToIdMap.get(data.agentEmail.toLowerCase());
                    if (agentId != null) {
                        request.Agent__c = agentId;
                    } else {
                        // Agent email not found in User records
                        // Try to parse as User ID if it looks like an ID (starts with 005 or similar)
                        if (data.agentEmail.startsWith('005') && data.agentEmail.length() == 15 || data.agentEmail.length() == 18) {
                            try {
                                request.Agent__c = Id.valueOf(data.agentEmail);
                            } catch (Exception e) {
                                // Invalid ID format, skip this record
                                skippedRecords.add('Agent email/ID not found: ' + data.agentEmail);
                                continue;
                            }
                        } else {
                            // Email doesn't match any active user
                            skippedRecords.add('Agent email not found: ' + data.agentEmail);
                            continue;
                        }
                    }
                } else if (String.isNotBlank(data.agentId)) {
                    try {
                        request.Agent__c = Id.valueOf(data.agentId);
                    } catch (Exception e) {
                        skippedRecords.add('Invalid agent ID: ' + data.agentId);
                        continue;
                    }
                } else {
                    skippedRecords.add('Missing agent email/ID');
                    continue; // Skip records without agent
                }
                
                // Set reference fields
                request.Reference_First_Name__c = data.referenceFirstName;
                request.Reference_Last_Name__c = data.referenceLastName;
                request.Reference_Email__c = data.referenceEmail;
                request.Status__c = 'New';
                
                appointmentRequests.add(request);
            }
            
            if (appointmentRequests.isEmpty()) {
                result.success = false;
                String errorMsg = 'No valid appointment requests to create. ';
                if (!skippedRecords.isEmpty()) {
                    errorMsg += 'Issues: ' + String.join(skippedRecords, '; ');
                }
                result.message = errorMsg;
                return result;
            }
            
            // Insert records
            insert appointmentRequests;
            result.recordsCreated = appointmentRequests.size();
            
            // Send emails with public site URL to each referral email
            result.emailsSent = sendReferralEmails(appointmentRequests);
            
            result.success = true;
            String successMsg = 'Successfully created ' + result.recordsCreated + ' appointment request(s)';
            if (!skippedRecords.isEmpty()) {
                successMsg += '. ' + skippedRecords.size() + ' record(s) skipped: ' + String.join(skippedRecords, '; ');
            }
            result.message = successMsg;
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
            System.debug('Error in uploadCSV: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    private static List<AppointmentRequestData> parseCSV(String csvContent) {
        List<AppointmentRequestData> dataList = new List<AppointmentRequestData>();
        
        if (String.isBlank(csvContent)) {
            return dataList;
        }
        
        // Split by lines
        List<String> lines = csvContent.split('\n');
        
        // Skip header row if present
        Integer startIndex = 0;
        if (lines.size() > 0) {
            String firstLine = lines[0].trim().toLowerCase();
            // Check if first line looks like a header
            if (firstLine.contains('agent') || firstLine.contains('email') || firstLine.contains('first') || firstLine.contains('last')) {
                startIndex = 1;
            }
        }
        
        for (Integer i = startIndex; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) {
                continue;
            }
            
            // Parse CSV line (handle quoted values)
            List<String> values = parseCSVLine(line);
            
            if (values.size() >= 4) {
                AppointmentRequestData data = new AppointmentRequestData();
                data.agentEmail = values[0].trim();
                data.referenceFirstName = values[1].trim();
                data.referenceLastName = values[2].trim();
                data.referenceEmail = values[3].trim();
                
                // Validate required fields
                if (String.isNotBlank(data.agentEmail) && 
                    String.isNotBlank(data.referenceFirstName) && 
                    String.isNotBlank(data.referenceLastName) && 
                    String.isNotBlank(data.referenceEmail)) {
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
                values.add(currentValue);
                currentValue = '';
            } else {
                currentValue += currentChar;
            }
        }
        
        // Add last value
        values.add(currentValue);
        
        return values;
    }
    
    private static Map<String, Id> getAgentEmailToIdMap(List<AppointmentRequestData> dataList) {
        Set<String> agentEmails = new Set<String>();
        
        for (AppointmentRequestData data : dataList) {
            if (String.isNotBlank(data.agentEmail) && isValidEmail(data.agentEmail)) {
                agentEmails.add(data.agentEmail.toLowerCase());
            }
        }
        
        Map<String, Id> emailToIdMap = new Map<String, Id>();
        
        if (!agentEmails.isEmpty()) {
            List<User> agents = [
                SELECT Id, Email 
                FROM User 
                WHERE Email IN :agentEmails 
                AND IsActive = true
            ];
            
            for (User agent : agents) {
                emailToIdMap.put(agent.Email.toLowerCase(), agent.Id);
            }
        }
        
        return emailToIdMap;
    }
    
    private static Integer sendReferralEmails(List<Appointment_Request__c> appointmentRequests) {
        Integer emailsSent = 0;
        
        try {
            // Get public site URL
            String publicSiteUrl = getPublicSiteUrl();
            
            if (String.isBlank(publicSiteUrl)) {
                System.debug('Public site URL not configured');
                return 0;
            }
            
            // Send individual email to each appointment request's referral email
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Appointment_Request__c request : appointmentRequests) {
                if (String.isBlank(request.Reference_Email__c) || !isValidEmail(request.Reference_Email__c)) {
                    continue; // Skip if no valid referral email
                }
                
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ request.Reference_Email__c });
                email.setSubject('Appointment Request Calendar - Request Created');
                
                String firstName = request.Reference_First_Name__c;
                String greeting = String.isNotBlank(firstName) ? 'Dear ' + firstName + ',' : 'Dear Referral,';
                
                // Build URL with appointment request ID as identifier
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
                
                if (String.isNotBlank(request.Reference_First_Name__c) || String.isNotBlank(request.Reference_Last_Name__c)) {
                    emailBody += '- Name: ' + request.Reference_First_Name__c + ' ' + request.Reference_Last_Name__c + '\n';
                }
                
                emailBody += '\nThank you for using our appointment scheduling system.\n\n';
                emailBody += 'Best regards,\n';
                emailBody += 'Appointment Scheduling Team';
                
                email.setPlainTextBody(emailBody);
                emails.add(email);
            }
            
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
                emailsSent = emails.size();
            }
            
        } catch (Exception e) {
            System.debug('Error sending referral emails: ' + e.getMessage());
            // Don't fail the entire operation if email fails
        }
        
        return emailsSent;
    }
    
    private static String getPublicSiteUrl() {
        // Try to get the public site URL from custom metadata or custom setting
        // For now, return a placeholder that you'll need to configure
        // You can also query Site or use URL.getSalesforceBaseUrl()
        
        // Option 1: Use Site domain
        try {
            List<Site> sites = [SELECT Id, UrlPathPrefix FROM Site WHERE Status = 'Active' LIMIT 1];
            if (!sites.isEmpty()) {
                Site site = sites[0];
                // Use Organization domain
                Organization org = [SELECT InstanceName FROM Organization LIMIT 1];
                String baseUrl = 'https://' + org.InstanceName.toLowerCase() + '.salesforce.com';
                return baseUrl + '/s/' + site.UrlPathPrefix;
            }
        } catch (Exception e) {
            System.debug('Error getting site URL: ' + e.getMessage());
        }
        
        // Option 2: Return organization URL (fallback)
        try {
            Organization org = [SELECT InstanceName FROM Organization LIMIT 1];
            return 'https://' + org.InstanceName.toLowerCase() + '.salesforce.com/lightning/page/home';
        } catch (Exception e) {
            System.debug('Error getting organization URL: ' + e.getMessage());
            return 'https://login.salesforce.com';
        }
    }
    
    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        String emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        Pattern pattern = Pattern.compile(emailRegex);
        Matcher matcher = pattern.matcher(email);
        return matcher.matches();
    }
    
    // Inner class for CSV data
    public class AppointmentRequestData {
        public String agentEmail;
        public String agentId;
        public String referenceFirstName;
        public String referenceLastName;
        public String referenceEmail;
    }
    
    // Result class
    public class UploadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer recordsCreated;
        @AuraEnabled public Integer emailsSent;
        
        public UploadResult() {
            this.success = false;
            this.recordsCreated = 0;
            this.emailsSent = 0;
        }
    }
}

