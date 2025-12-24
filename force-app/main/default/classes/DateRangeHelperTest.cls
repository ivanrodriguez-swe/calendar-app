@isTest
private class DateRangeHelperTest {
    
    @isTest
    static void testGetDatesBetween_Inclusive() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 1, 17);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(3, result.size(), 'Should return 3 dates (inclusive)');
        Assert.areEqual(startDate, result[0], 'First date should be start date');
        Assert.areEqual(endDate, result[result.size() - 1], 'Last date should be end date');
    }
    
    @isTest
    static void testGetDatesBetween_Exclusive() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 1, 17);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, false);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(2, result.size(), 'Should return 2 dates (exclusive)');
        Assert.areEqual(startDate, result[0], 'First date should be start date');
        Assert.areEqual(startDate.addDays(1), result[1], 'Last date should be day before end');
    }
    
    @isTest
    static void testGetDatesBetween_SingleDay() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 1, 15);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(1, result.size(), 'Should return 1 date');
        Assert.areEqual(startDate, result[0], 'Should return the date');
    }
    
    @isTest
    static void testGetDatesBetween_SingleDayExclusive() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 1, 15);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, false);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list when exclusive and same date');
    }
    
    @isTest
    static void testGetDatesBetween_LargeRange() {
        Date startDate = Date.newInstance(2025, 1, 1);
        Date endDate = Date.newInstance(2025, 1, 31);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(31, result.size(), 'Should return 31 dates');
        Assert.areEqual(startDate, result[0], 'First date should be start');
        Assert.areEqual(endDate, result[result.size() - 1], 'Last date should be end');
    }
    
    @isTest
    static void testGetDatesBetween_NullStartDate() {
        Date endDate = Date.newInstance(2025, 1, 15);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(null, endDate, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list for null start');
    }
    
    @isTest
    static void testGetDatesBetween_NullEndDate() {
        Date startDate = Date.newInstance(2025, 1, 15);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, null, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list for null end');
    }
    
    @isTest
    static void testGetDatesBetween_StartAfterEnd() {
        Date startDate = Date.newInstance(2025, 1, 17);
        Date endDate = Date.newInstance(2025, 1, 15);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list when start > end');
    }
    
    @isTest
    static void testGetDatesBetween_ConsecutiveDays() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 1, 16);
        
        Test.startTest();
        List<Date> result = DateRangeHelper.getDatesBetween(startDate, endDate, true);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(2, result.size(), 'Should return 2 consecutive dates');
        Assert.areEqual(startDate, result[0], 'First should be start');
        Assert.areEqual(endDate, result[1], 'Second should be end');
    }
}

