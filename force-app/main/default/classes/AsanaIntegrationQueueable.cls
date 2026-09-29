//**********************
// Created/Deployment Date: 6th Oct 2025
// Created by: Dotsolved Development team
// Jira Ticket # : 290,283,276,375,287,387
// Description: To sync with Asana from OLI
// Last Modified Date: 29th Oct 2025 (fixed duplicate creation issue)
//***********************
public class AsanaIntegrationQueueable implements Queueable, Database.AllowsCallouts {

    private List<OpportunityLineItem> lineItems;
    private Integer currentIndex;
    private Boolean isInsert = false;

    // Constructor for initial call
    public AsanaIntegrationQueueable(List<OpportunityLineItem> lineItems, Boolean isInsert) { 
        this.lineItems = lineItems;
        this.currentIndex = 0;
        this.isInsert = isInsert;
    }

    // Constructor for chained calls
    public AsanaIntegrationQueueable(List<OpportunityLineItem> lineItems, Integer currentIndex, Boolean isInsert) {
        this.lineItems = lineItems;
        this.currentIndex = currentIndex;
        this.isInsert = isInsert;
    }

    public void execute(QueueableContext context) {
        if (currentIndex >= lineItems.size()) return;

        OpportunityLineItem lineItem = lineItems[currentIndex];

        try {
            // Only process if Sync_to_Asana__c = 'Yes'
            if (lineItem.Sync_to_Asana__c == 'Yes') {
                // ----- FIRST-TIME CREATION -----
                if (String.isBlank(lineItem.Task_GID__c)                    
                    && lineItem.Status__c == 'Active') {
                    System.debug('Creating Asana Task for OLI: ' + lineItem.Id);
                    AsanaIntegrationHandler.createAsanaTask(lineItem);

                // ----- UPDATE / RESYNC -----
                } else if (!String.isBlank(lineItem.Task_GID__c)
                           && (lineItem.Integration_Status__c == 'Send to Asana' || lineItem.Integration_Status__c == 'Resync')
                           && (lineItem.Status__c == 'Active' || (lineItem.Status__c == 'Canceled' && lineItem.Canceled_in_Asana__c == FALSE))) {
                    System.debug('Updating Asana Task for OLI: ' + lineItem.Id);
                    AsanaIntegrationHandler.updateAsanaTask(lineItem);
                }

            } else {
                System.debug('Skipping Asana integration for OLI: ' + lineItem.Id);
            }

        } catch (Exception e) {
            System.debug('Error processing OLI ' + lineItem.Id + ': ' + e.getMessage());
        }

        // Chain next queueable job if more items remain
        currentIndex++;
        if (currentIndex < lineItems.size() && !Test.isRunningTest()) {
            System.enqueueJob(new AsanaIntegrationQueueable(lineItems, currentIndex, isInsert));
        }
    }
}