/**
 * @description Selector class for Selectee__c queries
 */
public inherited sharing class SelecteeSelector {
    
    /**
     * @description Retrieves selectees by email addresses
     * @param emails Set of email addresses to search for
     * @return Map of lowercase email to Selectee record
     */
    public static Map<String, Selectee__c> getSelecteesByEmails(Set<String> emails) {
        Map<String, Selectee__c> selecteesByEmail = new Map<String, Selectee__c>();
        
        for (Selectee__c s : [SELECT Id, Email__c FROM Selectee__c WHERE Email__c IN :emails]) {
            if (String.isNotBlank(s.Email__c)) {
                selecteesByEmail.put(s.Email__c.toLowerCase(), s);
            }
        }
        
        return selecteesByEmail;
    }
}

