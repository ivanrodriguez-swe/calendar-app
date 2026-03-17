public without sharing class TokenValidatorController {

    @AuraEnabled
    public static String  validateToken(TokenValidationRequest request){
        try {
            String result;
            System.debug('Request '+request);
            if(request == null || 
                String.isBlank(request.urlToken) ||
                String.isBlank(request.recordId)){
             return result;
            }

            if(TokenValidationRequestService.validateURLToken(request.urlToken, request.recordId)){
                result = 'isValid';
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class TokenValidationRequest{
        @AuraEnabled public String urlToken;
        @AuraEnabled public String recordId;

    }
}