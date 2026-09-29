//**********************		
// Created/Deployment Date: 6th Oct 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 290,283,276,375,287,387	
// Description: To sync with Asana from OLI		
// Last Modified Date: 7th Nov 2025
// Reason for Commenting: We are handling the ASANA Integration in OLI itself	
//***********************	
trigger OpportunityTrigger on Opportunity (before Update, after update) { 
   /* Set<Id> oppIds = new Set<Id>();
    Set<Id> fieldChangedOppIds = new Set<Id>();
    
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        
        // Stage changes (existing logic)
        if ((oldOpp.StageName != opp.StageName 
             && (opp.StageName == 'P1: Prospecting' || opp.StageName == 'P2: Contact' || opp.StageName == 'P3: Proposal/RFP' || opp.StageName == 'P4: Verbal Agreement'
             || opp.StageName == 'P5: Signed/Won' || opp.StageName == 'Campaign Completed' || opp.StageName == 'Closed Lost'))) {
            oppIds.add(opp.Id);
        }
        
        // NEW: Detect field changes that should propagate to all line items
        if (oldOpp.Amount != opp.Amount ||
            oldOpp.Account_Manager__c != opp.Account_Manager__c ||
            oldOpp.OwnerId != opp.OwnerId ||
            oldOpp.Name != opp.Name) {
            
            fieldChangedOppIds.add(opp.Id);
            
            System.debug('Field changes detected for Opportunity: ' + opp.Id + 
                        ' | Amount: ' + (oldOpp.Amount != opp.Amount) +
                        ' | Account Manager: ' + (oldOpp.Account_Manager__c != opp.Account_Manager__c) +
                        ' | Owner: ' + (oldOpp.OwnerId != opp.OwnerId) +
                        ' | Name: ' + (oldOpp.Name != opp.Name));
        }
    }
    
    // Process stage updates (existing)
    if (!oppIds.isEmpty()) {
        System.debug('Processing stage updates for Opp IDs: ' + oppIds);
        AsanaIntegrationHandler.updateTaskStageFuture(oppIds);
    }
    
    // Process field updates (enhanced)
    if (!fieldChangedOppIds.isEmpty()) {
        System.debug('Processing field updates for Opp IDs: ' + fieldChangedOppIds);
        AsanaIntegrationHandler.updateTaskFieldsFuture(fieldChangedOppIds);
    }*/
}