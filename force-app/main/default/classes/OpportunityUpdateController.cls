public with sharing class OpportunityUpdateController {

    @AuraEnabled(cacheable=true)
    public static WrapperData getData(String opportunityId) { 

        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException(
                'Opportunity Id is required.'
            );
        }
 
        List<Opportunity> opportunities = [

            SELECT
                Id,
                PO_Number__c,
                Lexion_Contract_URL__c,
                StageName,
                Is_P5_Mandate_Pending__c,

                (
                SELECT Id
                FROM OpportunityLineItems
                LIMIT 1 
                ),

                Billing_Contact__c,
                Billing_Contact__r.Id,
                Billing_Contact__r.AccountId,
                Billing_Contact__r.FirstName,
                Billing_Contact__r.LastName,
                Billing_Contact__r.Email,
                Billing_Contact__r.MailingStreet,
                Billing_Contact__r.MailingCity,
                Billing_Contact__r.MailingState,
                Billing_Contact__r.MailingStateCode,
                Billing_Contact__r.MailingCountry,
                Billing_Contact__r.MailingCountryCode,
                Billing_Contact__r.MailingPostalCode,
                Billing_Contact__r.Invoice_CC_Emails__c,
                Billing_Contact__r.Invoice_Delivery_Method__c,
                Billing_Contact__r.Account.Tax_Identifier__c,
 
                Related_Account__c,
                Related_Account__r.Id,
                Related_Account__r.Tax_Identifier__c,
                Related_Account__r.Registered_Legal_Name__c, 
                Related_Account__r.BillingCountry,
                Related_Account__r.BillingCountryCode,

                AccountId, 
                Account.Id,
                Account.Tax_Identifier__c, 
                Account.Registered_Legal_Name__c, 
                Account.BillingCountryCode,
                Account.BillingCountry

            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opportunities.isEmpty()) {
            throw new AuraHandledException(
                'No Opportunity found for Id: ' + opportunityId
            );
        }

        Opportunity opp = opportunities[0];

        Boolean hasActiveOpportunityLineItem = false;

        for (OpportunityLineItem oli : opp.OpportunityLineItems) {
            if (oli.Status__c == 'Active') {
                hasActiveOpportunityLineItem = true;
                break;
            }
        }
        //Boolean hasOpportunityLineItems = opp.OpportunityLineItems != null && !opp.OpportunityLineItems.isEmpty();

        return new WrapperData(
            opp,
            opp.Related_Account__r,
            opp.Account,
            opp.Billing_Contact__r,
            hasActiveOpportunityLineItem
        );
    }
 
    @AuraEnabled
    public static Id createBillingContact(
        Id opportunityId,
        Contact contactData
    ) {
        System.debug('contactData:'+contactData);
        insert contactData;

        Opportunity opp = new Opportunity(
            Id = opportunityId,
            Billing_Contact__c = contactData.Id
        );
        System.debug('opp Data:'+opp);
        update opp;

        return contactData.Id;
    }

    @AuraEnabled
    public static void updateRecords(
        Opportunity oppData,
        Account accountData,
        Account agencyData,
        Account billingAccountData,
        Contact billingContactData
    ) {
        List<SObject> recordsToUpdate = new List<SObject>();

        if (oppData != null) {
            recordsToUpdate.add(oppData);
        }

        if (accountData != null) {
            recordsToUpdate.add(accountData);
        }

        if (agencyData != null) {
            recordsToUpdate.add(agencyData);
        }

        if (billingAccountData != null) {
            recordsToUpdate.add(billingAccountData);
        }

        if (billingContactData != null) {
            recordsToUpdate.add(billingContactData);
        }

        system.debug('recordsToUpdate:'+recordsToUpdate);

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }

    public class WrapperData {
        @AuraEnabled
        public Opportunity opportunity;

        @AuraEnabled
        public Account agency;

        @AuraEnabled
        public Account account;

        @AuraEnabled
        public Contact billingContact;

        @AuraEnabled
        public Boolean hasOpportunityLineItems;

        public WrapperData(
            Opportunity opportunity,
            Account agency,
            Account account,
            Contact billingContact,
            Boolean hasOpportunityLineItems
        ) {
            this.opportunity = opportunity;
            this.agency = agency;
            this.account = account;
            this.billingContact = billingContact;
            this.hasOpportunityLineItems = hasOpportunityLineItems;
        }
    }
}