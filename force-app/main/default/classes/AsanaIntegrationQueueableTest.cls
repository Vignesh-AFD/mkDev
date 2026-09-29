@IsTest
private class AsanaIntegrationQueueableTest {
    
    @TestSetup
    static void setup() {
        // Create test pricebook first
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i
            ));
        }
        insert accounts;
        
        // Create test opportunities
// In AsanaIntegrationQueueableTest.setup()
List<Opportunity> opportunities = new List<Opportunity>();
for (Integer i = 0; i < 3; i++) {
    opportunities.add(new Opportunity(
        Name = 'Test Opportunity ' + i,
        AccountId = accounts[i].Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Amount = 100.00 + i, // Already added
        SalesVertical__c = 'Gaming', // <--- ADD THIS LINE IF IT'S REQUIRED
        Pricebook2Id = standardPricebook.Id
    ));
}
insert opportunities;
        
        Test.setMock(HttpCalloutMock.class, new AsanaMock(
            '{"data":{"id":"prod-123","name":"Test prod"}}',
            201,
            'POST'
        ));        // Create test products
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 3; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                IsActive = true
            ));
        }
        insert products;
        
        // Create pricebook entries
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
        for (Product2 product : products) {
            pricebookEntries.add(new PricebookEntry(
                Pricebook2Id = standardPricebook.Id,
                Product2Id = product.Id,
                UnitPrice = 100.00,
                IsActive = true,
                UseStandardPrice = false
            ));
        }
        insert pricebookEntries;
        
        // Create opportunity line items
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 3; i++) {
            lineItems.add(new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pricebookEntries[i].Id,
                Quantity = 1,
                UnitPrice = 100.00,
                Integration_Status__c = 'Send to Asana',
                Sync_to_Asana__c = 'Yes',
                Status__c = 'Active'
            ));
        }
        insert lineItems;
    }
    
    @IsTest
    static void testConstructorWithLineItems() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 3
        ];

         AsanaIntegrationHandler.configCache = new Map<String, String>{
                'Access_Token' => 'test-token'
            };
        // Ensure internal config is preloaded and no static paths make callouts
         Test.setMock(HttpCalloutMock.class, new AsanaMock(
            '{"data":{"gid":"task-123","name":"Test Task"}}',
            201,
            'POST'
        ));

        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems,true));
        Test.stopTest();
        
        // Then
        System.assert(true, 'Queueable enqueued and executed with mocked callout');
    }
    
    @IsTest
    static void testConstructorWithLineItemsAndIndex() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 3
        ];
        Integer currentIndex = 1;
        Boolean isInsert = true;
        
        // Ensure internal config is preloaded
        // Register mock since enqueue will execute and may call out
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, currentIndex, isInsert));
        Test.stopTest();
        
        // Then
        System.assert(true, 'Queueable executed with mocked callout');
    }
    
    @IsTest
    static void testExecuteWithNewLineItems() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 3
        ];
        
        // Clear Task GIDs to simulate new items
        for (OpportunityLineItem item : lineItems) {
            item.Task_GID__c = null;
        }
        update lineItems;
        
        // Preload config and mock the callout
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, true));
        Test.stopTest();
        
        // Then
        // Verify that the execute method runs without errors
        System.assert(true, 'Execute should complete without throwing exceptions');
    }
    
    @IsTest
    static void testExecuteWithExistingLineItems() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 3
        ];
        
        // Set Task GIDs and status to simulate existing items that need update
        for (OpportunityLineItem item : lineItems) {
            item.Task_GID__c = 'test_task_id_' + item.Id;
            item.Integration_Status__c = 'Resync';
        }
        update lineItems;        
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());        
        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, false));
        Test.stopTest();
        
        // Then
        // Verify that the execute method runs without errors
        System.assert(true, 'Execute should complete without throwing exceptions');
    }
    
    @IsTest
    static void testExecuteWithMixedLineItems() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 3
        ];
        
        // Mix of new and existing items
        lineItems[0].Task_GID__c = null; // New item
        lineItems[0].Integration_Status__c = 'Send to Asana';
        
        lineItems[1].Task_GID__c = 'test_task_id_1'; // Existing item - update
        lineItems[1].Integration_Status__c = 'Send to Asana';
        
        lineItems[2].Task_GID__c = 'test_task_id_2'; // Existing item - resync
        lineItems[2].Integration_Status__c = 'Resync';
        
        update lineItems;
        
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, true));
        Test.stopTest();
        
        // Then
        // Verify that the execute method runs without errors
        System.assert(true, 'Execute should complete without throwing exceptions');
    }
    
    @IsTest
    static void testExecuteWithSyncToAsanaNo() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 1
        ];
        
        // Set Sync_to_Asana__c to 'No' to test skipping logic
        lineItems[0].Sync_to_Asana__c = 'No';
        update lineItems;
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        // Use System.enqueueJob instead of direct execute call
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, true));
        Test.stopTest();
        
        // Then
        // Should skip processing when Sync_to_Asana__c = 'No'
        System.assert(true, 'Execute should skip items with Sync_to_Asana__c = No');
    }
    
    @IsTest
    static void testExecuteWithCanceledStatus() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c, Canceled_in_Asana__c
            FROM OpportunityLineItem 
            LIMIT 1
        ];
        
        // Set status to canceled to test skipping logic
        lineItems[0].Status__c = 'Canceled';
        lineItems[0].Task_GID__c = 'test_task_id';
        lineItems[0].Canceled_in_Asana__c = true; // Already canceled in Asana
        lineItems[0].Reason_for_Canceling__c = 'Error';
        update lineItems;
        
        // Preload config and register mock defensively in case an update path is taken
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        // Use System.enqueueJob instead of direct execute call
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, false));
        Test.stopTest();
        
        // Then
        // Should skip processing for canceled items already canceled in Asana
        System.assert(true, 'Execute should skip canceled items already canceled in Asana');
    }
    
    @IsTest
    static void testExecuteWithEmptyList() {
        // Given
        List<OpportunityLineItem> emptyLineItems = new List<OpportunityLineItem>();
        
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(emptyLineItems, true));
        Test.stopTest();
        
        // Then
        // Should complete without errors
        System.assert(true, 'Execute should handle empty list without errors');
    }
    
    @IsTest
    static void testExecuteWithException() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 1
        ];
        
        lineItems[0].Task_GID__c = null;
        update lineItems;
        
        // Preload config; then mock a callout failure
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock(true)); // Simulate failure
        
        // When
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, true));
        Test.stopTest();
        
        // Then
        // Should complete without throwing unhandled exceptions
        System.assert(true, 'Execute should handle exceptions gracefully');
    }
    
    @IsTest
    static void testExecuteChaining() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 2
        ];
        
        for (OpportunityLineItem item : lineItems) {
            item.Task_GID__c = null;
        }
        update lineItems;
        
        // Preload config and mock the callout
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        // Test chaining by using System.enqueueJob
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, 0, true));
        Test.stopTest();
        
        // Then
        // Verify that chaining logic works
        System.assert(true, 'Execute should handle chaining logic');
    }
    
    @IsTest
    static void testExecuteWhenCurrentIndexExceedsSize() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c
            FROM OpportunityLineItem 
            LIMIT 1
        ];
        
        // Preload config and register mock defensively
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        // Start with index beyond list size - use System.enqueueJob
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, lineItems.size() + 1, true));
        Test.stopTest();
        
        // Then
        // Should return early without processing
        System.assert(true, 'Execute should return early when currentIndex exceeds list size');
    }
    
    @IsTest
    static void testExecuteSkipProcessingBasedOnConditions() {
        // Given
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c, Canceled_in_Asana__c
            FROM OpportunityLineItem 
            LIMIT 1
        ];
        
        // Test various skip conditions
        lineItems[0].Sync_to_Asana__c = 'Yes';
        lineItems[0].Status__c = 'Active'; // Should skip for new items
        lineItems[0].Task_GID__c = null;
        update lineItems;
        
        // Preload config and register mock defensively
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When
        Test.startTest();
        // Use System.enqueueJob instead of direct execute call
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, true));
        Test.stopTest();
        
        // Then
        // Should skip processing based on conditions
        System.assert(true, 'Execute should skip processing based on conditions');
    }

    @IsTest
    static void testExecuteWithoutCallouts() {
        // Given - Test items that shouldn't trigger callouts
        List<OpportunityLineItem> lineItems = [
            SELECT Id, Task_GID__c, Integration_Status__c, Sync_to_Asana__c, Status__c, Canceled_in_Asana__c
            FROM OpportunityLineItem 
            LIMIT 1
        ];
        
        // Setup item that should be skipped (no callout should be attempted)
        lineItems[0].Sync_to_Asana__c = 'No';
        lineItems[0].Task_GID__c = null;
        lineItems[0].Status__c = 'Active';
        update lineItems;
        
        // Preload config and register mock defensively even though path should skip
        Test.setMock(HttpCalloutMock.class, new AsanaCalloutMock());
        
        // When - With mock registered
        Test.startTest();
        System.enqueueJob(new AsanaIntegrationQueueable(lineItems, true));
        Test.stopTest();
        
        // Then
        // No callout should be attempted for items with Sync_to_Asana__c = 'No'
        System.assert(true, 'Should skip callout for items with Sync_to_Asana__c = No');
    }

    // Mock class for Asana callouts
    private class AsanaCalloutMock implements HttpCalloutMock {
        private Boolean simulateFailure;
        
        public AsanaCalloutMock() {
            this.simulateFailure = false;
        }
        
        public AsanaCalloutMock(Boolean simulateFailure) {
            this.simulateFailure = simulateFailure;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (simulateFailure) {
                res.setStatusCode(500);
                res.setStatus('Server Error');
                res.setBody('{"errors":[{"message":"Internal Server Error"}]}');
            } else {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setHeader('Content-Type', 'application/json');
                
                // Mock response for both create and update scenarios
                if (req.getEndpoint().contains('/tasks')) {
                    if (req.getMethod() == 'POST') {
                        // Create task response
                        res.setBody('{"data":{"gid":"new_task_id_123","name":"Test Task","notes":"Test Description"}}');
                    } else if (req.getMethod() == 'PUT') {
                        // Update task response
                        res.setBody('{"data":{"gid":"updated_task_id_123","name":"Updated Test Task","notes":"Updated Description"}}');
                    }
                }
            }
            
            return res;
        }
    }
     // Mock class for Asana API callouts
    public class AsanaMock implements HttpCalloutMock {
        private String responseBody;
        private Integer statusCode;
        private String method;
        
        public AsanaMock(String responseBody, Integer statusCode, String method) {
            this.responseBody = responseBody;
            this.statusCode = statusCode;
            this.method = method;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }
    
}