//**********************	
// Created/Deployment Date: 28th July 2025	
// Created by: Dotsolved Development team	
// Jira Ticket # : 212,223, SF-308
// Description: processing leads	
// Last Modified Date: 07th May 2026
//***********************	
trigger triggerOnLead on Lead (before insert, before update, after update) {	
	Trigger_Settings_Hierarchy__c setting = Trigger_Settings_Hierarchy__c.getInstance();
    	
    if (setting != null && !setting.Skip_Process__c) {	
        if (Trigger.isBefore ) {	
            if (Trigger.isInsert) {	
                LeadBeforeTriggerHandler.processBeforeInsertLeads(Trigger.New);	
            }else if(Trigger.isUpdate){
                LeadBeforeTriggerHandler.processBeforeUpdateLeads(Trigger.New, Trigger.OldMap); 
            }
        }/*else if (Trigger.isAfter){
            for(Lead l: Trigger.New){
                System.debug('After Trigger');
                System.debug('Lead Country ==> '+l.Country +', lead.Region__c ==> '+l.Region__c);
            }
        }*/
    }	
}