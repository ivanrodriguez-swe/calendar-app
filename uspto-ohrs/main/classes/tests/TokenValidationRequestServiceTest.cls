@isTest
public with sharing class TokenValidationRequestServiceTest {
    @testSetup
    static void setup() {
        // Create test Appointment_Request__c with URL_Token__c
        Appointment_Request__c appointmentReq = new Appointment_Request__c(
            URL_Token__c = 'valid-token-123'
        );
        insert appointmentReq;
    }
    
    @isTest
    static void testValidateURLTokenSuccess() {
        // Get test record
        Appointment_Request__c appointmentReq = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        Boolean result = TokenValidationRequestService.validateURLToken('valid-token-123', appointmentReq.Id);
        Test.stopTest();
        
        Assert.isTrue(result, 'Should return true for matching token');
    }
    
    @isTest
    static void testValidateURLTokenNoMatch() {
        // Get test record
        Appointment_Request__c appointmentReq = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        Boolean result = TokenValidationRequestService.validateURLToken('wrong-token', appointmentReq.Id);
        Test.stopTest();
        
        Assert.isFalse(result, 'Should return false for non-matching token');
    }
    
    @isTest
    static void testValidateURLTokenBlankToken() {
        Appointment_Request__c appointmentReq = [SELECT Id FROM Appointment_Request__c LIMIT 1];
        
        Test.startTest();
        try {
            TokenValidationRequestService.validateURLToken('', appointmentReq.Id);
            Assert.fail('Should throw exception for blank token');
        } catch (TokenValidationRequestService.TokenValidationRequestServiceException e) {
            Assert.areEqual('recordId and token must be valid parameters', e.getMessage(), 'An Exception must have been thrown');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateURLTokenBlankRecordId() {
        Test.startTest();
        try {
            TokenValidationRequestService.validateURLToken('valid-token', '');
            Assert.fail('Should throw exception for blank recordId');
        } catch (TokenValidationRequestService.TokenValidationRequestServiceException e) {
            Assert.areEqual('recordId and token must be valid parameters', e.getMessage(), 'An Exception must have been thrown');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateURLTokenInvalidId() {
        Test.startTest();
        try {
            TokenValidationRequestService.validateURLToken('valid-token', 'invalid-id-format');
            Assert.fail('Should throw exception for invalid Id');
        } catch (TokenValidationRequestService.TokenValidationRequestServiceException e) {
            Assert.isNotNull(e.getMessage(), 'The result was null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateURLTokenMissingField() {
        // Test with User object which doesn't have URL_Token__c field
        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        Test.startTest();
        try {
            TokenValidationRequestService.validateURLToken('token', usr.Id);
            Assert.fail('Should throw exception for missing field');
        } catch (TokenValidationRequestService.TokenValidationRequestServiceException e) {
            Assert.isTrue(e.getMessage().contains('Field URL_Token__c must be created'), 'An Exception must have been thrown');
        }
        Test.stopTest();
    }
}