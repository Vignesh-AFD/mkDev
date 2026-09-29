@isTest
private class TriggerOnContentDocumentLink_Test {
    @isTest
    static void testFinanceProfileRestriction() {
        // Get the Finance profile
        Profile financeProfile = [SELECT Id FROM Profile WHERE Name = 'Finance' LIMIT 1];

        // Create a user with the Finance profile
        User financeUser = new User(
            Alias = 'fuser',
            Email = 'financeuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FinanceUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = financeProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'financeuser123@example1234.com'
        );
        insert financeUser;

        System.runAs(financeUser) {
            // Create a file (ContentVersion)
            ContentVersion cv = new ContentVersion(
                Title = 'Test File',
                PathOnClient = 'TestFile.txt',
                VersionData = Blob.valueOf('Test file content')
            );
            try{
                insert cv;
            }catch (Exception e) {
                System.debug('insert failed!');
            }
        }
    }
}