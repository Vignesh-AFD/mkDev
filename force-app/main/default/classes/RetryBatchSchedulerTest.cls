@IsTest
private class RetryBatchSchedulerTest {
    
    @TestSetup
    static void setup() {
        // Create test Integration User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User integrationUser = new User(
            FirstName = 'Integration',
            LastName = 'User',
            Email = 'integration.user@test.com',
            Username = 'integration.user@DiscordTest.com',
            Alias = 'intuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert integrationUser;
    }
    
   
     @isTest
     static void testOrderBatchSchedule() {

          Test.startTest();
          RetryBatchScheduler scheduler = new RetryBatchScheduler();
          scheduler.execute(null);
          Test.stopTest();

     }
    
    
  
}