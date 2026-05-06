@isTest
public with sharing class TokenValidatorControllerTest {
      @testSetup
    static void setup() {
        // Create test Appointment_Request__c with URL_Token__c
        Appointment_Request__c appointmentReq = new Appointment_Request__c(
            URL_Token__c = 'valid-token-123'
        );
        insert appointmentReq;
    }
    
    @isTest
    static void testValidateTokenSuccess() {
        // Get test record
        Appointment_Request__c appointmentReq = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        String result = TokenValidatorController.validateToken('valid-token-123', appointmentReq.Id);
        Test.stopTest();
        
        Assert.areEqual('isValid', result, 'Should return isValid for matching token');
    }
    
    @isTest
    static void testValidateTokenNoMatch() {
        // Get test record
        Appointment_Request__c appointmentReq = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        String result = TokenValidatorController.validateToken('wrong-token', appointmentReq.Id);
        Test.stopTest();
        
        Assert.isNull(result, 'Should return null for non-matching token');
    }
    
    @isTest
    static void testValidateTokenBlankToken() {
        Appointment_Request__c appointmentReq = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        String result = TokenValidatorController.validateToken('', appointmentReq.Id);
        Test.stopTest();
        
        Assert.isNull(result, 'Should return null for blank token');
    }
    
    @isTest
    static void testValidateTokenBlankRecordId() {
        Test.startTest();
        String result = TokenValidatorController.validateToken('valid-token', '');
        Test.stopTest();
        
        Assert.isNull(result, 'Should return null for blank recordId');
    }
    
    @isTest
    static void testValidateTokenBothBlank() {
        Test.startTest();
        String result = TokenValidatorController.validateToken('', '');
        Test.stopTest();
        
        Assert.isNull(result, 'Should return null for both blank parameters');
    }

    @isTest
    static void testValidateTokenException() {
        Test.startTest();
        try {
            // Invalid ID format will cause exception in service class
            TokenValidatorController.validateToken('token', 'invalid-id-format');
            Assert.fail('Should throw AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
}