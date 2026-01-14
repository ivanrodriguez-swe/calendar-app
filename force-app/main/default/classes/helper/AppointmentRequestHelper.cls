/**
 * @description Helper class for parsing appointment request files
 */
public without sharing class AppointmentRequestHelper {
    
    /**
     * @description Parses file content to extract selectee and reference data
     * @param fileContent The file content as a string
     * @return List of parsed data maps with selectee and references info
     */
    public static List<Map<String, Object>> parseFile(String fileContent) {
        List<Map<String, Object>> dataList = new List<Map<String, Object>>();
        
        if (String.isBlank(fileContent)) {
            return dataList;
        }
        
        String normalizedContent = fileContent.replace('\r\n', '\n').replace('\r', '\n');
        List<String> lines = normalizedContent.split('\n');
        
        Integer startIndex = 0;
        if (lines.size() > 0) {
            String firstLine = lines[0].trim().toLowerCase();
            Boolean looksLikeHeader = firstLine.contains('selectee') || 
                                      firstLine.contains('first name') || 
                                      firstLine.contains('last name') ||
                                      firstLine.contains('reference') ||
                                      firstLine.contains('discipline') ||
                                      firstLine.contains('eod');
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
            
            if (values.size() >= 5) {
                Map<String, Object> selecteeData = new Map<String, Object>();
                
                selecteeData.put('selecteeLastName', values[0].trim());
                selecteeData.put('selecteeFirstName', values[1].trim());
                selecteeData.put('selecteeEmail', values[2].trim());
                selecteeData.put('expectedEOD', values[3].trim());
                selecteeData.put('discipline', values[4].trim());
                
                List<Map<String, String>> references = new List<Map<String, String>>();
                
                if (values.size() >= 7 && String.isNotBlank(values[5].trim()) && String.isNotBlank(values[6].trim())) {
                    Map<String, String> ref1 = new Map<String, String>();
                    ref1.put('name', values[5].trim());
                    ref1.put('email', values[6].trim());
                    ref1.put('relationship', values.size() >= 8 ? values[7].trim() : '');
                    references.add(ref1);
                }
                
                if (values.size() >= 10 && String.isNotBlank(values[8].trim()) && String.isNotBlank(values[9].trim())) {
                    Map<String, String> ref2 = new Map<String, String>();
                    ref2.put('name', values[8].trim());
                    ref2.put('email', values[9].trim());
                    ref2.put('relationship', values.size() >= 11 ? values[10].trim() : '');
                    references.add(ref2);
                }
                
                if (values.size() >= 13 && String.isNotBlank(values[11].trim()) && String.isNotBlank(values[12].trim())) {
                    Map<String, String> ref3 = new Map<String, String>();
                    ref3.put('name', values[11].trim());
                    ref3.put('email', values[12].trim());
                    ref3.put('relationship', values.size() >= 14 ? values[13].trim() : '');
                    references.add(ref3);
                }
                
                selecteeData.put('references', references);
                
                if (String.isNotBlank((String)selecteeData.get('selecteeLastName')) && 
                    String.isNotBlank((String)selecteeData.get('selecteeFirstName'))) {
                    dataList.add(selecteeData);
                }
            }
        }
        
        return dataList;
    }
    
    private static List<String> parseCSVLine(String line) {
        List<String> values = new List<String>();
        Boolean inQuotes = false;
        String currentValue = '';
        
        for (Integer i = 0; i < line.length(); i++) {
            String currentChar = line.substring(i, i + 1);
            
            if (currentChar == '"') {
                inQuotes = !inQuotes;
            } else if (currentChar == ',' && !inQuotes) {
                values.add(currentValue.trim());
                currentValue = '';
            } else {
                currentValue += currentChar;
            }
        }
        
        values.add(currentValue.trim());
        
        return values;
    }
}
