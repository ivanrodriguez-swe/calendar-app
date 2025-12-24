public class DateRangeHelper {
    
    /**
     * Get dates between start and end date (inclusive)
     * @param startDate Start date
     * @param endDate End date
     * @param inclusive Whether to include the end date
     * @return List of dates between start and end
     */
    public static List<Date> getDatesBetween(Date startDate, Date endDate, Boolean inclusive) {
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
}

