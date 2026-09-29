@IsTest
private class OpportunityCampaignCompletedTest {

    // Minimal helper to create a PricebookEntry
    private static PricebookEntry createPBE() {
        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Product2Id  = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice   = 10,
            IsActive    = true
        );
        insert pbe;

        return pbe;
    }

    @IsTest
    static void testBatch() {
        PricebookEntry pbe = createPBE();

        // Get an initial (earliest) stage to avoid the validation rule
        OpportunityStage initStage = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            ORDER BY SortOrder ASC
            LIMIT 1
        ];

        // 1) Insert Opp in an early stage
        Opportunity opp = new Opportunity(
            Name      = 'Batch Test Opp',
            StageName = initStage.MasterLabel,
            CloseDate = Date.today()
        );
        insert opp;

        // 2) Insert OLI to drive End_Date__c rollup
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            Quantity         = 1,
            PricebookEntryId = pbe.Id,
            TotalPrice       = 10,
            End_Date__c      = Date.today().addDays(-1) // yesterday
        );
        insert oli;

        // 3) Now safely move Opp to P5 so batch will pick it up
        opp.StageName = 'P5: Signed/Won';
        update opp;

        Test.startTest();
        Database.executeBatch(new OpportunityCampaignCompletedBatch(), 200);
        Test.stopTest();

        opp = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Campaign Completed', opp.StageName);
    }

    @IsTest
    static void testScheduler() {
        Test.startTest();
        // Just ensure scheduler runs and calls the batch
        new OpportunityCampaignCompletedScheduler().execute(null);
        Test.stopTest();
    }
}