/**
 * This class provides a simple way to generate UUIDs
 * In case it is needed to generate a shorter code for other applications, the lentgh can be specified.
 * This class uses a standard UUID class, avoiding the necesity to implement any login=c
 * increasing performance
 */
public class UUIDCodeGenerator{
    private final static Integer LENGTH = 36;
    
    /**
     * Calling this method with null, generates the default 36 UUID
     * @params Ineteger lentgh of string generated
     * @return string 
     */
    public static String generateCode(Integer length){
        Integer finalLength = 0;
        if(length == null){
            finalLength = LENGTH;
        }else{
            finalLength = length;
        }
        if (finalLength > 36 || finalLength <= 0 ){
            throw new UnsupportedOperationException('The Maximum lentgh for UUIDs code is 36 and the minimum 1');
        }
        return System.UUID.randomUUID().toString().substring(0,finalLength);
    }

    public static String generateCode(){
         return System.UUID.randomUUID().toString();
    }

   public class UUIDCodeGeneratorException extends Exception{}
}