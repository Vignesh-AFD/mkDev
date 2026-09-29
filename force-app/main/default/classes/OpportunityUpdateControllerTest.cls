@IsTest
private class OpportunityUpdateControllerTest {
 
    @TestSetup
    static void setupData() {

        Account advertiser = new Account(
            Name = 'Advertiser Account',
            Registered_Legal_Name__c = 'Advertiser Legal',
            BillingCountryCode = 'US'
        );
        insert advertiser;

        Account agency = new Account(
            Name = 'Agency Account',
            Registered_Legal_Name__c = 'Agency Legal'
        );
        insert agency;

        Contact billingContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            AccountId = advertiser.Id,
            MailingStreet = '123 Main St',
            MailingCity = 'New York',
            MailingStateCode = 'NY',
            MailingCountryCode = 'US',
            MailingPostalCode = '10001'
        );
        insert billingContact; 

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = advertiser.Id,
            Billing_Contact__c = billingContact.Id,
            PO_Number__c = 'PO-123',
            Lexion_Contract_URL__c = 'https://test.com'
        );

        insert opp;
    }

    @IsTest
    static void testGetData() {

        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        Test.startTest();

        OpportunityUpdateController.WrapperData result =
            OpportunityUpdateController.getData(
                opp.Id
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            opp.Id,
            result.opportunity.Id
        );

        System.assertNotEquals(
            null,
            result.account
        );

    }

    @IsTest
    static void testCreateBillingContact() {

        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Contact con = new Contact(
            FirstName = 'New',
            LastName = 'Contact',
            Email = 'new@test.com',
            AccountId = acc.Id,
            MailingCountryCode = 'US',
            MailingStateCode = 'NY'
        );

        Test.startTest();

        Id contactId =
            OpportunityUpdateController.createBillingContact(
                opp.Id,
                con
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            contactId
        );

        Opportunity updatedOpp = [
            SELECT Billing_Contact__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals(
            contactId,
            updatedOpp.Billing_Contact__c
        );
    }

    @IsTest
    static void testUpdateRecords() {

        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        Account advertiser = [
            SELECT Id
            FROM Account
            WHERE Name = 'Advertiser Account'
            LIMIT 1
        ];

        Account agency = [
            SELECT Id
            FROM Account
            WHERE Name = 'Agency Account'
            LIMIT 1
        ];

        Contact billingContact = [
            SELECT Id
            FROM Contact
            LIMIT 1
        ];

        Opportunity oppUpdate =
            new Opportunity(
                Id = opp.Id,
                PO_Number__c = 'PO-999' 
            );

        Account accountUpdate =
            new Account(
                Id = advertiser.Id,
                Registered_Legal_Name__c =
                    'Updated Advertiser'
            );

        Account agencyUpdate =
            new Account(
                Id = agency.Id,
                Registered_Legal_Name__c =
                    'Updated Agency'
            );


        Contact contactUpdate =
            new Contact(
                Id = billingContact.Id,
                FirstName = 'Updated'
            );

        Test.startTest();

        OpportunityUpdateController.updateRecords(
            oppUpdate,
            accountUpdate,
            agencyUpdate,
            null,
            contactUpdate
        );

        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT PO_Number__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        Contact updatedContact = [
            SELECT FirstName
            FROM Contact
            WHERE Id = :billingContact.Id
        ];

        System.assertEquals(
            'PO-999',
            updatedOpp.PO_Number__c
        );

        System.assertEquals(
            'Updated',
            updatedContact.FirstName
        );
    }
 
    @IsTest
    static void testGetDataWithInvalidId() {
        Test.startTest();
        try {
            OpportunityUpdateController.getData(null);
            System.assert(false);
        } catch (AuraHandledException ex) {}

        Test.stopTest();
    }
}