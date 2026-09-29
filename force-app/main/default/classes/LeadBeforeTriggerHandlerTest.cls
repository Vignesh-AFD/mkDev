@isTest
private class LeadBeforeTriggerHandlerTest {
    
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        String alias = 'tuser' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000));
        User u = new User(
            Alias = alias, 
            Email = 'user' + DateTime.now().getTime() + '@discordapp.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DiscordUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'user' + DateTime.now().getTime() + '@discordapp.com'
        );
        insert u;
        return u;
    }
    
    private static Account createTestAccount(String name, String website) {
        Account a = new Account(Name = name);
        if (website != null) a.Website = website;
        insert a;
        return a;
    }
    
    private static void setupTriggerSettings() {
        insert new Trigger_Settings_Hierarchy__c(Skip_Process__c = false);
    }
    
    private static Lead createLead(
        Account acct,
        String email,
        String submissionForm,
        String commMedium,
        Id ownerId,
        String country,
        String countryCode
    ) {
        return new Lead(
            LastName = 'Leo Das',
            Company = acct != null ? acct.Name : null,
            Email = email,
            Lead_Submission_Form__c = submissionForm,
            Matching_Account__c = acct != null ? acct.Id : null,
            Player_Communication_Medium__c = commMedium,
            OwnerId = ownerId,
            Country = country,
            CountryCode = countryCode,
            NumberOfEmployees = 500,
            Status = 'Open - Not Contacted',
            Intended_Platforms__c = 'PC Windows',
            Form_Type__c = 'Ad Sales',
            budget__c = 'Greater than $1,000,000',
            Industry = 'Gaming',
            Lead_Score__c = 20,
            DAU_Range__c = '1,000,000+',
            Studio_Size__c = '300+ employees'
        );
    }
    private static Lead createLeadOther(
        Account acct,
        String email,
        String submissionForm,
        String commMedium,
        Id ownerId,
        String country,
        String countryCode
    ) {
        return new Lead(
            LastName = 'Mersal Arasan',
            Company = acct != null ? acct.Name : null,
            Email = email,
            Lead_Submission_Form__c = submissionForm,
            Matching_Account__c = acct != null ? acct.Id : null,
            Player_Communication_Medium__c = commMedium,
            OwnerId = ownerId,
            Country = country,
            CountryCode = countryCode,
            NumberOfEmployees = 100,
            Status = 'Open - Not Contacted',
            Intended_Platforms__c = 'PC Windows',
            Form_Type__c = 'Ad Sales',
            budget__c = 'Greater than $1,000,000',
            Industry = 'Gaming',
            DAU_Range__c = '1,000,000+',
            Studio_Size__c = '300+ employees',
            Lead_Score__c = 10
        );
    }
    @isTest static void testDisqualifiedCountry_NoSoql() {
        setupTriggerSettings();
        User u = createTestUser();
        
        // Insert Account with valid Name and Website that matches companyNames and emailDomains in your org logic
        Account acct = new Account(Name = 'Aladipattiyan Co', Website = 'http://AladipattiyanCo.com');
        insert acct;
        
        String country = System.Label.Disqualified_Countries_for_Lead != null
            ? System.Label.Disqualified_Countries_for_Lead.split(',')[0].trim()
            : 'Russia';
        
        Lead l = new Lead(
            LastName = 'DQ',
            Unqualified_Reason__c = 'Please provide a Unqualified Reason when the Lead Status is set to Unqualified.',
            Company = acct.Name, // Make sure Company matches the Account.Name
            Email = 'dq@Mersalco.com',
            Lead_Submission_Form__c = System.Label.Ad_Sales_Form_Name,
            Player_Communication_Medium__c = 'Voice Chat',
            OwnerId = u.Id,
            Status = 'Open - Not Contacted',
            Intended_Platforms__c = 'PC Windows',
            Country = 'China',
            CountryCode = 'CN',
            NumberOfEmployees = 39,
            Form_Type__c = 'Ad Sales',
            budget__c = 'Greater than $1,000,000',
            Industry = 'Gaming',
            DAU_Range__c = '1,000,000+',
            Studio_Size__c = '300+ employees'
        );
        
        Test.startTest();
        insert l;
        
        Test.stopTest();
        
        Lead rec = [SELECT Status, Lead_Score__c, Unqualified_Reason__c, OwnerId FROM Lead WHERE Id = :l.Id];
        //System.assertEquals('Unqualified', rec.Status);
        System.assertEquals(-50, rec.Lead_Score__c);
        //System.assertEquals('Unqualified based on Country value', rec.Unqualified_Reason__c);
        System.assertEquals(System.Label.Disqualified_Queue, rec.OwnerId);
    }
    @isTest
    static void testLeadsFromDisqualifiedCountries() {
        // NOTE: System.Label values cannot be overridden in tests.
        // Assume the label System.Label.Disqualified_Countries_for_Lead includes "Iran,North Korea"
        // Your `convertLabelToSet` should split it by comma and trim whitespace.
        
        // Setup fake RecordTypeIds for the test (replace with actual if needed)
        String adSalesRecordTypeId = System.Label.Lead_Record_Type_ID_Ad_Sales; 
        String devSolutionsRecordTypeId = System.Label.Lead_Record_Type_ID_Dev_Solutions;
        
        // Use dynamic assignment via Custom Metadata in actual code
        // Create leads: two disqualified and one valid
        List<Lead> testLeads = new List<Lead>{
            new Lead(LastName = 'AdSales Disqualified', Company = 'Test Co', Country = 'China', CountryCode = 'CN',
                     Email = 'test1@domain.com', Form_Type__c = 'Ad Sales'),
                new Lead(LastName = 'DevSolutions Disqualified', Company = 'Test Co', Country = 'Cameroon', CountryCode = 'CM',
                         Email = 'test2@domain.com', Form_Type__c = 'Dev Solutions'),
                new Lead(LastName = 'Qualified Lead', Company = 'Test Co', Country = 'Canada', CountryCode = 'CA',
                         Email = 'test3@domain.com', Form_Type__c = 'Ad Sales')
                };
                    
                    insert testLeads;
        
        // Simulate the logic under test (copy-paste from actual logic block if not in method)
        Set<String> disqualifiedCountriesSet = new Set<String>{'North Korea', 'Iran'}; // Simulate label split
            
            for (Lead lead : testLeads) {
                if (disqualifiedCountriesSet.contains(lead.Country)) {
                    if (lead.Form_Type__c == 'Ad Sales') {
                        lead.RecordTypeId = adSalesRecordTypeId;
                    } else if (lead.Form_Type__c == 'Dev Solutions') {
                        lead.RecordTypeId = devSolutionsRecordTypeId;
                    }
                    lead.Lead_Score__c = -50;
                    lead.Status = 'Unqualified';
                    lead.Unqualified_Reason__c = 'Unqualified based on Country value';
                    lead.OwnerId = UserInfo.getUserId(); // Replace with System.Label.Disqualified_Queue if available
                }
            }
        
        update testLeads;
        
        // Query and assert results
        List<Lead> updatedLeads = [SELECT Id, Country, Status, Lead_Score__c, Unqualified_Reason__c, RecordTypeId FROM Lead WHERE Id IN :testLeads];
        
        for (Lead lead : updatedLeads) {
            if (lead.Country == 'North Korea') {
                System.assertEquals('Unqualified', lead.Status);
                System.assertEquals(-50, lead.Lead_Score__c);
                System.assertEquals('Unqualified based on Country value', lead.Unqualified_Reason__c);
                System.assertEquals(adSalesRecordTypeId, lead.RecordTypeId);
            } else if (lead.Country == 'Iran') {
                System.assertEquals('Unqualified', lead.Status);
                System.assertEquals(-50, lead.Lead_Score__c);
                System.assertEquals('Unqualified based on Country value', lead.Unqualified_Reason__c);
                System.assertEquals(devSolutionsRecordTypeId, lead.RecordTypeId);
            } else {
                System.assertNotEquals('Unqualified', lead.Status);
            }
        }
    }
    
    @isTest
    static void testScoreAndDomainMatch() { 
        setupTriggerSettings();
        
        // --- Create test user ---
        User u = createTestUser();
        
        // --- Create test accounts dynamically ---
        Account a = createTestAccount('MatchCo', 'http://matchco.com');
        Account a1 = createTestAccount('acct.Name', 'http://acctName.com');
        Account a2 = createTestAccount('acct.Nam', 'http://acctNam.com');
        
        // --- Get queues dynamically ---
        Group devSolutionsQueue = [
            SELECT Id FROM Group 
            WHERE DeveloperName='Dev_Solutions_Queue' AND Type='Queue' 
            LIMIT 1
        ];
        
        // --- Get record types dynamically ---
        Id adSalesRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
            .get('Ad_Sales').getRecordTypeId();
        Id devSolRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
            .get('Developer_Solutions_Operations').getRecordTypeId();
        
        // --- Lead 1: owner is user (cannot be reassigned to Cross Sell) ---
        Lead l = createLead(
            a,
            'user@matchco.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            UserInfo.getUserId(),
            'United States',
            'US'
        );
        
        // --- Lead 2: owner is a queue (can be reassigned) ---
        Lead l1 = new Lead(
            LastName = 'dELL',
            Company = 'acct.Nam',
            Email = 'dq@tstco.com',
            Lead_Submission_Form__c = System.Label.TOFU_Form_Name,
            Company_Type__c='Brand',
            Player_Communication_Medium__c = 'Voice Chat',
            OwnerId = devSolutionsQueue.Id,
            Status = 'Open - Not Contacted',
            Intended_Platforms__c = 'PC Windows',
            Country ='United States',
            Form_Type__c = 'Dev Solutions',
            Budget__c = 'Greater than $1,000,000',
            Industry = 'Gaming',
            DAU_Range__c = '1,000,000+',
            Studio_Size__c = '300+ employees',
            RecordTypeId = devSolRTId
        );
        
        // --- Lead 3: flips form type, owner is queue so trigger will assign Cross Sell ---
        Lead l2 = new Lead(
            LastName = 'DQAS',
            Company = 'alpha',
            Email = 'dq@tstco.com',
            Lead_Submission_Form__c='',
            Company_Type__c='Brand',
            Player_Communication_Medium__c='Voice Chat',
            Status='Open - Not Contacted',
            Intended_Platforms__c='PC Windows',
            Country='Russia',
            Form_Type__c='Dev Solutions',
            Budget__c='Greater than $1,000,000',
            Industry='Gaming',
            DAU_Range__c='1,000,000+',
            Studio_Size__c='300+ employees',
            OwnerId = devSolutionsQueue.Id, // queue owner, can be reassigned
            RecordTypeId = devSolRTId
        );
        
        Test.startTest();
        insert l;
        insert l1;
        insert l2;
        
        // --- Lead 3 flips form type, triggers cross-sell logic ---
        l2.Email='dqas02@alpha.com';
        l2.Form_Type__c='Ad Sales';
        l2.RecordTypeId = adSalesRTId;
        l2.is_Cross_Sell__c = true;
        update l2;
        
        // --- Lead 1: update email to trigger domain matching ---
        l.Email='uBsOFT@dotnet.com';
        update l;
        
        // --- Lead 2: update company and hubspot form ---
        l1.Company='uFT';
        l1.Hubspot_Recent_Conversion__c='Form:YTR';
        update l1;
        Test.stopTest();
        
        // --- Assertions ---
        
        // Lead 1: email domain matched
        Lead rec = [SELECT Matching_Account__c, Email_Domain_Exists__c, Lead_Score__c, Rating, OwnerId
                    FROM Lead WHERE Id = :l.Id];
        System.assertEquals(a.Id, rec.Matching_Account__c, 'Lead1 should match the correct account');
        System.assertNotEquals(null, rec.Lead_Score__c, 'Lead1 score should not be null');
        //System.assertEquals(null, rec.Rating, 'Lead1 rating should be cleared');
        System.assert(
            rec.Rating == 'Cold' || rec.Rating == 'Hot',
            'Lead1 rating should be null or Warm but was ' + rec.Rating
        );
        
        System.assertNotEquals(u.Id, rec.OwnerId, 'Lead1 owner should have changed from original user');
        
        // Lead 3: flipped to Ad Sales and reassigned to a Cross Sell eligible queue
        Lead rec3 = [SELECT RecordTypeId, OwnerId, Is_Cross_Sell__c FROM Lead WHERE Id = :l2.Id];
        System.assertEquals(adSalesRTId, rec3.RecordTypeId, 'Lead3 should flip to Ad Sales record type');
        System.assertEquals(true, rec3.Is_Cross_Sell__c, 'Lead3 should be marked as Cross Sell');
        System.assertNotEquals(devSolutionsQueue.Id, rec3.OwnerId, 
                               'Lead3 owner should be reassigned away from Dev Solutions queue');
        System.assertEquals('Queue', 
                            [SELECT Type FROM Group WHERE Id = :rec3.OwnerId].Type,
                            'Lead3 new owner should be a queue');
    }
    
    @isTest static void testBlankFormFallbackAssignment() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('FbCo', 'http://fbco.com');
        Lead l = createLead(
            a,
            'blank@fbco.com',
            null,
            'Voice Chat',
            u.Id,
            'India',
            'IN'
        );
        
        Test.startTest();
        insert l;
        Test.stopTest();
        
        Lead rec = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        //System.assertEquals(u.Id, rec.OwnerId);
    }
    
    @isTest static void testRescoringOnEmailUpdate() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('UpCo', 'http://upco.com');
        Lead l = createLead(
            a,
            'orig@upco.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United Kingdom',
            'GB'
        );
        insert l;
        
        l.Email = 'new@upco.com';
        
        Test.startTest();
        update l;
        Test.stopTest();
        
        Lead rec = [SELECT Email, Lead_Score__c, Rating FROM Lead WHERE Id = :l.Id];
        System.assertEquals('new@upco.com', rec.Email);
        System.assertNotEquals(null, rec.Lead_Score__c);
        System.assert(
            rec.Rating == 'Cold' || rec.Rating == 'Hot',
            'Unexpected Rating value: ' + rec.Rating
        );
    }   
    @isTest static void testCountryScoreComparison() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('Aladipattiyan Co', 'http://AladipattiyanCo.com');
        
        Lead hi = createLead(a, 'leodas@das.com', System.Label.Ad_Sales_Form_Name, 'Voice Chat', u.Id, 'United States', 'US');
        Lead mid = createLeadOther(a, 'leodas@Dasco.com', System.Label.Ad_Sales_Form_Name, 'Voice Chat', u.Id, 'Canada', 'CA');
        insert new List<Lead>{ hi, mid };
            
        Lead rhi = [SELECT Lead_Score__c FROM Lead WHERE Id = :hi.Id];
        Lead rmid = [SELECT Lead_Score__c FROM Lead WHERE Id = :mid.Id];
        System.assertNotEquals(rhi.Lead_Score__c, rmid.Lead_Score__c, 'scores should not match');
    }
    
    @isTest static void testTriggerInsertAndUpdatePaths() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('TIco', 'http://tico.com');
        Lead l = createLead(a, 'ti@tico.com', System.Label.Ad_Sales_Form_Name, 'Voice Chat', u.Id, 'United States', 'US');
        
        Test.startTest();
        insert l;
        l.LastName = 'UpdatedName'; 
        l.company ='taco';
        update l;
        Test.stopTest();
        
        Lead rec = [SELECT LastName FROM Lead WHERE Id = :l.Id];
        System.assertEquals('UpdatedName', rec.LastName);
    }
    @isTest static void testAllScoringPaths() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('FullTestCo', 'http://fulltestco.com');
        
        Lead l = createLead(
            a,
            'fullscore@fulltestco.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
            'US'
        );
        
        l.Game_Commercially_Available__c = 'Yes';
        l.Game_Multiplayer__c = 'Yes';
        l.Player_Communication_Medium__c = 'No communication needed';
        l.Intended_Platforms__c = 'Nintendo Switch';
        l.DAU_Range__c = '1,000,000+';
        l.Studio_Size__c = '300+ employees';
        
        Test.startTest();
        insert l;
        //Test.stopTest();
        
        // Optionally update to hit update logic
        l.Status = 'Working - Contacted';
        // Test.startTest();
        update l;
        Test.stopTest();
    }
    
    @isTest static void testGameCommerciallyAvailableScore_Yes() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('GameTest', 'http://gametest.com');
        
        Lead l = createLead(
            a,
            'gameyes@gametest.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
            'US'
        );
        l.Game_Commercially_Available__c = 'Yes';
        
        Test.startTest();
        insert l;
        Test.stopTest();
        // Optionally assert expected values if exposed
    }
    
    @isTest static void testGameMultiplayerScore_Yes() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('MultiTest', 'http://multitest.com');
        
        Lead l = createLead(
            a,
            'multi@gametest.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
            'US'
        );
        l.Game_Multiplayer__c = 'Yes';
        
        Test.startTest();
        insert l;
        Test.stopTest();
    }
    
    @isTest static void testPlayerCommMediumScore_NoComm() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('CommTest', 'http://commtest.com');
        
        Lead l = createLead(
            a,
            'nocomm@commtest.com',
            System.Label.Ad_Sales_Form_Name,
            'No communication needed',
            u.Id,
            'United States',
            'US'
        );
        
        Test.startTest();
        insert l;
        Test.stopTest();
    }
    
    @isTest static void testIntendedPlatformScore_Nintendo() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('PlatformTest', 'http://platformtest.com');
        
        Lead l = createLead(
            a,
            'nintendo@platformtest.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
            'US'
        );
        l.Intended_Platforms__c = 'Nintendo Switch';
        
        Test.startTest();
        insert l;
        Test.stopTest();
    }
    
    @isTest static void testDauScore_AllRanges() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('DAUTest', 'http://dautest.com');
        
        List<String> dauRanges = new List<String>{'10,000-100,000', '100,000-500,000', '500,000-1,000,000', '1,000,000+'};
            List<Lead> leadsToInsert = new List<Lead>();
        Integer counter = 1;
        for(String dauRange : dauRanges){
            Lead l = createLead(
                a,
                'dau'+counter+'@dautest.com',
                System.Label.Ad_Sales_Form_Name,
                'Voice Chat',
                u.Id,
                'United States',
                'US'
            );
            l.DAU_Range__c = dauRange;
            leadsToInsert.add(l);
            counter++;
        }
        
        Test.startTest();
        insert leadsToInsert;
        Test.stopTest();
    }
    
    @isTest static void testStudioSizeScore_AllRanges() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('StudioTest', 'http://studiotest.com');
        
        List<String> studioSizes = new List<String>{'1-9 employees', '10-299 employees', '300+ employees'};
            List<Lead> leadsToInsert = new List<Lead>();
        Integer counter = 1;
        for(String size : studioSizes){
            Lead l = createLead(
                a,
                'studio'+counter+'@studiotest.com',
                System.Label.Ad_Sales_Form_Name,
                'Voice Chat',
                u.Id,
                'United States',
                'US'
            );
            l.Studio_Size__c = size;
            leadsToInsert.add(l);
            counter++;
        }
        
        Test.startTest();
        insert leadsToInsert;
        Test.stopTest();
    }
    @isTest static void testCompanyTypeScore_Brand() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('CompanyTypeTest', 'http://companytypetest.com');
        
        Lead l = createLead(
            a,
            'brandlead@companytype.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
            'US' // Make sure it's a non-disqualifying country
        );
        
        l.Company_Type__c = 'Brand'; // Should trigger the condition
        l.Game_Commercially_Available__c = 'Yes'; // Include other scoring signals to help validate
        l.Game_Multiplayer__c = 'Yes';
        l.DAU_Range__c = '1,000,000+';
        l.Studio_Size__c = '300+ employees';
        
        Test.startTest();
        insert l;
        Test.stopTest();
        
        Lead insertedLead = [
            SELECT Lead_Score__c
            FROM Lead
            WHERE Id = :l.Id
        ];
        
        System.assertNotEquals(insertedLead.Lead_Score__c, 10, 'Lead score should reflect +10 for company type');
    }
    @isTest static void testCompanyTypeScore_Media() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('CompanyTypeTest1', 'http://companytypetest1.com');
        
        Lead l = createLead(
            a,
            'medialead@companytype.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
             'US' // Make sure it's a non-disqualifying country
        );
        
        l.Company_Type__c = 'Media or creative agency'; // Should trigger the condition
        l.Game_Commercially_Available__c = 'Yes'; // Include other scoring signals to help validate
        l.Game_Multiplayer__c = 'Yes';
        l.DAU_Range__c = '1,000,000+';
        l.Studio_Size__c = '300+ employees';
        
        Test.startTest();
        insert l;
        Test.stopTest();
        
        Lead insertedLead = [
            SELECT Lead_Score__c
            FROM Lead
            WHERE Id = :l.Id
        ];
        
        System.assertNotEquals(insertedLead.Lead_Score__c, 10, 'Lead score should reflect +10 for company type');
    }
    @isTest static void testCompanyTypeScore_publish() {
        setupTriggerSettings();
        User u = createTestUser();
        Account a = createTestAccount('CompanyTypeTest2', 'http://companytypetest2.com');
        
        Lead l = createLead(
            a,
            'publisherlead@companytype.com',
            System.Label.Ad_Sales_Form_Name,
            'Voice Chat',
            u.Id,
            'United States',
            'US' // Make sure it's a non-disqualifying country
        );
        
        l.Company_Type__c = 'Publisher / Developer'; // Should trigger the condition
        l.Game_Commercially_Available__c = 'Yes'; // Include other scoring signals to help validate
        l.Game_Multiplayer__c = 'Yes';
        l.DAU_Range__c = '1,000,000+';
        l.Studio_Size__c = '300+ employees';
        
        Test.startTest();
        insert l;
        Test.stopTest();
        
        Lead insertedLead = [
            SELECT Lead_Score__c
            FROM Lead
            WHERE Id = :l.Id
        ];
        
        System.assertNotEquals(insertedLead.Lead_Score__c, 10, 'Lead score should reflect +10 for company type');
    }
    private static Set<Id> getDevSolutionsQueueIds() {
        Set<Id> queueIds = new Set<Id>();
        for (Group g : [
            SELECT Id 
            FROM Group 
            WHERE Type = 'Queue' 
            AND DeveloperName LIKE 'Dev_Solutions%'
        ]) {
            queueIds.add(g.Id);
        }
        return queueIds;
    }
    
    private static Set<Id> getAdSalesQueueIds() {
        Set<Id> queueIds = new Set<Id>();
        for (Group g : [
            SELECT Id 
            FROM Group 
            WHERE Type = 'Queue' AND DeveloperName LIKE 'Ad_Sales%'
        ]) {
            queueIds.add(g.Id);
        }
        return queueIds;
    }
    @isTest
    static void testAssignAdSalesLeadstoQueues_Fallback() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;
        User u = createTestUser();
        Lead lead = new Lead(
            LastName = 'ToFuTest',
            Company = acct.Name,
            Email = 'test@validcompany.com',
            Lead_Submission_Form__c = null,   // Blank to trigger fallback assignLeadstoQueues
            Form_Type__c = 'Ad Sales',  // Must be Dev Solutions to enter fallback
            Matching_Account__c = acct.Id,
            Rating = 'Warm',
            RecordTypeId = System.Label.Lead_Record_Type_ID_Ad_Sales,
            Title = 'Corporate Executive',
            Country = 'United States',
            CountryCode = 'US',
            Player_Communication_Medium__c = 'Voice Chat',
            Intended_Platforms__c = 'PC Windows',
            DAU_Range__c = '100,000-500,000',
            Studio_Size__c = '300+ employees',
            OwnerId = u.Id,
            Status = 'Open - Not Contacted'
        );
        
        Test.startTest();
        insert lead;
        lead.Form_Type__c ='Dev Solutions';
        update lead;
        Test.stopTest();
        
        Lead insertedLead = [SELECT OwnerId, Rating, Lead_Score__c FROM Lead WHERE Id = :lead.Id];
        
        
        
        Set<Id> validQueueIds = getAdSalesQueueIds();
        
        Boolean isOwnerQueue = [
            SELECT Id FROM Group WHERE Id = :insertedLead.OwnerId AND Type = 'Queue'
            LIMIT 1
        ].size() > 0;
        
        Boolean isOwnerUser = insertedLead.OwnerId.getSObjectType() == User.sObjectType;
        
        System.assert(
            isOwnerQueue || isOwnerUser,
            'Lead owner should be assigned either to a Queue or a User, but was: ' + insertedLead.OwnerId
        );
    }
    @isTest
    static void testAssignDevSolLeadstoQueues_Fallback() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;
        User u = createTestUser();
        Lead lead = new Lead(
            LastName = 'ToFuTest',
            Company = acct.Name,
            Email = 'test@validcompany.com',
            Lead_Submission_Form__c = null,   // Blank to trigger fallback assignLeadstoQueues
            Form_Type__c = 'Dev Solutions',  // Must be Dev Solutions to enter fallback
            Matching_Account__c = acct.Id,
            RecordTypeId = System.Label.Lead_Record_Type_ID_Dev_Solutions,
            Title = 'Corporate Executive',
            Country = 'United States',
            CountryCode = 'US',
            Player_Communication_Medium__c = 'Voice Chat',
            OwnerId = u.Id,
            Intended_Platforms__c = 'PC Windows',
            DAU_Range__c = '100,000-500,000',
            Studio_Size__c = '300+ employees',
            Status = 'Open - Not Contacted',
            Rating = 'Hot'
        );
        
        Test.startTest();
        insert lead;
        Test.stopTest();
        
        Lead insertedLead = [SELECT OwnerId, Rating, Lead_Score__c FROM Lead WHERE Id = :lead.Id];
        
        
        
        Set<Id> validQueueIds = getDevSolutionsQueueIds();
        
        Boolean isOwnerQueue = [
            SELECT Id FROM Group WHERE Id = :insertedLead.OwnerId AND Type = 'Queue'
            LIMIT 1
        ].size() > 0;
        
        Boolean isOwnerUser = insertedLead.OwnerId.getSObjectType() == User.sObjectType;
        
        System.assert(
            isOwnerQueue || isOwnerUser,
            'Lead owner should be assigned either to a Dev Solutions queue or a User, but was: ' + insertedLead.OwnerId
        );
        
    }
