// Controller for volunteer availability and time slot management
// Using 'without sharing' to allow guest users on public sites to access time slots and book appointments
public without sharing class VolunteerAvailabilityController {
    
    // Get available time slots for a date range (used by appointmentScheduler LWC)
    @AuraEnabled(cacheable=true)
    public static List<DayWrapper> getTimeslotsForRange(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('startDate and endDate are required.');
        }
        
        // Query available time slots
        List<Time_Slot__c> slots = [
            SELECT Id, Start_Time__c, End_Time__c, Day__c, Status__c, Volunteer__c, Volunteer__r.Name
            FROM Time_Slot__c
            WHERE Day__c >= :startDate AND Day__c <= :endDate
            AND Status__c = 'Available'
            ORDER BY Start_Time__c
        ];

        // Build time slot map
        Map<String, TimeslotWrapper> timeSlotMap = new Map<String, TimeslotWrapper>();
        for (Time_Slot__c t : slots) {
            String key = t.Day__c + '-' + t.Start_Time__c + '-' + t.End_Time__c;
            timeSlotMap.put(key, new TimeslotWrapper(t.Id, t.Start_Time__c, t.End_Time__c, t.Day__c, t.Volunteer__c, t.Volunteer__r.Name));
        }

        // Build result structure with time slots grouped by time ranges
        List<DayWrapper> results = createTimeSlotStructure();
        List<Date> dates = getDatesBetween(startDate, endDate, true);
        
        for (DayWrapper dw : results) {
            for (Date day : dates) {
                String key = day + '-' + dw.label;
                if (timeSlotMap.containsKey(key)) {
                    dw.slots.add(timeSlotMap.get(key));
                } else {
                    dw.slots.add(new TimeslotWrapper(dw.label, day));
                }
            }
        }

        return results;
    }

    // Book a time slot (used by appointmentScheduler LWC)
    @AuraEnabled
    public static BookingResult bookTimeSlot(Id timeSlotId, Id customerId, Id appointmentRequestId) {
        try {
            // Query the time slot
            List<Time_Slot__c> slots = [
                SELECT Id, Volunteer__c, Volunteer__r.Email, Volunteer__r.Name, 
                       Day__c, Start_Time__c, End_Time__c, Status__c
                FROM Time_Slot__c
                WHERE Id = :timeSlotId
                LIMIT 1
            ];

            if (slots.isEmpty()) {
                throw new AuraHandledException('Time slot not found.');
            }

            Time_Slot__c slot = slots[0];
            if (slot.Status__c != 'Available') {
                throw new AuraHandledException('This time slot is no longer available.');
            }
            if (slot.Volunteer__c == null) {
                throw new AuraHandledException('No volunteer assigned to this time slot.');
            }

            // Get or create appointment request
            Appointment_Request__c appointmentRequest;
            String customerName = '';
            String customerEmail = '';
            
            if (appointmentRequestId != null) {
                // Query Appointment Request - Name field is auto-generated (autonumber format: APPT REQ - {0000})
                List<Appointment_Request__c> requests = [
                    SELECT Id, Name, Volunteer__c, Status__c, Reference_First_Name__c, 
                           Reference_Last_Name__c, Reference_Email__c
                    FROM Appointment_Request__c 
                    WHERE Id = :appointmentRequestId 
                    LIMIT 1
                ];
                
                if (requests.isEmpty()) {
                    throw new AuraHandledException('Appointment Request not found.');
                }
                
                appointmentRequest = requests[0];
                if (appointmentRequest.Volunteer__c != slot.Volunteer__c) {
                    throw new AuraHandledException('The selected time slot is not available for this appointment request.');
                }
                
                customerName = (appointmentRequest.Reference_First_Name__c != null ? appointmentRequest.Reference_First_Name__c : '') + 
                              ' ' + (appointmentRequest.Reference_Last_Name__c != null ? appointmentRequest.Reference_Last_Name__c : '');
                customerName = customerName.trim();
                customerEmail = appointmentRequest.Reference_Email__c;
            } else {
                if (customerId == null) {
                    throw new AuraHandledException('Appointment request information is required. Please use the link provided in your email.');
                }
                
                User customer = [SELECT Id, Name, Email FROM User WHERE Id = :customerId LIMIT 1];
                customerName = customer.Name;
                customerEmail = customer.Email;
                
                // Create Appointment Request - Name field is auto-generated (autonumber format: APPT REQ - {0000})
                appointmentRequest = new Appointment_Request__c(
                    Volunteer__c = slot.Volunteer__c,
                    Status__c = 'New'
                );
                insert appointmentRequest;
                // After insertion, appointmentRequest.Name is automatically populated with the autonumber value
            }

            // Create appointment record
            Appointment__c appointment = new Appointment__c(
                Appointment_Request__c = appointmentRequest.Id,
                Time_Slot__c = timeSlotId,
                Status__c = 'Confirmed'
            );
            insert appointment;

            // Update records
            appointmentRequest.Status__c = 'Reserved';
            update appointmentRequest;
            slot.Status__c = 'Booked';
            update slot;

            // Send email notifications
            sendBookingEmails(slot, customerName, customerEmail, appointment, appointmentRequest);

            return new BookingResult(true, 'Time slot booked successfully!', appointment.Id);
        } catch (Exception e) {
            throw new AuraHandledException('Error booking time slot: ' + e.getMessage());
        }
    }

    // Create time slots from availability ranges (used by volunteerAvailability LWC)
    @AuraEnabled
    public static CreateSlotsResult createTimeSlotsFromRanges(List<AvailabilityRange> ranges) {
        CreateSlotsResult result = new CreateSlotsResult();
        
        try {
            Id volunteerId = UserInfo.getUserId();
            
            if (ranges == null || ranges.isEmpty()) {
                result.success = false;
                result.message = 'No availability ranges provided';
                return result;
            }
            
            List<Time_Slot__c> potentialSlots = new List<Time_Slot__c>();
            Integer slotMinutes = 15;
            
            // First, build all potential time slots
            for (AvailabilityRange range : ranges) {
                if (range.dateValue == null || range.startTime == null || range.endTime == null) {
                    continue;
                }
                
                Date slotDate = Date.valueOf(range.dateValue);
                Time startTime = parseTime(range.startTime);
                Time endTime = parseTime(range.endTime);
                
                if (startTime == null || endTime == null || !isValidTimeRange(startTime, endTime)) {
                    continue;
                }
                
                // Create 15-minute slots
                Time currentStart = startTime;
                while (currentStart < endTime) {
                    Integer currentStartMinutes = currentStart.hour() * 60 + currentStart.minute();
                    Integer currentEndMinutes = currentStartMinutes + slotMinutes;
                    Integer slotEndHour = currentEndMinutes / 60;
                    Integer slotEndMinute = Math.mod(currentEndMinutes, 60);
                    
                    if (slotEndHour > 23) {
                        slotEndHour = 23;
                        slotEndMinute = 59;
                    }
                    
                    Time calculatedEnd = Time.newInstance(slotEndHour, slotEndMinute, 0, 0);
                    Time currentEnd = (calculatedEnd > endTime) ? endTime : calculatedEnd;
                    
                    // Create time slot - always set Status to 'Available' when creating new slots
                    Time_Slot__c ts = new Time_Slot__c();
                    ts.Start_Time__c = currentStart;
                    ts.End_Time__c = currentEnd;
                    ts.Day__c = slotDate;
                    ts.Status__c = 'Available'; // Time slots are created as Available
                    ts.Volunteer__c = volunteerId;
                    
                    potentialSlots.add(ts);
                    currentStart = calculatedEnd;
                    
                    if (currentStart >= endTime) {
                        break;
                    }
                }
            }
            
            // First, deduplicate slots within the same submission (handle overlapping ranges)
            // Example: Range 1 (9:00-9:30) and Range 2 (9:00-9:45) will create overlapping slots
            Set<String> submissionSlotKeys = new Set<String>();
            List<Time_Slot__c> deduplicatedSlots = new List<Time_Slot__c>();
            
            for (Time_Slot__c ts : potentialSlots) {
                String slotKey = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
                if (!submissionSlotKeys.contains(slotKey)) {
                    submissionSlotKeys.add(slotKey);
                    deduplicatedSlots.add(ts);
                }
            }
            
            // Now check for existing time slots in the database to avoid duplicates
            Set<String> existingSlotKeys = getExistingTimeSlotKeys(deduplicatedSlots);
            
            // Filter out duplicates - only insert slots that don't already exist in database
            List<Time_Slot__c> slotsToInsert = new List<Time_Slot__c>();
            Set<String> finalSlotKeys = new Set<String>(); // Final safety check to prevent any duplicates
            
            for (Time_Slot__c ts : deduplicatedSlots) {
                String slotKey = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
                // Check both: not in database AND not already in our insert list (final safety check)
                if (!existingSlotKeys.contains(slotKey) && !finalSlotKeys.contains(slotKey)) {
                    finalSlotKeys.add(slotKey);
                    slotsToInsert.add(ts);
                }
            }
            
            if (!slotsToInsert.isEmpty()) {
                insert slotsToInsert;
                result.success = true;
                result.message = 'Time slots processed successfully';
                result.slotsCreated = slotsToInsert.size();
            } else {
                result.success = false;
                result.message = 'Availability for this time range was already set.';
            }
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error creating time slots: ' + e.getMessage();
        }
        
        return result;
    }

    // Helper: Create time slot structure (9:00 AM - 4:00 PM in 15-minute intervals)
    private static List<DayWrapper> createTimeSlotStructure() {
        List<DayWrapper> result = new List<DayWrapper>();
        Time businessStart = Time.newInstance(9, 0, 0, 0);
        Time businessEnd = Time.newInstance(16, 0, 0, 0);
        Integer slotMinutes = 15;

        Time currentStart = businessStart;
        while (currentStart < businessEnd) {
            Integer millis = slotMinutes * 60 * 1000;
            Time currentEnd = Time.newInstance(currentStart.hour(), currentStart.minute(), currentStart.second(), currentStart.millisecond()).addMilliseconds(millis);
            if (currentEnd > businessEnd) {
                currentEnd = businessEnd;
            }
            result.add(new DayWrapper(currentStart, currentEnd));
            currentStart = currentEnd;
        }
        return result;
    }

    // Helper: Get dates between start and end (inclusive)
    private static List<Date> getDatesBetween(Date startDate, Date endDate, Boolean inclusive) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return new List<Date>();
        }
        Integer daysDiff = startDate.daysBetween(endDate);
        Integer totalDays = daysDiff + (inclusive ? 1 : 0);
        List<Date> result = new List<Date>();
        Date cursor = startDate;
        for (Integer i = 0; i < totalDays; i++) {
            result.add(cursor);
            cursor = cursor.addDays(1);
        }
        return result;
    }

    // Helper: Parse time string (HH:mm) to Time object
    private static Time parseTime(String timeStr) {
        if (String.isBlank(timeStr)) return null;
        List<String> parts = timeStr.split(':');
        if (parts.size() < 1) return null;
        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return Time.newInstance(hour, minute, 0, 0);
    }

    // Helper: Validate time range is within business hours
    private static Boolean isValidTimeRange(Time startTime, Time endTime) {
        Time minStartTime = Time.newInstance(9, 0, 0, 0);
        Time maxStartTime = Time.newInstance(15, 45, 0, 0);
        Time minEndTime = Time.newInstance(9, 15, 0, 0);
        Time maxEndTime = Time.newInstance(16, 0, 0, 0);
        
        return startTime >= minStartTime && startTime <= maxStartTime &&
               endTime >= minEndTime && endTime <= maxEndTime &&
               endTime > startTime;
    }

    // Helper: Send booking confirmation emails
    private static void sendBookingEmails(Time_Slot__c slot, String customerName, String customerEmail, Appointment__c appointment, Appointment_Request__c appointmentRequest) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Email to Volunteer
        if (slot.Volunteer__r.Email != null) {
            Messaging.SingleEmailMessage volunteerEmail = new Messaging.SingleEmailMessage();
            volunteerEmail.setToAddresses(new List<String>{ slot.Volunteer__r.Email });
            volunteerEmail.setSubject('New Appointment Scheduled - ' + slot.Day__c.format());
            volunteerEmail.setPlainTextBody(
                'Hello ' + slot.Volunteer__r.Name + ',\n\n' +
                'A new appointment has been scheduled:\n\n' +
                'Customer: ' + (String.isNotBlank(customerName) ? customerName : 'Guest') + '\n' +
                'Customer Email: ' + (String.isNotBlank(customerEmail) ? customerEmail : 'N/A') + '\n' +
                'Date: ' + slot.Day__c.format() + '\n' +
                'Time: ' + formatTime(slot.Start_Time__c) + ' - ' + formatTime(slot.End_Time__c) + '\n\n' +
                'Thank you!'
            );
            emails.add(volunteerEmail);
        }

        // Email to Customer
        if (String.isNotBlank(customerEmail)) {
            Messaging.SingleEmailMessage customerEmailMsg = new Messaging.SingleEmailMessage();
            customerEmailMsg.setToAddresses(new List<String>{ customerEmail });
            customerEmailMsg.setSubject('Appointment Confirmed - ' + slot.Day__c.format());
            customerEmailMsg.setPlainTextBody(
                'Hello ' + (String.isNotBlank(customerName) ? customerName : 'Guest') + ',\n\n' +
                'Your appointment has been confirmed:\n\n' +
                'Volunteer: ' + slot.Volunteer__r.Name + '\n' +
                'Date: ' + slot.Day__c.format() + '\n' +
                'Time: ' + formatTime(slot.Start_Time__c) + ' - ' + formatTime(slot.End_Time__c) + '\n\n' +
                'We look forward to meeting with you!\n\n' +
                'Thank you!'
            );
            emails.add(customerEmailMsg);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }

    // Helper: Format Time to readable string
    private static String formatTime(Time t) {
        if (t == null) return '';
        Integer hours = t.hour();
        Integer minutes = t.minute();
        String ampm = hours >= 12 ? 'PM' : 'AM';
        if (hours > 12) hours = hours - 12;
        if (hours == 0) hours = 12;
        String minutesStr = String.valueOf(minutes);
        if (minutesStr.length() == 1) {
            minutesStr = '0' + minutesStr;
        }
        return String.valueOf(hours) + ':' + minutesStr + ' ' + ampm;
    }

    // Create time slots from CSV file (used by volunteerAvailabilityUploader LWC)
    @AuraEnabled
    public static CreateSlotsResult createTimeSlotsFromCSV(String csvContent) {
        CreateSlotsResult result = new CreateSlotsResult();
        
        try {
            if (String.isBlank(csvContent)) {
                result.success = false;
                result.message = 'CSV content is empty';
                return result;
            }
            
            // Parse CSV
            List<AvailabilityCSVRow> csvRows = parseAvailabilityCSV(csvContent);
            
            if (csvRows.isEmpty()) {
                result.success = false;
                result.message = 'No valid records found in CSV';
                return result;
            }
            
            // Get unique volunteer emails and create map
            Set<String> volunteerEmails = new Set<String>();
            for (AvailabilityCSVRow row : csvRows) {
                if (String.isNotBlank(row.volunteerEmail) && isValidEmail(row.volunteerEmail)) {
                    volunteerEmails.add(row.volunteerEmail.toLowerCase());
                }
            }
            
            // Query Users by email
            Map<String, Id> emailToUserIdMap = new Map<String, Id>();
            if (!volunteerEmails.isEmpty()) {
                List<User> users = [
                    SELECT Id, Email 
                    FROM User 
                    WHERE Email IN :volunteerEmails 
                    AND IsActive = true
                ];
                for (User u : users) {
                    emailToUserIdMap.put(u.Email.toLowerCase(), u.Id);
                }
            }
            
            // Create time slots for each row
            List<Time_Slot__c> potentialSlots = new List<Time_Slot__c>();
            Integer slotMinutes = 15;
            Integer rowsProcessed = 0;
            Integer rowsSkipped = 0;
            List<String> skippedReasons = new List<String>();
            
            // First, build all potential time slots
            for (AvailabilityCSVRow row : csvRows) {
                try {
                    // Validate volunteer email
                    if (String.isBlank(row.volunteerEmail)) {
                        rowsSkipped++;
                        skippedReasons.add('Row ' + (rowsProcessed + rowsSkipped) + ': Missing volunteer email');
                        continue;
                    }
                    
                    Id volunteerId = emailToUserIdMap.get(row.volunteerEmail.toLowerCase());
                    if (volunteerId == null) {
                        rowsSkipped++;
                        skippedReasons.add('Row ' + (rowsProcessed + rowsSkipped) + ': Volunteer email not found: ' + row.volunteerEmail);
                        continue;
                    }
                    
                    // Parse date
                    Date slotDate;
                    try {
                        slotDate = Date.valueOf(row.dayValue);
                    } catch (Exception e) {
                        rowsSkipped++;
                        skippedReasons.add('Row ' + (rowsProcessed + rowsSkipped) + ': Invalid date format: ' + row.dayValue);
                        continue;
                    }
                    
                    // Parse times
                    Time startTime = parseTime(row.startTime);
                    Time endTime = parseTime(row.endTime);
                    
                    if (startTime == null || endTime == null) {
                        rowsSkipped++;
                        skippedReasons.add('Row ' + (rowsProcessed + rowsSkipped) + ': Invalid time format');
                        continue;
                    }
                    
                    // Validate time range
                    if (!isValidTimeRange(startTime, endTime)) {
                        rowsSkipped++;
                        skippedReasons.add('Row ' + (rowsProcessed + rowsSkipped) + ': Time range outside business hours (9:00 AM - 4:00 PM) or invalid');
                        continue;
                    }
                    
                    // Create 15-minute slots (reuse same logic as createTimeSlotsFromRanges)
                    Time currentStart = startTime;
                    while (currentStart < endTime) {
                        Integer currentStartMinutes = currentStart.hour() * 60 + currentStart.minute();
                        Integer currentEndMinutes = currentStartMinutes + slotMinutes;
                        Integer slotEndHour = currentEndMinutes / 60;
                        Integer slotEndMinute = Math.mod(currentEndMinutes, 60);
                        
                        if (slotEndHour > 23) {
                            slotEndHour = 23;
                            slotEndMinute = 59;
                        }
                        
                        Time calculatedEnd = Time.newInstance(slotEndHour, slotEndMinute, 0, 0);
                        Time currentEnd = (calculatedEnd > endTime) ? endTime : calculatedEnd;
                        
                        // Create time slot - always set Status to 'Available' when creating new slots
                        Time_Slot__c ts = new Time_Slot__c();
                        ts.Start_Time__c = currentStart;
                        ts.End_Time__c = currentEnd;
                        ts.Day__c = slotDate;
                        ts.Status__c = 'Available'; // Time slots are created as Available
                        ts.Volunteer__c = volunteerId;
                        
                        potentialSlots.add(ts);
                        currentStart = calculatedEnd;
                        
                        if (currentStart >= endTime) {
                            break;
                        }
                    }
                    
                    rowsProcessed++;
                } catch (Exception e) {
                    rowsSkipped++;
                    skippedReasons.add('Row ' + (rowsProcessed + rowsSkipped) + ': Error - ' + e.getMessage());
                }
            }
            
            // First, deduplicate slots within the same submission (handle overlapping ranges)
            // Example: Range 1 (9:00-9:30) and Range 2 (9:00-9:45) will create overlapping slots
            Set<String> submissionSlotKeys = new Set<String>();
            List<Time_Slot__c> deduplicatedSlots = new List<Time_Slot__c>();
            
            for (Time_Slot__c ts : potentialSlots) {
                String slotKey = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
                if (!submissionSlotKeys.contains(slotKey)) {
                    submissionSlotKeys.add(slotKey);
                    deduplicatedSlots.add(ts);
                }
            }
            
            // Now check for existing time slots in the database to avoid duplicates
            Set<String> existingSlotKeys = getExistingTimeSlotKeys(deduplicatedSlots);
            
            // Filter out duplicates - only insert slots that don't already exist in database
            List<Time_Slot__c> slotsToInsert = new List<Time_Slot__c>();
            Set<String> finalSlotKeys = new Set<String>(); // Final safety check to prevent any duplicates
            
            for (Time_Slot__c ts : deduplicatedSlots) {
                String slotKey = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
                // Check both: not in database AND not already in our insert list (final safety check)
                if (!existingSlotKeys.contains(slotKey) && !finalSlotKeys.contains(slotKey)) {
                    finalSlotKeys.add(slotKey);
                    slotsToInsert.add(ts);
                }
            }
            
            // Insert all new slots (bypass duplicates, insert non-duplicates)
            // For CSV uploader: Always return success with generic message if CSV was processed
            // Duplicates are silently bypassed - this is expected behavior
            if (!slotsToInsert.isEmpty()) {
                insert slotsToInsert;
            }
            
            // Always return success for CSV uploader if we processed the file (even if all were duplicates)
            // Duplicates are silently bypassed (both within file and in database)
            // This is different from volunteerAvailability LWC which shows specific error messages
            result.success = true;
            result.message = 'Availability processed successfully';
            result.slotsCreated = slotsToInsert.size();
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error processing CSV: ' + e.getMessage();
        }
        
        return result;
    }
    
    // Parse CSV content for availability upload
    private static List<AvailabilityCSVRow> parseAvailabilityCSV(String csvContent) {
        List<AvailabilityCSVRow> rows = new List<AvailabilityCSVRow>();
        
        if (String.isBlank(csvContent)) {
            return rows;
        }
        
        List<String> lines = csvContent.split('\n');
        
        // Skip header row if present
        Integer startIndex = 0;
        if (lines.size() > 0) {
            String firstLine = lines[0].trim().toLowerCase();
            if (firstLine.contains('volunteer') || firstLine.contains('email') || 
                firstLine.contains('day') || firstLine.contains('date') ||
                firstLine.contains('start') || firstLine.contains('end') ||
                firstLine.contains('time')) {
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
                AvailabilityCSVRow row = new AvailabilityCSVRow();
                row.volunteerEmail = values[0].trim();
                row.dayValue = values[1].trim();
                row.startTime = values[2].trim();
                row.endTime = values[3].trim();
                
                if (String.isNotBlank(row.volunteerEmail) && 
                    String.isNotBlank(row.dayValue) && 
                    String.isNotBlank(row.startTime) && 
                    String.isNotBlank(row.endTime)) {
                    rows.add(row);
                }
            }
        }
        
        return rows;
    }
    
    // Helper: Parse CSV line (handle quoted values)
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
    
    // Helper: Validate email format
    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) return false;
        return email.contains('@') && email.contains('.');
    }
    
    // Helper: Build a unique key for a time slot (Day + Start_Time + End_Time + Volunteer)
    private static String buildTimeSlotKey(Date day, Time startTime, Time endTime, Id volunteerId) {
        String dayStr = day != null ? String.valueOf(day) : '';
        String startStr = startTime != null ? String.valueOf(startTime) : '';
        String endStr = endTime != null ? String.valueOf(endTime) : '';
        String volunteerStr = volunteerId != null ? String.valueOf(volunteerId) : '';
        return dayStr + '|' + startStr + '|' + endStr + '|' + volunteerStr;
    }
    
    // Helper: Query existing time slots and return a set of keys to check for duplicates
    private static Set<String> getExistingTimeSlotKeys(List<Time_Slot__c> potentialSlots) {
        Set<String> existingKeys = new Set<String>();
        
        if (potentialSlots == null || potentialSlots.isEmpty()) {
            return existingKeys;
        }
        
        // Collect unique dates, times, and volunteer IDs
        Set<Date> dates = new Set<Date>();
        Set<Id> volunteerIds = new Set<Id>();
        
        for (Time_Slot__c ts : potentialSlots) {
            if (ts.Day__c != null) {
                dates.add(ts.Day__c);
            }
            if (ts.Volunteer__c != null) {
                volunteerIds.add(ts.Volunteer__c);
            }
        }
        
        if (dates.isEmpty() || volunteerIds.isEmpty()) {
            return existingKeys;
        }
        
        // Query existing time slots that match any of the potential slots
        List<Time_Slot__c> existingSlots = [
            SELECT Day__c, Start_Time__c, End_Time__c, Volunteer__c
            FROM Time_Slot__c
            WHERE Day__c IN :dates
            AND Volunteer__c IN :volunteerIds
        ];
        
        // Build set of keys for existing slots
        for (Time_Slot__c ts : existingSlots) {
            String key = buildTimeSlotKey(ts.Day__c, ts.Start_Time__c, ts.End_Time__c, ts.Volunteer__c);
            existingKeys.add(key);
        }
        
        return existingKeys;
    }
    
    // Wrapper class for CSV row data
    public class AvailabilityCSVRow {
        public String volunteerEmail;
        public String dayValue; // YYYY-MM-DD format
        public String startTime; // HH:mm format
        public String endTime;   // HH:mm format
    }

    // Wrapper Classes
    public class DayWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public List<TimeslotWrapper> slots;
        
        public DayWrapper(Time startTime, Time endTime) {
            this.label = startTime + '-' + endTime;
            this.slots = new List<TimeslotWrapper>();
        }
    }

    public class TimeslotWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public Date day;
        @AuraEnabled public String label;
        @AuraEnabled public Id volunteerId;
        @AuraEnabled public String volunteerName;
        @AuraEnabled public Boolean isAvailable;
        @AuraEnabled public Boolean isUnavailable;

        public TimeslotWrapper(Id id, Time startTime, Time endTime, Date day, Id volunteerId, String volunteerName) {
            this.id = id;
            this.startTime = startTime;
            this.endTime = endTime;
            this.day = day;
            this.label = day + '-' + startTime + '-' + endTime;
            this.volunteerId = volunteerId;
            this.volunteerName = volunteerName;
            this.isAvailable = true;
            this.isUnavailable = false;
        }

        public TimeslotWrapper(String label, Date day) {
            this.id = null;
            this.startTime = null;
            this.endTime = null;
            this.day = day;
            this.label = label;
            this.volunteerId = null;
            this.volunteerName = null;
            this.isAvailable = false;
            this.isUnavailable = true;
        }
    }

    public class BookingResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id appointmentId;

        public BookingResult(Boolean success, String message, Id appointmentId) {
            this.success = success;
            this.message = message;
            this.appointmentId = appointmentId;
        }
    }

    public class AvailabilityRange {
        @AuraEnabled public String dateValue { get; set; }
        @AuraEnabled public String startTime { get; set; }
        @AuraEnabled public String endTime { get; set; }
    }

    public class CreateSlotsResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer slotsCreated;
        
        public CreateSlotsResult() {
            this.success = false;
            this.slotsCreated = 0;
        }
    }
}

