@isTest
private class TimeSlotFormatterTest {
    
    @isTest
    static void testParseTime_Success() {
        Test.startTest();
        Time result1 = TimeSlotFormatter.parseTime('09:00');
        Time result2 = TimeSlotFormatter.parseTime('14:30');
        Time result3 = TimeSlotFormatter.parseTime('23:59');
        Test.stopTest();
        
        Assert.isNotNull( result1, 'Should parse 09:00');
        Assert.areEqual(9, result1.hour(), 'Should have correct hour');
        Assert.areEqual(0, result1.minute(), 'Should have correct minute');
        
        Assert.isNotNull( result2, 'Should parse 14:30');
        Assert.areEqual(14, result2.hour(), 'Should have correct hour');
        Assert.areEqual(30, result2.minute(), 'Should have correct minute');
        
        Assert.isNotNull( result3, 'Should parse 23:59');
        Assert.areEqual(23, result3.hour(), 'Should have correct hour');
        Assert.areEqual(59, result3.minute(), 'Should have correct minute');
    }
    
    @isTest
    static void testParseTime_WithSingleDigit() {
        Test.startTest();
        Time result = TimeSlotFormatter.parseTime('9:0');
        Test.stopTest();
        
        Assert.isNotNull( result, 'Should parse single digit');
        Assert.areEqual(9, result.hour(), 'Should have correct hour');
        Assert.areEqual(0, result.minute(), 'Should have correct minute');
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
        
        Assert.areEqual(null, result1, 'Should return null for empty string');
        Assert.areEqual(null, result2, 'Should return null for null');
        Assert.areEqual(null, result3, 'Should return null for invalid format');
        Assert.areEqual(null, result4, 'Should return null for invalid hour');
        Assert.areEqual(null, result5, 'Should return null for invalid minute');
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
        
        Assert.isNotNull( result1, 'Should format 9:00');
        Assert.isTrue(result1.contains('AM'), 'Should indicate AM');
        
        Assert.isNotNull( result2, 'Should format 14:30');
        Assert.isTrue(result2.contains('PM'), 'Should indicate PM');
        Assert.isTrue(result2.contains('2:30'), 'Should convert to 12-hour format');
        
        Assert.isNotNull( result3, 'Should format 23:59');
        Assert.isTrue(result3.contains('PM'), 'Should indicate PM');
        
        Assert.isNotNull( result4, 'Should format 12:00');
        Assert.isTrue(result4.contains('PM'), 'Should indicate PM');
        
        Assert.isNotNull( result5, 'Should format 00:00');
        Assert.isTrue(result5.contains('AM'), 'Should indicate AM');
    }
    
    @isTest
    static void testFormatTime_Null() {
        Test.startTest();
        String result = TimeSlotFormatter.formatTime(null);
        Test.stopTest();
        
        Assert.areEqual('', result, 'Should return empty string for null');
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
        
        Assert.areEqual(true, result1, 'Should validate 9:00-9:15');
        Assert.areEqual(true, result2, 'Should validate 15:45-16:00');
        Assert.areEqual(true, result3, 'Should validate 10:30-11:00');
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
        
        Assert.areEqual(false, result1, 'Should reject start before 9:00');
        Assert.areEqual(false, result2, 'Should reject start after 15:45');
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
        
        Assert.areEqual(false, result1, 'Should reject end before 9:15');
        Assert.areEqual(false, result2, 'Should reject end after 16:00');
    }
    
    @isTest
    static void testIsValidTimeRange_EndBeforeStart() {
        Time start = Time.newInstance(10, 0, 0, 0);
        Time endTime = Time.newInstance(9, 0, 0, 0);
        
        Test.startTest();
        Boolean result = TimeSlotFormatter.isValidTimeRange(start, endTime);
        Test.stopTest();
        
        Assert.areEqual(false, result, 'Should reject end before start');
    }
    
    @isTest
    static void testIsValidTimeRange_EqualTimes() {
        Time start = Time.newInstance(10, 0, 0, 0);
        Time endTime = Time.newInstance(10, 0, 0, 0);
        
        Test.startTest();
        Boolean result = TimeSlotFormatter.isValidTimeRange(start, endTime);
        Test.stopTest();
        
        Assert.areEqual(false, result, 'Should reject equal times');
    }
}

