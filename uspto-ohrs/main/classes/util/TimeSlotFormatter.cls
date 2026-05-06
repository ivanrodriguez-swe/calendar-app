/**
 * @description Utility class for formatting and parsing time values
 */
public class TimeSlotFormatter {
    
    /**
     * @description Parses a time string in HH:MM format
     * @param timeStr The time string to parse
     * @return Parsed Time or null if invalid
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
     * @description Formats a Time value to a readable string (e.g., "9:00 AM")
     * @param t The Time value to format
     * @return Formatted time string
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
     * @description Validates if a time range is within business hours
     * @param startTime The start time to validate
     * @param endTime The end time to validate
     * @return Boolean indicating if the range is valid
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
}
