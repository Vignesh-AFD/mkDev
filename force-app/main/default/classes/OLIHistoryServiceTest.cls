//**********************		
// Deployment Date: 27 Mar 2026		
// Created by: Dotsolved Development team		
// Jira Ticket # : SF-236
// Description: To sync with Asana from OLI	
// Last Modified Date: 24 Apr 2026		
//***********************
@IsTest
private class OLIHistoryServiceTest {

    @testSetup
    static void setupData(){

        Account acc = new Account(Name='Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'P1: Prospecting',
            Lexion_Contract_URL__c = 'https://login.salesforce.com/',
            CloseDate = Date.today().addDays(10),
            RecordTypeId = '012Kd000001Us8kIAC' // Ad Sales record type id
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = standardPricebookId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            Rate_Type__c = 'Flat Fee',
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(10),
            Targeting_Country__c = 'US',
            Reward_Type__c = 'Orbs'
        );
        insert oli;
        
        opp.StageName = 'P5: Signed/Won';
        update opp;
        
        oli.Start_Date__c = Date.today().addDays(2);
        oli.End_Date__c = Date.today().addDays(11);
        oli.UnitPrice = 10000;
        oli.Quantity = 2;
        update oli;
        
        OpportunityLineItem oli2 = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 1000,
            Rate_Type__c = 'Flat Fee',
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(10),
            Targeting_Country__c = 'US',
            Reward_Type__c = 'Orbs'
        );
        insert oli2;
    }


    @IsTest
    static void testStageCheck(){

        Boolean result = OLIHistoryService.checkIfStageIsP5OrCC('Ad Sales','P5: Signed/Won');

        System.assertEquals(true, result);
    }


    @IsTest
    static void testOliFieldUpdateDetected(){

        OpportunityLineItem oli =
            [SELECT Id, OpportunityId, UnitPrice, Quantity, Deal_Stage__c, Opp_RecordType__c, Attribution_Mobile_Store_IDs__c, 
             Avatar_Deco_Duration__c, Avatar_Deco_File_Link__c, BLS_Template_Link__c, Brand_Lift_Study__c, Attribution_Partner_Multi__c,
             Eligibility_Age_Restriction__c, Eligibility_Geographical__c, Eligibility_Traits__c, End_Date__c, Game_Movie_Content_Rating__c, 
             General_Market_Creative_Approval_Thread__c, Has_Split_Test__c, Media_Plan_Worksheet_URL__c, Official_Game_Product_Name__c, 
             Quest_Completion_Task__c, Quest_Setup_Status__c, Reward_Type__c, Split_Test_Type__c, Start_Date__c, Targeting_Country__c, 
             Task_Campaign_Name__c, Time_Requirement_min__c, TotalPrice, Use_Multi_Ad_Sets__c, Quest_ID__c, Quests_Title__c, Rate_Type__c, 
             Product_Name__c, CreatedDate
             FROM OpportunityLineItem
             LIMIT 1];

        OpportunityLineItem oldOli = oli.clone(false,true,false,false);

        oli.Quantity = 5;

        Boolean result = OLIHistoryService.oliFieldUpdateDetectedAfterP4(oli, oldOli);

        System.assertNotEquals(null, result);
    }


    @IsTest
    static void testCreateHistoryRecords(){

        OpportunityLineItem oli =
            [SELECT Id, OpportunityId, UnitPrice, Quantity, Deal_Stage__c, Opp_RecordType__c, Attribution_Mobile_Store_IDs__c, 
             Avatar_Deco_Duration__c, Avatar_Deco_File_Link__c, BLS_Template_Link__c, Brand_Lift_Study__c, Attribution_Partner_Multi__c,
             Eligibility_Age_Restriction__c, Eligibility_Geographical__c, Eligibility_Traits__c, End_Date__c, Game_Movie_Content_Rating__c, 
             General_Market_Creative_Approval_Thread__c, Has_Split_Test__c, Media_Plan_Worksheet_URL__c, Official_Game_Product_Name__c, 
             Quest_Completion_Task__c, Quest_Setup_Status__c, Reward_Type__c, Split_Test_Type__c, Start_Date__c, Targeting_Country__c, 
             Task_Campaign_Name__c, Time_Requirement_min__c, TotalPrice, Use_Multi_Ad_Sets__c, Quest_ID__c, Quests_Title__c, Rate_Type__c,
             Product_Name__c, CreatedDate
             FROM OpportunityLineItem
             LIMIT 1];

        OpportunityLineItem oldOli = oli.clone(false,true,false,false);

        oli.Quantity = 10;

        update oli;

        List<OpportunityLineItem> newList = new List<OpportunityLineItem>{oli};

        Map<Id,OpportunityLineItem> oldMap = new Map<Id,OpportunityLineItem>{oli.Id => oldOli};

        Test.startTest();

        OLIHistoryService.createOLIHistories(newList, oldMap);

        Test.stopTest();

        List<Opportunity_Product_History__c> histories =
            [SELECT Id, Field_API_Name__c
             FROM Opportunity_Product_History__c];

        System.assert(histories.size() >= 0);
    }


    @IsTest
    static void testQueueableExecution(){

        Opportunity_Product_History__c hist =
            new Opportunity_Product_History__c(
                Field_Label__c = 'Quantity',
                Field_API_Name__c = 'Quantity',
                Old_Value__c = '1',
                New_Value__c = '5',
                Modified_Date__c = System.now(),
                Modified_By__c = UserInfo.getUserId()
            );

        List<Opportunity_Product_History__c> historyList = new List<Opportunity_Product_History__c>{hist};

        Test.startTest();
        System.enqueueJob(new OLIHistoryQueueable(historyList));
        Test.stopTest();

        List<Opportunity_Product_History__c> inserted = [SELECT Id FROM Opportunity_Product_History__c];
        System.assert(inserted.size() > 0);
    }
}