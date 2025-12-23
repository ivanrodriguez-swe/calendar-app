@isTest
private class AvailabilityCSVParserTest {
    
    @isTest
    static void testParseAvailabilityCSV_Success() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'volunteer1@test.com,2025-01-15,09:00,10:00\n' +
            'volunteer2@test.com,2025-01-16,10:00,11:00';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Should parse 2 rows');
        
        System.assertEquals('volunteer1@test.com', result[0].volunteerEmail, 'Should parse email');
        System.assertEquals('2025-01-15', result[0].dayValue, 'Should parse day');
        System.assertEquals('09:00', result[0].startTime, 'Should parse start time');
        System.assertEquals('10:00', result[0].endTime, 'Should parse end time');
    }
    
    @isTest
    static void testParseAvailabilityCSV_WithoutHeader() {
        String csvContent = 'volunteer1@test.com,2025-01-15,09:00,10:00\n' +
            'volunteer2@test.com,2025-01-16,10:00,11:00';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Should parse 2 rows');
    }
    
    @isTest
    static void testParseAvailabilityCSV_WithQuotedValues() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            '"volunteer1@test.com","2025-01-15","09:00","10:00"';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should parse 1 row');
        System.assertEquals('volunteer1@test.com', result[0].volunteerEmail, 'Should handle quotes');
    }
    
    @isTest
    static void testParseAvailabilityCSV_EmptyContent() {
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV('');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testParseAvailabilityCSV_NullContent() {
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testParseAvailabilityCSV_BlankLines() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'volunteer1@test.com,2025-01-15,09:00,10:00\n' +
            '\n' +
            'volunteer2@test.com,2025-01-16,10:00,11:00\n' +
            '   \n';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Should skip blank lines');
    }
    
    @isTest
    static void testParseAvailabilityCSV_IncompleteRows() {
        String csvContent = 'Volunteer Email,Day,Start Time,End Time\n' +
            'volunteer1@test.com,2025-01-15,09:00\n' + // Missing end time
            'volunteer2@test.com,2025-01-16,10:00,11:00';
        
        Test.startTest();
        List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
            AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should skip incomplete rows');
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
            String csvContent = header + '\nvolunteer1@test.com,2025-01-15,09:00,10:00';
            
            List<AvailabilityCSVParser.AvailabilityCSVRow> result = 
                AvailabilityCSVParser.parseAvailabilityCSV(csvContent);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(1, result.size(), 'Should parse with header: ' + header);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testParseCSVLine_Simple() {
        String line = 'value1,value2,value3';
        
        Test.startTest();
        List<String> result = AvailabilityCSVParser.parseCSVLine(line);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.size(), 'Should parse 3 values');
        System.assertEquals('value1', result[0], 'Should parse first value');
        System.assertEquals('value2', result[1], 'Should parse second value');
        System.assertEquals('value3', result[2], 'Should parse third value');
    }
    
    @isTest
    static void testParseCSVLine_WithQuotes() {
        String line = '"value,with,commas","normal value","another value"';
        
        Test.startTest();
        List<String> result = AvailabilityCSVParser.parseCSVLine(line);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.size(), 'Should parse 3 values');
        System.assertEquals('value,with,commas', result[0], 'Should handle quoted commas');
    }
    
    @isTest
    static void testParseCSVLine_EmptyValues() {
        String line = 'value1,,value3,';
        
        Test.startTest();
        List<String> result = AvailabilityCSVParser.parseCSVLine(line);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(4, result.size(), 'Should parse 4 values including empty');
    }
}

