public class EmailTemplates {
    
    public class EmailContent {
        public String subject { get; set; }
        public String htmlBody { get; set; }
        public String plainTextBody { get; set; }
        
        public EmailContent(String subject, String htmlBody, String plainTextBody) {
            this.subject = subject;
            this.htmlBody = htmlBody;
            this.plainTextBody = plainTextBody;
        }
    }
    
    public static EmailContent getAppointmentInviteEmail(String recipientName, String inviteUrl) {
        String firstName = String.isNotBlank(recipientName) ? recipientName : 'Guest';
        
        String subject = 'Appointment Scheduling Invitation';
        
        String htmlBody = 
            '<p style="margin-bottom: 16px;">Hi ' + firstName + ',</p>' +
            '<p style="margin-bottom: 16px;">You have been invited to schedule an appointment.</p>' +
            '<p style="margin-bottom: 24px;">Please click the button below to select your preferred time slot:</p>' +
            '<p style="margin: 32px 0;">' +
            '<a href="' + inviteUrl + '" style="background-color: #0176d3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold;">Schedule Appointment</a>' +
            '</p>' +
            '<p style="margin-top: 32px;">Thank you,<br/>OHRS Team</p>';
        
        String plainTextBody = 
            'Hi ' + firstName + ',\n\n' +
            'You have been invited to schedule an appointment.\n\n' +
            'Please click the link below to select your preferred time slot:\n' +
            inviteUrl + '\n\n' +
            'Thank you,\n' +
            'OHRS Team';
        
        return new EmailContent(subject, htmlBody, plainTextBody);
    }
    
    public static EmailContent getVolunteerNotificationEmail(
        String volunteerName, 
        String customerName, 
        String customerEmail, 
        Date appointmentDate, 
        String timeRange
    ) {
        String subject = 'New Appointment Scheduled - ' + appointmentDate.format();
        
        String safeCustomerName = String.isNotBlank(customerName) ? customerName : 'Guest';
        String safeCustomerEmail = String.isNotBlank(customerEmail) ? customerEmail : 'N/A';
        
        String htmlBody = 
            '<p style="margin-bottom: 16px;">Hello ' + volunteerName + ',</p>' +
            '<p style="margin-bottom: 16px;">A new appointment has been scheduled:</p>' +
            '<table style="margin-bottom: 24px;">' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Customer:</td><td>' + safeCustomerName + '</td></tr>' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Customer Email:</td><td>' + safeCustomerEmail + '</td></tr>' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Date:</td><td>' + appointmentDate.format() + '</td></tr>' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Time:</td><td>' + timeRange + '</td></tr>' +
            '</table>' +
            '<p style="margin-top: 32px;">Thank you!</p>';
        
        String plainTextBody = 
            'Hello ' + volunteerName + ',\n\n' +
            'A new appointment has been scheduled:\n\n' +
            'Customer: ' + safeCustomerName + '\n' +
            'Customer Email: ' + safeCustomerEmail + '\n' +
            'Date: ' + appointmentDate.format() + '\n' +
            'Time: ' + timeRange + '\n\n' +
            'Thank you!';
        
        return new EmailContent(subject, htmlBody, plainTextBody);
    }
    
    public static EmailContent getCustomerConfirmationEmail(
        String customerName, 
        String volunteerName, 
        Date appointmentDate, 
        String timeRange
    ) {
        String subject = 'Appointment Confirmed - ' + appointmentDate.format();
        
        String safeCustomerName = String.isNotBlank(customerName) ? customerName : 'Guest';
        String safeVolunteerName = String.isNotBlank(volunteerName) ? volunteerName : 'N/A';
        
        String htmlBody = 
            '<p style="margin-bottom: 16px;">Hello ' + safeCustomerName + ',</p>' +
            '<p style="margin-bottom: 16px;">Your appointment has been confirmed:</p>' +
            '<table style="margin-bottom: 24px;">' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Volunteer:</td><td>' + safeVolunteerName + '</td></tr>' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Date:</td><td>' + appointmentDate.format() + '</td></tr>' +
            '<tr><td style="padding: 4px 16px 4px 0; font-weight: bold;">Time:</td><td>' + timeRange + '</td></tr>' +
            '</table>' +
            '<p style="margin-bottom: 16px;">We look forward to meeting with you!</p>' +
            '<p style="margin-top: 32px;">Thank you!</p>';
        
        String plainTextBody = 
            'Hello ' + safeCustomerName + ',\n\n' +
            'Your appointment has been confirmed:\n\n' +
            'Volunteer: ' + safeVolunteerName + '\n' +
            'Date: ' + appointmentDate.format() + '\n' +
            'Time: ' + timeRange + '\n\n' +
            'We look forward to meeting with you!\n\n' +
            'Thank you!';
        
        return new EmailContent(subject, htmlBody, plainTextBody);
    }
}
