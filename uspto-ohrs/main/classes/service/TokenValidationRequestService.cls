/**
 * This class is created to validate tokens.
 */
public inherited sharing class TokenValidationRequestService {

    /**
     * This method expectes that the token is stored in a field named
     * "URL_Token__c." The field must live in the object whose api name matches with 
     * objecApiName
     * @param String token; vaue of he token to be verified
     * @param String Id; Id of the record where the token must be retrieved from
     * @return Boolean ; true of the token matches, false if not
     */
    public static Boolean validateURLToken (String token, String recordId){
        if(String.isBlank(token) || String.isBlank(recordId)){
             throw new TokenValidationRequestServiceException( 'recordId and token must be valid parameters');
        }
        Schema.SObjectType sObjectType;
        try{
            Id resultId = Id.valueOf(recordId);
            System.debug('Id from Service clase '+resultId);
            System.debug('String Id '+recordId);
            sObjectType = resultId.getSobjectType();
        }catch(Exception e){
            throw new TokenValidationRequestServiceException(e.getMessage());
        }
            
        if(sObjectType == null){
            throw new TokenValidationRequestServiceException( recordId +' is not a valid Id');
        }
      
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        String objectApiName = sObjectType.getDescribe().getName();

        if(!fieldMap.containsKey('URL_Token__c')){
            throw new TokenValidationRequestServiceException('Field URL_Token__c must be created for the '+objectApiName+' object');
        }

        String query = 'SELECT Id, URL_Token__c'+
            +' FROM '+objectApiName
            +' WHERE Id = :resultId AND URL_Token__c = :token';

        List<SObject> records = Database.query(query);
        System.debug('Returned size: '+records.size());
        Boolean result = records.size() > 0;
        return result;
        
    }

    public class TokenValidationRequestServiceException extends Exception{}
}