@isTest
private class TimeSlotFormatterTest {
    
    @isTest
    static void testParseTime_Success() {
        Test.startTest();
        Time result1 = TimeSlotFormatter.parseTime('09:00');
        Time result2 = TimeSlotFormatter.parseTime('14:30');
        Time result3 = TimeSlotFormatter.parseTime('23:59');
        Test.stopTest();
        
        System.assertNotEquals(null, result1, 'Should parse 09:00');
        System.assertEquals(9, result1.hour(), 'Should have correct hour');
        System.assertEquals(0, result1.minute(), 'Should have correct minute');
        
        System.assertNotEquals(null, result2, 'Should parse 14:30');
        System.assertEquals(14, result2.hour(), 'Should have correct hour');
        System.assertEquals(30, result2.minute(), 'Should have correct minute');
        
        System.assertNotEquals(null, result3, 'Should parse 23:59');
        System.assertEquals(23, result3.hour(), 'Should have correct hour');
        System.assertEquals(59, result3.minute(), 'Should have correct minute');
    }
    
    @isTest
    static void testParseTime_WithSingleDigit() {
        Test.startTest();
        Time result = TimeSlotFormatter.parseTime('9:0');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should parse single digit');
        System.assertEquals(9, result.hour(), 'Should have correct hour');
        System.assertEquals(0, result.minute(), 'Should have correct minute');
    }
    
    @isTest
    static void testParseTime_InvalidFormat() {
        Test.startTest();
        Time result1 = TimeSlotFormatter.parseTime('');
        Time result2 = TimeSlotFormatter.parseTime(null);
        Time result3 = TimeSlotFormatter.parseTime('invalid');
        Time result4 = TimeSlotFormatter.parseTime('25:00'); // Invalid hour
        Time result5 = TimeSlotFormatter.parseTime('12:60'); // Invalid minute
        Test.stopTest();
        
        System.assertEquals(null, result1, 'Should return null for empty string');
        System.assertEquals(null, result2, 'Should return null for null');
        System.assertEquals(null, result3, 'Should return null for invalid format');
        System.assertEquals(null, result4, 'Should return null for invalid hour');
        System.assertEquals(null, result5, 'Should return null for invalid minute');
    }
    
    @isTest
    static void testFormatTime_Success() {
        Time time1 = Time.newInstance(9, 0, 0, 0);
        Time time2 = Time.newInstance(14, 30, 0, 0);
        Time time3 = Time.newInstance(23, 59, 0, 0);
        Time time4 = Time.newInstance(12, 0, 0, 0);
        Time time5 = Time.newInstance(0, 0, 0, 0);
        
        Test.startTest();
        String result1 = TimeSlotFormatter.formatTime(time1);
        String result2 = TimeSlotFormatter.formatTime(time2);
        String result3 = TimeSlotFormatter.formatTime(time3);
        String result4 = TimeSlotFormatter.formatTime(time4);
        String result5 = TimeSlotFormatter.formatTime(time5);
        Test.stopTest();
        
        System.assertNotEquals(null, result1, 'Should format 9:00');
        System.assert(result1.contains('AM'), 'Should indicate AM');
        
        System.assertNotEquals(null, result2, 'Should format 14:30');
        System.assert(result2.contains('PM'), 'Should indicate PM');
        System.assert(result2.contains('2:30'), 'Should convert to 12-hour format');
        
        System.assertNotEquals(null, result3, 'Should format 23:59');
        System.assert(result3.contains('PM'), 'Should indicate PM');
        
        System.assertNotEquals(null, result4, 'Should format 12:00');
        System.assert(result4.contains('PM'), 'Should indicate PM');
        
        System.assertNotEquals(null, result5, 'Should format 00:00');
        System.assert(result5.contains('AM'), 'Should indicate AM');
    }
    
    @isTest
    static void testFormatTime_Null() {
        Test.startTest();
        String result = TimeSlotFormatter.formatTime(null);
        Test.stopTest();
        
        System.assertEquals('', result, 'Should return empty string for null');
    }
    
