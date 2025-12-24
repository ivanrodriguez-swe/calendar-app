// Utility class for time slot formatting and validation
public class TimeSlotFormatter {
    
    /**
     * Parse time string (HH:mm) to Time object
     * @param timeStr Time string in HH:mm format
     * @return Time object or null if invalid
     */
    public static Time parseTime(String timeStr) {
        if (String.isBlank(timeStr)) return null;
        List<String> parts = timeStr.split(':');
        if (parts.size() < 1) return null;
        
        try {
            Integer hour = Integer.valueOf(parts[0]);
            Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
            if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
            return Time.newInstance(hour, minute, 0, 0);
        } catch (TypeException e) {
            return null;
        }
    }
    
    /**
     * Format Time to readable string (e.g., "9:00 AM")
     * 
     * TIMEZONE-SAFE: This method formats Time objects (which are time-of-day only, no timezone)
     * into readable strings. Since Time objects don't have timezone information, formatting
     * them server-side ensures consistent display regardless of the user's timezone.
     * 
     * @param t Time object to format
     * @return Formatted time string (e.g., "9:00 AM", "2:30 PM")
     */
    public static String formatTime(Time t) {
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
    
    /**
     * Validate time range is within business hours (9:00 AM - 4:00 PM)
     * Start time must be between 9:00 AM and 3:45 PM
     * End time must be between 9:15 AM and 4:00 PM
     * End time must be after start time
     * @param startTime Start time
     * @param endTime End time
     * @return True if valid, false otherwise
     */
    public static Boolean isValidTimeRange(Time startTime, Time endTime) {
        Time minStartTime = Time.newInstance(9, 0, 0, 0);
        Time maxStartTime = Time.newInstance(15, 45, 0, 0);
        Time minEndTime = Time.newInstance(9, 15, 0, 0);
        Time maxEndTime = Time.newInstance(16, 0, 0, 0);
        
        return startTime >= minStartTime && startTime <= maxStartTime &&
               endTime >= minEndTime && endTime <= maxEndTime &&
               endTime > startTime;
    }
    
    /**
     * Create time slot structure (9:00 AM - 4:00 PM in 15-minute intervals)
     * Returns a list of time ranges as strings (e.g., "09:00:00.000Z-09:15:00.000Z")
     * Used for building the calendar grid structure
     * @return List of time range labels
     */
    public static List<String> createTimeSlotStructureLabels() {
        List<String> result = new List<String>();
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
            result.add(String.valueOf(currentStart) + '-' + String.valueOf(currentEnd));
            currentStart = currentEnd;
        }
        return result;
    }
}

