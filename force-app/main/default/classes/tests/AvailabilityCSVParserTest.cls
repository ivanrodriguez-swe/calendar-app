@isTest
private class AvailabilityCSVParserTest {
    
    @isTest
    static void testParseAvailabilityCSV_Success() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'volunteer1@example.com,2025-01-15,09:00,10:00\n' +
            'volunteer2@example.com,2025-01-16,10:00,11:00';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(2, result.size(), 'Should parse 2 rows');
        
        Assert.areEqual('volunteer1@example.com', result[0].volunteerEmail, 'Should parse email');
        Assert.areEqual('2025-01-15', result[0].dayValue, 'Should parse day');
        Assert.areEqual('09:00', result[0].startTime, 'Should parse start time');
        Assert.areEqual('10:00', result[0].endTime, 'Should parse end time');
    }
    
    @isTest
    static void testParseAvailabilityCSV_WithoutHeader() {
        String csvContent = 'volunteer1@example.com,2025-01-15,09:00,10:00\n' +
            'volunteer2@example.com,2025-01-16,10:00,11:00';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(2, result.size(), 'Should parse 2 rows');
    }
    
    @isTest
    static void testParseAvailabilityCSV_WithQuotedValues() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            '"volunteer1@example.com","2025-01-15","09:00","10:00"';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(1, result.size(), 'Should parse 1 row');
        Assert.areEqual('volunteer1@example.com', result[0].volunteerEmail, 'Should handle quotes');
    }
    
    @isTest
    static void testParseAvailabilityCSV_EmptyContent() {
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV('');
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testParseAvailabilityCSV_NullContent() {
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(null);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testParseAvailabilityCSV_BlankLines() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'volunteer1@example.com,2025-01-15,09:00,10:00\n' +
            '\n' +
            'volunteer2@example.com,2025-01-16,10:00,11:00\n' +
            '   \n';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(2, result.size(), 'Should skip blank lines');
    }
    
    @isTest
    static void testParseAvailabilityCSV_IncompleteRows() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'volunteer1@example.com,2025-01-15,09:00\n' + // Missing end time
            'volunteer2@example.com,2025-01-16,10:00,11:00';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(1, result.size(), 'Should skip incomplete rows');
    }
    
    @isTest
    static void testParseAvailabilityCSV_VariousHeaderFormats() {
        // Test different header variations
        String[] headers = new String[]{
            'Volunteer Email,Day,Start Time,End Time',
            'Email,Date,Start,End',
            'volunteer email,day,start time,end time',
            'VOLUNTEER EMAIL,DAY,START TIME,END TIME'
        };
        
        Test.startTest();
        for (String header : headers) {
            String csvContent = header + '\nvolunteer1@example.com,2025-01-15,09:00,10:00';
            
            List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
                AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
            
            Assert.isNotNull( result, 'Result should not be null');
            Assert.areEqual(1, result.size(), 'Should parse with header: ' + header);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testParseCSVLine_Simple() {
        String line = 'value1,value2,value3';
        
        Test.startTest();
        List<String> result = AvailabilityCSVParser.parseCSVLine(line);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(3, result.size(), 'Should parse 3 values');
        Assert.areEqual('value1', result[0], 'Should parse first value');
        Assert.areEqual('value2', result[1], 'Should parse second value');
        Assert.areEqual('value3', result[2], 'Should parse third value');
    }
    
    @isTest
    static void testParseCSVLine_WithQuotes() {
        String line = '"value,with,commas","normal value","another value"';
        
        Test.startTest();
        List<String> result = AvailabilityCSVParser.parseCSVLine(line);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(3, result.size(), 'Should parse 3 values');
        Assert.areEqual('value,with,commas', result[0], 'Should handle quoted commas');
    }
    
    @isTest
    static void testParseCSVLine_EmptyValues() {
        String line = 'value1,,value3,';
        
        Test.startTest();
        List<String> result = AvailabilityCSVParser.parseCSVLine(line);
        Test.stopTest();
        
        Assert.isNotNull( result, 'Result should not be null');
        Assert.areEqual(4, result.size(), 'Should parse 4 values including empty');
    }
}