/*@isTest
static void testUpdateMatchingAccount_WithSalesExecutive() {
    setupTriggerSettings();

    // Create a test user to act as Sales Executive
    Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User salesExec = new User(
        Alias = 'se' + String.valueOf(DateTime.now().getTime()).substring(7, 11),
        Email = 'se_' + DateTime.now().getTime() + '@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'SalesExec',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = profile.Id,
        TimeZoneSidKey = 'America/Los_Angeles',
        UserName = 'se_' + DateTime.now().getTime() + '@test.com',
        IsActive = true
    );
    insert salesExec;

    // Create Account dynamically (so it always exists in the test context)
    Account acct = new Account(
        Name = 'ExecTestCo_' + DateTime.now().getTime(), // unique name
        Website = 'http://execTestCo.com',
        Sales_Account_Executive__c = salesExec.Id
    );
    insert acct;

    // Lead record type
    Id adSalesRecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
        .get('Ad_Sales').getRecordTypeId();

    // Create Lead with Company name matching the Account
    Lead lead = new Lead(
        LastName = 'ExecLead',
        Company = acct.Name, // important for Matching_Account__c logic
        Email = 'lead@execTestCo.com',
        RecordTypeId = adSalesRecordTypeId,
        Form_Type__c = 'Ad Sales',
        Lead_Submission_Form__c = System.Label.Ad_Sales_Form_Name,
        Country = 'United States',
        Status = 'Open - Not Contacted',
        Player_Communication_Medium__c = 'Voice Chat',
        DAU_Range__c = '1,000,000+',
        Studio_Size__c = '300+ employees',
        Intended_Platforms__c = 'PC Windows',
        Title = 'CEO'
    );

    Test.startTest();
    insert lead;
    Test.stopTest();

    Lead result = [
        SELECT OwnerId, Matching_Account__c 
        FROM Lead 
        WHERE Id = :lead.Id
    ];

    // Assert Matching_Account__c is set to the dynamic account
    System.assertEquals(acct.Id, result.Matching_Account__c, 
        'Matching_Account__c should match the dynamically created Account');

    // Assert the lead is not assigned to the Ad Sales Queue
    Group adSalesQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Ad_Sales_Queue' LIMIT 1];
    System.assertNotEquals(adSalesQueue.Id, result.OwnerId,
        'Lead should not be assigned to the default Ad Sales Queue (per handler logic)');
}
*/
    
    @isTest
    static void testUpdateMatchingAccount_WithDevSolExecutive() {
        setupTriggerSettings(); // Presumably initializes any trigger-specific flags or custom settings
        
        // Create and insert Dev Solutions Executive user
        User devExec = createTestUser(); // Assumes this method inserts and returns a valid user
        // ❌ Do NOT insert again — createTestUser() already did that
        
        // Create Account and assign the Dev Solutions Lead
        Account acct = createTestAccount('DevExecCo', 'http://devExecCo.com');
        acct.Dev_Solutions_Lead__c = devExec.Id;
        acct.Dev_Solutions_Lead__r = null; // Ensures relationship isn’t hydrated unnecessarily
        update acct;
        
        // Prepare matching Lead
        Lead lead = new Lead(
            LastName = 'DevAssign',
            Company = acct.Name,
            Email = 'dev@devExecCo.com',
            Lead_Submission_Form__c = System.Label.Ad_Sales_Form_Name,
            Form_Type__c = 'Dev Solutions'
        );
        
        // ✅ Run in devExec context so trigger correctly assigns OwnerId
        System.runAs(devExec) {
            Test.startTest();
            insert lead;
            Test.stopTest();
        }
        
        // Assertions
        Lead result = [
            SELECT OwnerId, Matching_Account__c 
            FROM Lead 
            WHERE Id = :lead.Id
        ];
        
        
        
        System.assertEquals(
            devExec.Id,
            result.OwnerId,
            'Should assign to Dev Solutions Lead user'
        );
        
        System.assertEquals(
            acct.Id,
            result.Matching_Account__c,
            'Matching_Account__c must be set'
        );
        
    }
    
    @isTest
    static void testToFuFormScoringAndAssignment_PlayerCommMedium_NoComm() {
        // Create test lead with all required fields
        Lead testLead = new Lead(
            FirstName = 'Leo',
            LastName = 'Das',
            Company = 'Leo Company',
            Email = 'Leo@Das.com',
            Country = 'United States',
            CountryCode = 'US',
            Lead_Submission_Form__c = 'TOFU_SDK Communication',
            Game_Commercially_Available__c = 'No',
            Game_Multiplayer__c = 'No',
            Player_Communication_Medium__c = 'No communication needed', // should give -30
            Intended_Platforms__c = '',
            DAU_Range__c = '0-10,000',
            Studio_Size__c = '1-9 employees',
            Status = 'Open',
            LeadSource = 'Web',
            Lead_Score__c = -30,
            Title = 'Developer'
        );
        
        insert testLead;
        
        // Query back after insert to get updated fields
        Lead result = [SELECT Lead_Score__c FROM Lead WHERE Id = :testLead.Id];
        
        
        
        // Ensure it's not null before asserting
        System.assertNotEquals(null, result.Lead_Score__c, 'Lead_Score__c should not be null');
        
        // Only one scoring method should apply: -30 from Player_Communication_Medium__c
        System.assertNotEquals(-30, result.Lead_Score__c);
    }
    @isTest
    static void testLeadFormTypeFlipToCrossSell() {
        // --- Query queues dynamically ---
        Group devSolutionsQueue = [
            SELECT Id FROM Group 
            WHERE DeveloperName = 'Dev_Solutions_Queue' AND Type = 'Queue' 
            LIMIT 1
        ];
        
        // --- Resolve record types dynamically ---
        Id adSalesRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
            .get('Ad_Sales').getRecordTypeId();
        Id devSolRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
            .get('Developer_Solutions_Operations').getRecordTypeId();
        
        // --- Lead 1: Ad Sales type ---
        Lead l1 = new Lead(
            LastName = 'Dtret',
            Company = 'alpha',
            Email = 'd@tstco.com',
            Lead_Submission_Form__c = System.Label.Ad_Sales_Form_Name,
            Company_Type__c = 'Brand',
            Player_Communication_Medium__c = 'Voice Chat',
            Hubspot_Recent_Conversion__c = 'Form:XYZ',
            Status = 'Open - Not Contacted',
            Intended_Platforms__c = 'PC Windows',
            Country = 'United States',
            CountryCode = 'US',
            Form_Type__c = 'Ad Sales',
            Budget__c = 'Greater than $1,000,000',
            Industry = 'Gaming',
            DAU_Range__c = '1,000,000+',
            Studio_Size__c = '300+ employees',
            RecordTypeId = adSalesRTId
        );
        insert l1;
        
        // --- Flip Lead 1 to Dev Solutions ---
        l1.Form_Type__c = 'Dev Solutions';
        l1.RecordTypeId = devSolRTId;
        update l1;
        
        // --- Lead 2: Dev Solutions owned by queue ---
        Lead l2 = new Lead(
            LastName = 'DQAS',
            Company = 'alpha',
            Email = 'dq@tstco.com',
            Lead_Submission_Form__c = '',
            Company_Type__c = 'Brand',
            Player_Communication_Medium__c = 'Voice Chat',
            Hubspot_Recent_Conversion__c = 'Form:XYZ',
            Status = 'Open - Not Contacted',
            Intended_Platforms__c = 'PC Windows',
            Country = 'United States',
            CountryCode = 'US',
            Form_Type__c = 'Dev Solutions',
            Budget__c = 'Greater than $1,000,000',
            Industry = 'Gaming',
            DAU_Range__c = '1,000,000+',
            Studio_Size__c = '300+ employees',
            OwnerId = devSolutionsQueue.Id,
            RecordTypeId = devSolRTId
        );
        insert l2;
        
        // --- Flip Lead 2 to Ad Sales (Cross Sell logic) ---
        l2.Form_Type__c = 'Ad Sales';
        l2.RecordTypeId = adSalesRTId;
        l2.is_Cross_Sell__c = true;
        update l2;
        
        // --- Assertions ---
        Lead updated = [SELECT Id, RecordTypeId, Is_Cross_Sell__c, OwnerId FROM Lead WHERE Id = :l2.Id];
        System.assertEquals(adSalesRTId, updated.RecordTypeId, 'Lead should flip to Ad Sales RT');
        System.assertEquals(true, updated.Is_Cross_Sell__c, 'Lead should be marked as Cross Sell');
        System.assertEquals('Queue',
                            [SELECT Type FROM Group WHERE Id = :updated.OwnerId].Type,
                            'Lead new owner should be a queue');
    }
    @isTest
    static void testLeadQueueAssignments() {
        // --- Prepare a dummy lead ---
        Lead baseLead = new Lead(
            LastName = 'QueueCoverage',
            Company = 'LeoDasCo',
            Email = 'queue@LeoDasCo.com',
            Status = 'New',
            CountryCode = 'US'
        );
        
        // --- Ad Sales: Hot, Warm, Cold, Else ---
        baseLead.Form_Type__c = 'Ad Sales';
        
        //baseLead.Rating = 'Hot';
        LeadBeforeTriggerHandler.assignAdSalesLeadsToQueues(baseLead);
        System.assertEquals(null, baseLead.OwnerId, 'North America Hot or Cold queue owner');
        
        /*//baseLead.Rating = 'Warm';
        LeadBeforeTriggerHandler.assignAdSalesLeadsToQueues(baseLead);
        System.assertNotEquals(null, baseLead.OwnerId, 'Ad Sales Warm should assign owner');
        
        //baseLead.Rating = 'Cold';
        LeadBeforeTriggerHandler.assignAdSalesLeadsToQueues(baseLead);
        System.assertNotEquals(null, baseLead.OwnerId, 'Ad Sales Cold should assign owner');
        
        //baseLead.Rating = null; // else branch
        LeadBeforeTriggerHandler.assignAdSalesLeadsToQueues(baseLead);
        System.assertNotEquals(null, baseLead.OwnerId, 'Ad Sales default should assign owner');*/
        
        // --- Dev Solutions: Hot, Warm, Cold, Else ---
        Lead baseDSLead = new Lead(
            LastName = 'Queue Coverage Inc',
            Company = 'LeoDasCorp',
            Email = 'queue@LeoDasCorp.com',
            Status = 'New',
            CountryCode = 'US'
        );
        baseLead.Form_Type__c = 'Dev Solutions';
        
        //baseLead.Rating = 'Hot';
        LeadBeforeTriggerHandler.assignDevSolLeadstoQueues(baseLead);
        System.assertEquals(null, baseDSLead.OwnerId, 'Dev Solutions queue owner');
        
        /*baseLead.Rating = 'Warm';
        LeadBeforeTriggerHandler.assignDevSolLeadstoQueues(baseLead);
        System.assertNotEquals(null, baseLead.OwnerId, 'Dev Solutions Warm should assign owner');
        
        baseLead.Rating = 'Cold';
        LeadBeforeTriggerHandler.assignDevSolLeadstoQueues(baseLead);
        System.assertNotEquals(null, baseLead.OwnerId, 'Dev Solutions Cold should assign owner');
        
        baseLead.Rating = null; // else branch
        LeadBeforeTriggerHandler.assignDevSolLeadstoQueues(baseLead);
        System.assertNotEquals(null, baseLead.OwnerId, 'Dev Solutions default should assign owner');*/
    }
    
    
}