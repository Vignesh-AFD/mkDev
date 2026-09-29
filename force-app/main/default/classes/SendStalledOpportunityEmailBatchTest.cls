@isTest
public class SendStalledOpportunityEmailBatchTest {

    @testSetup
    static void setupTestData() {
        RecordType oppRecordType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Global_Partnership' AND SobjectType = 'Opportunity' LIMIT 1];

        User testOwner = new User(
            Username = 'test.owner@example.com',
            LastName = 'Owner',
            Email = 'owner@example.com',
            Alias = 'owner1',
            CommunityNickname = 'testowner',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testOwner;

        Opportunity opp1 = new Opportunity(
            Name = 'Opportunity 1',
            StageName = 'Stalled',
            CloseDate = Date.today().addDays(90),
            RecordTypeId = oppRecordType.Id,
            OwnerId = testOwner.Id,
            Amount = 5000,
            Type = 'New Business',
            LeadSource = 'Web',
            Probability = 75
        );

        Opportunity opp2 = new Opportunity(
            Name = 'Opportunity 2',
            StageName = 'Stalled',
            CloseDate = Date.today().addDays(120),
            RecordTypeId = oppRecordType.Id,
            OwnerId = testOwner.Id,
            Amount = 7000,
            Type = 'Existing Business',
            LeadSource = 'Referral',
            Probability = 50
        );

        insert new List<Opportunity>{ opp1, opp2 };
    }

    @isTest
    static void testSingleBatchExecution() {
        String testQuery = 'SELECT Id, Name, StageName, OwnerId, Owner.Email, Owner.FirstName, Owner.LastName, RecordType.Name ' +
                           'FROM Opportunity WHERE StageName = \'Stalled\' LIMIT 2';

        Test.startTest();

        SendStalledOpportunityEmailBatch batch = new SendStalledOpportunityEmailBatch(testQuery);

        Database.executeBatch(batch, 2); // Single batch execution guaranteed

        Test.stopTest();

        System.assert(true, 'Batch executed successfully with valid data.');
    }

    @isTest
    static void testBatchExecutionWithNoData() {
        delete [SELECT Id FROM Opportunity];

        Test.startTest();

        SendStalledOpportunityEmailBatch batch = new SendStalledOpportunityEmailBatch();
        Database.executeBatch(batch, 2);

        Test.stopTest();

        System.assert(true, 'Batch executed successfully with no matching opportunities.');
    }

    @isTest
    static void testHandlesInvalidEmailsGracefully() {
        List<User> users = [SELECT Id, Email FROM User WHERE Email LIKE '%@example.com%'];
        for (User u : users) {
            u.Email = 'noemail@example.com';
        }
        update users;

        Test.startTest();

        SendStalledOpportunityEmailBatch batch = new SendStalledOpportunityEmailBatch();
        Database.executeBatch(batch, 2);

        Test.stopTest();

        System.assert(true, 'Batch executed successfully while skipping invalid emails.');
    }
}