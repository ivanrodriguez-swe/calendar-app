public without sharing class TokenValidatorController {

    @AuraEnabled
    public static String  validateToken(String urlToken, String recordId){
        try {
            String result;
            if(String.isBlank(urlToken) ||
                String.isBlank(recordId)){
             return result;
            }

            if(TokenValidationRequestService.validateURLToken(urlToken,recordId)){
                result = 'isValid';
            }
            System.debug(' Result: '+result);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}