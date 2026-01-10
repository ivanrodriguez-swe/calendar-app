public class TimeSlotFormatter {
    
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