    @isTest
    static void testIsValidTimeRange_Success() {
        Time start1 = Time.newInstance(9, 0, 0, 0);
        Time end1 = Time.newInstance(9, 15, 0, 0);
        
        Time start2 = Time.newInstance(15, 45, 0, 0);
        Time end2 = Time.newInstance(16, 0, 0, 0);
        
        Time start3 = Time.newInstance(10, 30, 0, 0);
        Time end3 = Time.newInstance(11, 0, 0, 0);
        
        Test.startTest();
        Boolean result1 = TimeSlotFormatter.isValidTimeRange(start1, end1);
        Boolean result2 = TimeSlotFormatter.isValidTimeRange(start2, end2);
        Boolean result3 = TimeSlotFormatter.isValidTimeRange(start3, end3);
        Test.stopTest();
        
        System.assertEquals(true, result1, 'Should validate 9:00-9:15');
        System.assertEquals(true, result2, 'Should validate 15:45-16:00');
        System.assertEquals(true, result3, 'Should validate 10:30-11:00');
    }
    
    @isTest
    static void testIsValidTimeRange_InvalidStartTime() {
        Time start1 = Time.newInstance(8, 0, 0, 0); // Too early
        Time end1 = Time.newInstance(9, 15, 0, 0);
        
        Time start2 = Time.newInstance(16, 0, 0, 0); // Too late
        Time end2 = Time.newInstance(16, 15, 0, 0);
        
        Test.startTest();
        Boolean result1 = TimeSlotFormatter.isValidTimeRange(start1, end1);
        Boolean result2 = TimeSlotFormatter.isValidTimeRange(start2, end2);
        Test.stopTest();
        
        System.assertEquals(false, result1, 'Should reject start before 9:00');
        System.assertEquals(false, result2, 'Should reject start after 15:45');
    }
    
    @isTest
    static void testIsValidTimeRange_InvalidEndTime() {
        Time start1 = Time.newInstance(9, 0, 0, 0);
        Time end1 = Time.newInstance(8, 59, 0, 0); // Too early
        
        Time start2 = Time.newInstance(15, 45, 0, 0);
        Time end2 = Time.newInstance(16, 1, 0, 0); // Too late
        
        Test.startTest();
        Boolean result1 = TimeSlotFormatter.isValidTimeRange(start1, end1);
        Boolean result2 = TimeSlotFormatter.isValidTimeRange(start2, end2);
        Test.stopTest();
        
        System.assertEquals(false, result1, 'Should reject end before 9:15');
        System.assertEquals(false, result2, 'Should reject end after 16:00');
    }
    
    @isTest
    static void testIsValidTimeRange_EndBeforeStart() {
        Time start = Time.newInstance(10, 0, 0, 0);
        Time endTime = Time.newInstance(9, 0, 0, 0);
        
        Test.startTest();
        Boolean result = TimeSlotFormatter.isValidTimeRange(start, endTime);
        Test.stopTest();
        
        System.assertEquals(false, result, 'Should reject end before start');
    }
    
    @isTest
    static void testIsValidTimeRange_EqualTimes() {
        Time start = Time.newInstance(10, 0, 0, 0);
        Time endTime = Time.newInstance(10, 0, 0, 0);
        
        Test.startTest();
        Boolean result = TimeSlotFormatter.isValidTimeRange(start, endTime);
        Test.stopTest();
        
        System.assertEquals(false, result, 'Should reject equal times');
    }
    
    @isTest
    static void testCreateTimeSlotStructureLabels() {
        Test.startTest();
        List<String> result = TimeSlotFormatter.createTimeSlotStructureLabels();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return time ranges');
        
        // Should have ranges from 9:00 to 16:00 in 15-minute intervals
        // That's 7 hours * 4 intervals = 28 slots
        System.assert(result.size() >= 20, 'Should have multiple time ranges');
        
        // Verify first range starts at 9:00
        String firstRange = result[0];
        System.assert(firstRange.contains('09:00:00'), 'First range should start at 9:00');
        
        // Verify last range ends at 16:00
        String lastRange = result[result.size() - 1];
        System.assert(lastRange.contains('16:00:00'), 'Last range should end at 16:00');
    }
}

