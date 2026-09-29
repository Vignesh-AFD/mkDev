@isTest
public class LeadBeforeTriggerHandler_Test {
    
    // Get required RecordType Ids once
    private static Id getRecordTypeId(String name) {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Lead' AND Name = :name LIMIT 1].Id;
    }
    
    // Create active user for assignment
    private static User createActiveUser(String alias, String username) {
        return new User(
            Alias = alias,
            Email = alias + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = username
        );
    }
    
    @isTest
    static void testDisqualifiedCountryLeadAssignedToQueue() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        Lead disqualifiedLead = new Lead(
            FirstName = 'Disqual',
            LastName = 'Lead',
            Company = 'BadCo',
            Country = 'Russia',
            Form_Type__c = 'Ad Sales',
            Email = 'disqual@test.com',
            Status = 'Open - Not Contacted'
        );
        insert disqualifiedLead;
        
        Lead fetched = [SELECT OwnerId FROM Lead WHERE Id = :disqualifiedLead.Id];
        System.assertEquals(System.Label.Disqualified_Queue, fetched.OwnerId, 'Disqualified lead should go to queue');
    }
    @isTest
    static void testDisqualifiedCountryLeadAssignedToQueue1() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        Lead disqualifiedLead1 = new Lead(
            FirstName = 'Disqual',
            LastName = 'Lead',
            Company = 'BadCo',
            Country = 'Russia',
            Form_Type__c = 'Dev Solutions',
            Email = 'disqual@test.com',
            Status = 'Open - Not Contacted'
        );
        insert disqualifiedLead1;
        
        Lead fetched = [SELECT OwnerId FROM Lead WHERE Id = :disqualifiedLead1.Id];
        System.assertEquals(System.Label.Disqualified_Queue, fetched.OwnerId, 'Disqualified lead should go to queue');
    }
    
    @isTest
    static void testFallbackQueueAssignedWhenNoAccountMatches() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        Lead fallbackLead = new Lead(
            FirstName = 'Fallback',
            LastName = 'Lead',
            Company = 'GhostCo',
            Country = 'India',
            Form_Type__c = 'Dev Solutions',
            Email = 'ghost@test.com',
            Status = 'Open - Not Contacted'
        );
        insert fallbackLead;
        
        Lead fetched = [SELECT OwnerId, Matching_Account__c FROM Lead WHERE Id = :fallbackLead.Id];
        System.assertEquals(System.Label.Dev_Solutions_Queue, fetched.OwnerId, 'Should be assigned to fallback queue');
        System.assertEquals(null, fetched.Matching_Account__c, 'Should not match any account');
    }
    
    @isTest
    static void testLeadMatchesAccountAndAssignsOwner() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        User devLead = createActiveUser('devlead', 'devlead@test.com');
        insert devLead;
        
        Account acc = new Account(
            Name = 'MatchCo',
            Dev_Solutions_Lead__c = devLead.Id
        );
        insert acc;
        
        Lead lead = new Lead(
            FirstName = 'Matchy',
            LastName = 'McMatch',
            Company = 'MatchCo',
            Country = 'India',
            Form_Type__c = 'Dev Solutions',
            Email = 'match@test.com',
            Status = 'Open - Not Contacted'
        );
        insert lead;
        
        Lead fetched = [SELECT OwnerId, Matching_Account__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(devLead.Id, fetched.OwnerId, 'Should assign to active Dev Lead');
        System.assertEquals(acc.Id, fetched.Matching_Account__c, 'Should match account correctly');
    }
    
    @isTest
    static void testLeadWithAccountButNoActiveUserGetsQueue() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        Account acc = new Account(Name = 'QueueMatch');
        insert acc;
        
        Lead lead = new Lead(
            FirstName = 'Queuey',
            LastName = 'NoOwner',
            Company = 'QueueMatch',
            Country = 'India',
            Form_Type__c = 'Ad Sales',
            Email = 'queue@test.com',
            Status = 'Open - Not Contacted'
        );
        insert lead;
        
        Lead fetched = [SELECT OwnerId FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(System.Label.Ad_Sales_Queue_ID, fetched.OwnerId, 'Should fall back to Ad Sales queue');
    }
    @isTest
    static void testAssginLeadstoQueuesGetsCalled() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        // Insert multiple accounts with partial matches
        insert new List<Account>{
            new Account(Name = 'MatchCo India'),
                new Account(Name = 'MatchCo Solutions')
                };
                    
                    Lead lead = new Lead(
                        FirstName = 'Partial',
                        LastName = 'Match',
                        Company = 'MatchCo',
                        Country = 'India',
                        Form_Type__c = 'Ad Sales',
                        Email = 'partial@test.com',
                        Status = 'Open - Not Contacted'
                    );
        insert lead;
        
        // Verify it fell back to the queue
        Lead fetched = [SELECT OwnerId, Matching_Account__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(System.Label.Ad_Sales_Queue_ID, fetched.OwnerId, 'Should be assigned to Ad Sales queue due to no exact account match');
        System.assertEquals(null, fetched.Matching_Account__c, 'Should not match any account');
    }
    @isTest
    static void testAssginLeadstoQueuesGetsCalledAdSales() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        // Insert multiple accounts with partial matches
        insert new List<Account>{
            new Account(Name = 'MatchCo India'),
                new Account(Name = 'MatchCo Solutions')
                };
                    
                    Lead lead = new Lead(
                        FirstName = 'Partial',
                        LastName = 'Match',
                        Company = 'MatchCo',
                        Country = 'India',
                        Form_Type__c = 'Ad Sales',
                        RecordTypeId = System.Label.Lead_Record_Type_ID_Ad_Sales,
                        Email = 'partial@test.com',
                        Status = 'Open - Not Contacted'
                    );
        insert lead;
        
        // Verify it fell back to the queue
        Lead fetched = [SELECT OwnerId, Matching_Account__c, RecordTypeId FROM Lead WHERE Id = :lead.Id];
        
        System.assertEquals(System.Label.Ad_Sales_Queue_ID, fetched.OwnerId, 'Should be assigned to Ad Sales queue due to no exact account match');
        System.assertEquals(System.Label.Lead_Record_Type_ID_Ad_Sales, fetched.RecordTypeId, 'RecordTypeId should be set correctly');
        System.assertEquals(null, fetched.Matching_Account__c, 'Should not match any account');
    }
    @isTest
    static void testAssginLeadstoQueuesGetsCalledDevSolns() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
        
        // Insert multiple accounts with partial matches
        insert new List<Account>{
            new Account(Name = 'MatchCo India'),
                new Account(Name = 'MatchCo Solutions')
                };
                    
                    Lead lead = new Lead(
                        FirstName = 'Partial',
                        LastName = 'Match',
                        Company = 'MatchCo',
                        Country = 'India',
                        Form_Type__c = 'Dev Solutions',
                        Email = 'partial@test.com',
                        Status = 'Open - Not Contacted'
                    );
        insert lead;
        
        // Verify it fell back to the queue
        Lead fetched = [SELECT OwnerId, Matching_Account__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(System.Label.Dev_Solutions_Queue, fetched.OwnerId, 'Should be assigned to Dev Solns queue due to no exact account match');
        System.assertEquals(null, fetched.Matching_Account__c, 'Should not match any account');
    }
    
}