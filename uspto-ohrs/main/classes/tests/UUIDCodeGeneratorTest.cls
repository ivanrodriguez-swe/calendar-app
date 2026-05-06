@isTest
public class UUIDCodeGeneratorTest {
 @isTest
    static void testGenerateCodeValidLength() {
        // Test with valid length
        Test.startTest();
        String uuid = UUIDCodeGenerator.generateCode(10);
        Test.stopTest();
        
        Assert.areEqual(10, uuid.length(), 'Should return 10 characters');
        Assert.isNotNull(uuid, 'Should not be null');
    }
    
    @isTest
    static void testGenerateCodeNullLength() {
        // Test with null length - should default to 36
        Test.startTest();
        String uuid = UUIDCodeGenerator.generateCode();
        Test.stopTest();
        
        Assert.areEqual(36, uuid.length(), 'Should return full UUID');
    }
    
    @isTest
    static void testGenerateCodeMaxLength() {
        // Test with max valid length
        Test.startTest();
        String uuid = UUIDCodeGenerator.generateCode(36);
        Test.stopTest();
        
        Assert.areEqual(36, uuid.length(), 'Should return full UUID');
    }
    
    @isTest
    static void testGenerateCodeExceedsMaxLength() {
        // Test exception case
        Test.startTest();
        try {
            UUIDCodeGenerator.generateCode(37);
            Assert.fail('Should throw exception');
        } catch (UnsupportedOperationException e) {
            Assert.areEqual('The Maximum lentgh for UUIDs code is 36 and the minimum 1', e.getMessage(), 'It should have thrown an exception');
        }
        Test.stopTest();
    }
}