//**********************		
// Deployment Date: 27 Mar 2026		
// Created by: Dotsolved Development team		
// Jira Ticket # : SF-236
// Description: To sync with Asana from OLI	
// Last Modified Date: 19 Mar 2026		
//***********************
public without sharing class OLIHistoryQueueable implements Queueable {

    private List<Opportunity_Product_History__c> historyRecords;

    public OLIHistoryQueueable(List<Opportunity_Product_History__c> historyRecords){
        this.historyRecords = historyRecords;
    }

    // queueable class to insert history records that are prepared and sent from OLIHistoryService Class
    public void execute(QueueableContext context){
        id integrationUserId = System.label.Hubspot_Integration_User_ID;
        if(historyRecords != null && !historyRecords.isEmpty()){
            for(Opportunity_Product_History__c rec : historyRecords){
                rec.OwnerId = integrationUserId; // setting ownerId as integration user
            }
            system.debug('inserting '+historyRecords.size()+' records');
            insert historyRecords;
        }
    }
}