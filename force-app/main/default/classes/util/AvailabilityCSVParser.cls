public class AvailabilityCSVParser {
    
    public class AvailabilityCSVRow {
        public String volunteerEmail;
        public String dayValue;
        public String startTime;
        public String endTime;
    }
    
    public static List<AvailabilityCSVRow> parseAvailabilityCSV(String csvContent) {
        List<AvailabilityCSVRow> rows = new List<AvailabilityCSVRow>();
        
        if (String.isBlank(csvContent)) {
            return rows;
        }
        
        List<String> lines = csvContent.split('\n');
        
        Integer startIndex = 0;
        if (lines.size() > 0) {
            String firstLine = lines[0].trim().toLowerCase();
            Boolean looksLikeHeader = (firstLine.contains('volunteer email') || 
                                      firstLine.contains('volunteer,') ||
                                      firstLine.startsWith('email,') ||
                                      firstLine.startsWith('day,') ||
                                      firstLine.startsWith('date,') ||
                                      firstLine.contains('start time') ||
                                      firstLine.contains('end time') ||
                                      (firstLine.contains('start,') && firstLine.contains('end,')) ||
                                      (firstLine.contains('time') && !firstLine.contains('@')));
            if (looksLikeHeader) {
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
    
    public static List<String> parseCSVLine(String line) {
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
        
        values.add(currentValue);
        
        return values;
    }
}
