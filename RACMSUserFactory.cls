@isTest
public class RACMSUserFactory {
    public static String usptoNoAccessPlatformProfileId = getProfileId('USPTO No Access - Platform');
    
    public static Id createJobApplicantWithoutAUserLinked(){
        Contact c;
        Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account newPersonAccount = new Account();
        newPersonAccount.FirstName = 'Job';
        newPersonAccount.LastName = 'Applicant';
        newPersonAccount.RecordTypeId = personAccountRecordTypeId;
        insert newPersonAccount;
        c = [Select Id From Contact WHERE isPersonAccount = true LIMIT 1];
        c.Email = 'jobapplicant@my.uspto.test.com';
        update c;
        return c.Id;
    }
    
    public static User createSpecialist(){
        User user;
        Map<String, String> parameters = new Map<String, String>();
        parameters.put('nameGroup','RACMS_Specialists' );
        parameters.put('permissionSetGroup', 'RACMS_EEO_Specialists');
        parameters.put('name','SP');
        parameters.put('profileId', usptoNoAccessPlatformProfileId );
        user = createUser(parameters);
        return user;
    }
    
    public static User createDecidingOfficial(){
        return createDecidingOfficial('DO');
    }
    
    public static User createDecidingOfficial(String name){
        User user;
        Map<String, String> parameters = new Map<String, String>();
        parameters.put('nameGroup','RACMS_Deciding_Officials' );
        parameters.put('permissionSetGroup', 'RACMS_Deciding_Official');
        parameters.put('name',name);
        parameters.put('profileId', usptoNoAccessPlatformProfileId );
        user = createUser(parameters);
        return user;
    }
    
    public static User createRACMSAdmin(){
        User user;
        Map<String, String> parameters = new Map<String, String>();
        parameters.put('nameGroup','RACMS_PTO_Admins' );
        parameters.put('permissionSetGroup', 'RACMS_Admin');
        parameters.put('name','rAd');
        parameters.put('profileId', usptoNoAccessPlatformProfileId );
        user = createUser(parameters);
        return user;
    }
    
    public static User createRAManager(){
        User user;
        Map<String, String> parameters = new Map<String, String>();
        parameters.put('nameGroup','RACMS_RA_Managers' );
        parameters.put('permissionSetGroup', 'RACMS_RA_Manager');
        parameters.put('name','Ra');
        parameters.put('profileId', usptoNoAccessPlatformProfileId );
        user = createUser(parameters);
        return user;
        
    }
    
    public static User createRACMSDeploymentUser(){
        User user;
        User sysAd = getSysAdmin();
        System.runAs(sysAd){
            Map<String, String> parameters = new Map<String, String>();
            parameters.put('nameGroup','RACMS_PTO_Admins' );
            parameters.put('permissionSetGroup', 'RACMS_Admin');
            parameters.put('name','dpl');
            Id profileId = getProfileId('System Administrator');
            parameters.put('profileId', profileId );
            user = createUser(parameters);
        }
        return user;
    }
    /***************************************** HELPER METHODS *******************************************/
    
    public static User createUser(String name){
        User newUser = new User();
        newUser.FirstName= 'Test-'+name;
        newUser.LastName='Test-'+name;
        newUser.Alias ='a_'+name;
        newUser.TimeZoneSidKey = 'America/New_York';
        newUser.LocaleSidKey = 'en_US';
        newUser.EmailEncodingKey = 'ISO-8859-1';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.Email='test_'+name+'_test@emailtest.com';
        newUser.userName= 'test_'+name+'_test@emailtest.com';
        return newUser;
    }
    private static User createUser(Map<String,String> parameters){
        User user = createUser(parameters.get('name'));
        user.ProfileId = parameters.get('profileId');
        insert user;
        String groupId = getPublicGroupId(parameters.get('nameGroup'));
        String permissionSetGroup = getPermissionSetGroupId(parameters.get('permissionSetGroup'));
        GroupMember memberGroup = new GroupMember();
        memberGroup.GroupId = groupId;
        memberGroup.UserOrGroupId = user.Id;
        insert memberGroup;
        PermissionSetAssignment permAssignment = new PermissionSetAssignment();
        permAssignment.AssigneeId = user.Id;
        permAssignment.PermissionSetGroupId = permissionSetGroup;
        insert permAssignment;
        return user;
        
    }
    /********************************** Profile, Permission Set Group, and Public group getters *********************/
    private static Id getProfileId(String name){
        Profile profile = [SELECT Id, Name FROM Profile WHERE Name =:name LIMIT 1];
        return profile.id;
    }
    
    private static Id getPermissionSetGroupId(String developerName){
        PermissionSetGroup permSetGroup = [SELECT Id, DeveloperName, Status FROM PermissionSetGroup WHERE DeveloperName=:developerName LIMIT 1];
        if(permSetGroup.Status != 'Updated'){
            Test.calculatePermissionSetGroup(permSetGroup.Id);
        }
        return permSetGroup.Id;
    }
    
    private static Id getPublicGroupId(String developerName){
        Group publicGroup = [SELECT Id, DeveloperName  FROM Group WHERE DeveloperName=:developerName LIMIT 1];
        return publicGroup.Id;
    }
    
    private static User getSysAdmin(){
        User usr = createUser('sysAd');
        Id profileID = getProfileId('System Administrator');
        usr.ProfileId = profileId;
        return usr;
    }
    
}