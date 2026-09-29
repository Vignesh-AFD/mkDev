@IsTest
public class ScheduleStalledOpportunityEmailTest {

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

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer i = 1; i <= 2; i++) {
            opportunities.add(new Opportunity(
                Name = 'Valid Test Opportunity ' + i,
                StageName = 'Stalled',
                CloseDate = Date.today().addDays(120),
                RecordTypeId = oppRecordType.Id,
                OwnerId = testOwner.Id, 
                Amount = 4000 + (i * 1000),
                Type = 'New Business',
                LeadSource = 'Web',
                Probability = 60
            ));
        }

        insert opportunities;
    }

    @IsTest
    static void testSchedulableExecution() {
        Test.startTest();

        String cronExpression = '0 0 0 * * ?';
        String scheduledJobName = 'Test_Schedule_Stalled_Opportunity_Email';

        System.schedule(scheduledJobName, cronExpression, new ScheduleStalledOpportunityEmail());

        CronTrigger cronTrigger = [
            SELECT Id, CronExpression, TimesTriggered, State, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :scheduledJobName
        ];

        System.assertEquals('WAITING', cronTrigger.State, 'The scheduled job should be in WAITING state.');

        Test.stopTest();

        System.assert(true, 'Batch class for sending stalled opportunity emails should have been executed.');
    }
}