//**********************		
// Created/Deployment Date: 6th Oct 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 290,283,276,375,287,387, 588, SF-214, SF-279
// Description: To sync with Asana from OLI		
// Last Modified Date: 20Apr2026		
//***********************	
trigger OpportunityLineItemTrigger on OpportunityLineItem (before insert, before update, after insert, after update) {
    // MK - 8 Jan 2026 - Added custom setting logic to switch on/off OLI process
    Trigger_Settings_Hierarchy__c setting = Trigger_Settings_Hierarchy__c.getInstance();
    
    if (setting != null && !setting.Skip_OLI_Process__c ) {
        if (Trigger.isBefore && Trigger.isInsert) {
            
            // handle before insert context
            OpportunityLineItemTriggerHelper.handleBeforeInsert(Trigger.New);
            
        }else if (Trigger.isBefore && Trigger.isUpdate) {
            
            // handle before insert context
            OpportunityLineItemTriggerHelper.handleBeforeUpdate(Trigger.New, Trigger.oldMap);
            
        }else if (Trigger.isAfter && Trigger.isInsert) {
            
            // MK - 20 Apr 2026 - create OLIs history records on create at Opp stage P5/Campaign Completed
        	OLIHistoryService.CreateOLIHistoriesOnCreate(Trigger.New);
            
            // MK - 19 Feb 2026 - handle recalculate the earliest Start date from OLI to Launch date in Opp
            OpportunityLineItemTriggerHelper.recalculateOppStartDate(Trigger.new);
            
            // handle Asana syncing after insert
            System.enqueueJob(new AsanaIntegrationQueueable(Trigger.new, true));
            
        }else if (Trigger.isAfter && Trigger.isUpdate) {
            
            // handle after update context
            OpportunityLineItemTriggerHelper.handleAfterUpdate(Trigger.New, Trigger.oldMap);
            
        }
    }
}