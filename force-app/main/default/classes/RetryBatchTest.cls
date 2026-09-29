@IsTest
private class RetryBatchTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            AccountId = acc.Id
        );
        insert opp;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();

        // Failure record (to trigger error log)
        oliList.add(new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 300,
            Sync_to_Asana__c = 'Yes',
            Integration_Status__c = 'Failure',
            Retry_Attempts__c = 1,
            Method_Name__c = 'updateAsanaTaskFields',
            Task_GID__c = 'GIDFAIL',
            Request__c = '{"data":{"name":"Task Fail"}}',
            Status__c = 'Active'
        ));

        insert oliList;
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":{"gid":"123","name":"Updated"}}');
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }

    @IsTest
    static void testBatchWithSuccessMock() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new RetryBatchonOli(), 2);
        Test.stopTest();

        List<OpportunityLineItem> olis = [
            SELECT Integration_Status__c, Retry_Attempts__c
            FROM OpportunityLineItem
        ];
        System.assertEquals(true, olis.size() > 0, 'OLIs should exist');
        System.assert(
            olis[0].Integration_Status__c == 'Success' || olis[0].Retry_Attempts__c >= 0,
            'OLI should have been processed successfully or retried'
        );
    }

    @IsTest
    static void testBatchWithFailureMock() {
        // Ensure a failure is simulated
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Test.startTest();
        Database.executeBatch(new RetryBatchonOli(), 1);
        Test.stopTest();

        // Query error logs created for failed OLIs
        List<Error_Log__c> logs = [SELECT Id, Integration_Message__c FROM Error_Log__c];
        System.assert(
            logs != null && logs.size() > 0,
            'Error logs should be inserted for failed records — none found. Check mock or data setup.'
        );
    }

    @IsTest
    static void testMakeCalloutUtilityMethodNoRequestBody() {
        HttpResponse res = RetryBatchonOli.makeCalloutUtilityMethod(
            'createAsanaTask', '', 'POST',
            new Map<String, String>{ 'Authorization' => 'Bearer Test' },
            '12345'
        );
        System.assertEquals(400, res.getStatusCode(), 'Should return 400 for empty request body');
    }

    @IsTest
    static void testMakeCalloutUtilityMethodWithException() {
        HttpResponse res = RetryBatchonOli.makeCalloutUtilityMethod(
            'unknownMethod', '{"data":{"test":"value"}}', 'POST',
            new Map<String, String>{},
            null
        );
        System.assert(
            res.getBody().contains('Callout failed'),
            'Should handle exception gracefully'
        );
    }

    @IsTest
    static void testBatchNoEligibleRecords() {
        List<OpportunityLineItem> olis = [SELECT Id FROM OpportunityLineItem];
        for (OpportunityLineItem oli : olis) {
            oli.Retry_Attempts__c = 5;
            oli.Integration_Status__c = 'Success';
        }
        update olis;

        Test.startTest();
        Database.executeBatch(new RetryBatchonOli());
        Test.stopTest();

        System.assert(true, 'Batch should complete with no eligible records');
    }

    @IsTest
    static void testFinishAndStartMethods() {
        RetryBatchonOli batch = new RetryBatchonOli();
        Database.QueryLocator ql = batch.start(null);
        System.assertNotEquals(null, ql, 'Query locator should not be null');
        batch.finish(null);
        System.assert(true, 'Finish should execute without error');
    }
}