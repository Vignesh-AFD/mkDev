//**********************		
// Created/Deployment Date: 6th Oct 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 290,283,276,375,287,387, 588, SF-214, SF-236, SF-174, SF-279
// Description: To sync with Asana from OLI	
// Last Modified Date: 20 Apr 2026		
//***********************	
public class OpportunityLineItemTriggerHelper {
    public static void recalculateOppStartDate(List<OpportunityLineItem> newList){
        Set<Id> oppIds = new Set<Id>();

        // Insert / Update
        if (newList != null) {
            for (OpportunityLineItem oli : newList) {
                system.debug('Opp_RecordType__c  ==> '+oli.Opp_RecordType__c);
                if(oli.Opp_RecordType__c  == 'Ad Sales'){
                	oppIds.add(oli.OpportunityId);   
                }
            }
        }

        if (oppIds.isEmpty()) return;

        // Aggregate query to find earliest start date per Opportunity
        List<AggregateResult> results = [
            SELECT OpportunityId oppId, MIN(Start_Date__c) minDate
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds AND Status__c = 'Active' 
            GROUP BY OpportunityId
        ];

        Map<Id, Date> oppToMinDate = new Map<Id, Date>();
        for (AggregateResult ar : results) {
            oppToMinDate.put((Id) ar.get('oppId'), (Date) ar.get('minDate'));
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for(Opportunity o: [Select id, LaunchDate__c from Opportunity where id in: oppIds]){
            if(o.LaunchDate__c <> oppToMinDate.get(o.Id)){
                o.LaunchDate__c = oppToMinDate.get(o.Id);
                oppsToUpdate.add(o);
            }
        }
		system.debug('oppsToUpdate size is '+oppsToUpdate.size());
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
    public static void handleAfterUpdate(List<OpportunityLineItem> OLIs, Map<Id, OpportunityLineItem> oldOLIMap){
        // Recalculate the earliest OLI start date to Launch Date in Opportunity
        OpportunityLineItemTriggerHelper.recalculateOppStartDate(OLIs);
        
        // MK - 15Mar2026 - create OLIs history records if any
        OLIHistoryService.createOLIHistories(OLIs, oldOLIMap);
        
        // Process further for Asana sync
        if(OLIs.size() == 0) return;
        List<OpportunityLineItem> updateRecords = new List<OpportunityLineItem>();
        for (OpportunityLineItem oli : OLIs) {
            OpportunityLineItem oldRec = oldOLIMap.get(oli.Id);
            
            // FIX: Check if this is a retry scenario (blank Task_GID) OR update scenario
            if (oli.Integration_Status__c != oldRec.Integration_Status__c  
                && (oli.Integration_Status__c == 'Send to Asana' || oli.Integration_Status__c == 'Resync') 
                && oli.Sync_to_Asana__c == 'Yes'
                && (oli.Status__c == 'Active' || (oli.Status__c == 'Canceled' && oli.Canceled_in_Asana__c == FALSE))) {
                    updateRecords.add(oli);
                    System.debug('Processing for retry/update - Task_GID: ' + oli.Task_GID__c + ', Status: ' + oli.Integration_Status__c);
                }
        }
        
        if (!updateRecords.isEmpty()) {
            System.debug('Queueing records for processing: ' + updateRecords.size());
            System.enqueueJob(new AsanaIntegrationQueueable(updateRecords, false));
        }
    }
    
    public static void handleBeforeInsert(List<OpportunityLineItem> OLIs){
        System.debug('Inside handleBeforeInsert');
        if(OLIs.size() == 0) return; // return if OLIs size is 0
        
        // MK - 06Apr2026: Clean multi-picklist 'none' values
    	cleanMultiPicklistNoneValues(OLIs);
        
        // get OppIds in a set
        Map<Id, Decimal> oppOLICountMap = new Map<Id, Decimal>();
        Set<Id> OppIds = New Set<Id>();
        for(OpportunityLineItem oli : OLIs){
            OppIds.add(oli.OpportunityId);
        }
        
        // get oppOLICountMap (Key --> OppID, Value --> OLI size)
        List<Opportunity> oppList = [Select id, name, (Select id from OpportunityLineItems) from Opportunity where id in: OppIds];
        for(Opportunity opp: oppList){	
            oppOLICountMap.put(opp.Id, opp.OpportunityLineItems.size());
        }
        system.debug('oppOLICountMap ==> '+oppOLICountMap);
        
        for(OpportunityLineItem oli : OLIs){
            Decimal currentCount = oppOLICountMap.containsKey(oli.OpportunityId) ? oppOLICountMap.get(oli.OpportunityId) : 0;
            Decimal nextCount = currentCount + 1;
            
            // MK - 20Apr2026: track history if OLI is inserted after P4 stage
            if(OLIHistoryService.checkIfStageIsP5OrCC(oli.Opp_RecordType__c, oli.Deal_Stage__c)){ 
                oli.Has_Modifications_after_P4__c = true;
            }
            
            // Generate Task/Campaign Name
            oli.Task_Campaign_Name__c = oli.Opportunity_Name__c + ' - ' + oli.Product_Name__c  + ' ' + String.valueOf(nextCount);
            oppOLICountMap.put(oli.OpportunityId, nextCount);
            
            // set Sync to Asana to NO if Dev Sol recordtype
            if(oli.Opportunity.RecordTypeId == System.Label.Opp_RecordTypeID_Dev_Sol_Ops && oli.Sync_to_Asana__c <> 'No'){
                oli.Sync_to_Asana__c = 'No';
            }
            
            // Setting the Sales price and Actual sales price 
            decimal givenSalesPrice = oli.UnitPrice;
            decimal curQuantity = oli.Quantity;
            decimal curTotalPrice = givenSalesPrice * curQuantity;
            oli.Actual_Sales_Price__c = givenSalesPrice;
            
            decimal derivedSalesPrice = oli.Rate_Type__c == 'CPM' ? givenSalesPrice/1000 : givenSalesPrice; 
            if(oli.UnitPrice <> derivedSalesPrice) oli.UnitPrice = derivedSalesPrice;
            
            // check if total price has decimals
            decimal derivedTotalPrice = derivedSalesPrice * curQuantity;
            system.debug('derivedTotalPrice ==> '+derivedTotalPrice);
            if(Math.floor((Double)derivedTotalPrice) <> (Double)derivedTotalPrice){
                decimal roundedTotalPrice = derivedTotalPrice.setScale(0, RoundingMode.HALF_UP);
                decimal roundedSalesPrice = roundedTotalPrice/curQuantity;
                
                system.debug('roundedTotalPrice ==> '+roundedTotalPrice);
                system.debug('roundedSalesPrice ==> '+roundedSalesPrice);
                
                // set rounded sales price and actual sales price
                oli.UnitPrice = roundedSalesPrice;
                oli.Actual_Sales_Price__c = oli.Rate_Type__c == 'CPM' ? roundedSalesPrice * 1000 : roundedSalesPrice;
            }
        }
    }
    
    public static void handleBeforeUpdate(List<OpportunityLineItem> OLIs, Map<Id, OpportunityLineItem> oldOLIMap){
        System.debug('Inside handleBeforeUpdate');
        
        // MK - 06Apr2026: Clean multi-picklist 'none' values
    	cleanMultiPicklistNoneValues(OLIs);
        
        List<Asana_Field_Mapping__mdt > fieldsToCheck = [
            SELECT Salesforce_Field_API__c, Data_Type__c FROM Asana_Field_Mapping__mdt 
            WHERE IsActive__c = true AND Salesforce_Object__c = 'OpportunityLineItem'
        ];
        
		for(OpportunityLineItem oli : OLIs){
            OpportunityLineItem oldOLI = oldOLIMap.get(oli.Id);
            // set Sync to Asana to NO if Dev Sol recordtype
            if(oli.Opportunity.RecordTypeId == System.Label.Opp_RecordTypeID_Dev_Sol_Ops && oli.Sync_to_Asana__c <> 'No'){
                oli.Sync_to_Asana__c = 'No';
            }
            
            // MK - 15Mar26 - track if there is field update after P4 stage
            if(!oli.Has_Modifications_after_P4__c && OLIHistoryService.oliFieldUpdateDetectedAfterP4(oli, oldOLI)){
                oli.Has_Modifications_after_P4__c = true;
            }
            
            // Set Integration Status to 'Send to Asana' when relavent field value changed dynamically
            if((hasRelevantFieldChanged(oli, oldOLI,fieldsToCheck) 
                || oli.Status__c <> oldOLI.Status__c 
                || oli.Sync_to_Asana__c <> oldOLI.Sync_to_Asana__c) 
               && oli.Sync_to_Asana__c == 'Yes' 
               && oli.Canceled_in_Asana__c == false){
                oli.Integration_Status__c = 'Send to Asana';
                oli.Retry_Attempts__c = 0;
            }
            // Set Retry_Attempts__c to 0 when integration status is manually changed
            else if(oli.Integration_Status__c <> oldOLI.Integration_Status__c 
                     && oli.Integration_Status__c == 'Send to Asana'){
                oli.Retry_Attempts__c = 0;
            }
            
            // Update sales price and actual sales price
            decimal givenSalesPrice = Oli.UnitPrice;
            decimal actualSalesPrice = oli.Actual_Sales_Price__c;
            system.debug('givenSalesPrice, actualSalesPrice ==> '+givenSalesPrice+', '+actualSalesPrice);
            
            if(oli.UnitPrice <> oldOLI.UnitPrice){
                oli.Actual_Sales_Price__c = Oli.UnitPrice;
                oli.UnitPrice = oli.Rate_Type__c == 'CPM' ? givenSalesPrice/1000 : givenSalesPrice;
            }
            system.debug('oli.Actual_Sales_Price__c ==> '+oli.Actual_Sales_Price__c);
            system.debug('oli.UnitPrice ==> '+oli.UnitPrice);
            
            // Update sales price if rate type changed
            if(oli.Rate_Type__c <> oldOLI.Rate_Type__c){
                oli.UnitPrice = oli.Rate_Type__c == 'CPM' ? actualSalesPrice/1000 : actualSalesPrice;
            }
            system.debug('oli.UnitPrice ==> '+oli.UnitPrice);
            
            // check if total price has decimals
            decimal derivedTotalPrice = oli.UnitPrice * oli.Quantity;
            system.debug('derivedTotalPrice ==> '+derivedTotalPrice);
            if(Math.floor((Double)derivedTotalPrice) <> (Double)derivedTotalPrice){
                decimal roundedTotalPrice = derivedTotalPrice.setScale(0, RoundingMode.HALF_UP);
                decimal roundedSalesPrice = roundedTotalPrice/oli.Quantity;
                
                system.debug('roundedTotalPrice ==> '+roundedTotalPrice);
                system.debug('roundedSalesPrice ==> '+roundedSalesPrice);
                
                // Set rounded sales price and actual sales price
                oli.UnitPrice = roundedSalesPrice;
                oli.Actual_Sales_Price__c = oli.Rate_Type__c == 'CPM' ? roundedSalesPrice * 1000 : roundedSalesPrice;
            }
            system.debug('oli.Actual_Sales_Price__c ==> '+oli.Actual_Sales_Price__c);
            system.debug('oli.UnitPrice ==> '+oli.UnitPrice);
            
            // Check if the status is changed to canceled
            decimal actualSalesPrice2 = oli.Actual_Sales_Price__c;
            if(oli.Status__c <> oldOLI.Status__c && oli.Status__c == 'Canceled'){
                oli.Canceled_Sales_Price__c = actualSalesPrice2;
                oli.UnitPrice = 0;
                oli.Actual_Sales_Price__c = 0;
            }else if(oli.Status__c == 'Canceled' && oli.UnitPrice <> 0){
                oli.UnitPrice = 0;
                oli.Actual_Sales_Price__c =0;
            }
            
            // check if the Status is Active and Canceled in Asana is TRUE, set FALSE
            if(oli.Status__c == 'Active' && oli.Canceled_in_Asana__c == true){
                oli.Canceled_in_Asana__c = false;
            }
        }
    }
    
    // helper method to check whether relavent field value(s) changed to sync the OLI
    public static Boolean hasRelevantFieldChanged(OpportunityLineItem newRec, OpportunityLineItem oldrec, List<Asana_Field_Mapping__mdt > fieldsToCheck){
        Boolean result = false;
        for (Asana_Field_Mapping__mdt f : fieldsToCheck) {
            String apiName = f.Salesforce_Field_API__c;
            Object newVal = newRec.get(apiName);
            Object oldVal = oldRec.get(apiName);
            
            if (newVal != oldVal) {
                result = true;
                break;
            }
        }
        return result;
    }
    
    // Removes 'none' from multi-picklist fields (only if multiple values exist)
    private static void cleanMultiPicklistNoneValues(List<OpportunityLineItem> OLIs) {
        
        List<Asana_Field_Mapping__mdt> multiPicklistfieldsToCheck = [
            SELECT Salesforce_Field_API__c 
            FROM Asana_Field_Mapping__mdt 
            WHERE IsActive__c = true 
            AND Salesforce_Object__c = 'OpportunityLineItem' 
            AND Data_Type__c = 'MultiPicklist'
        ];
        
        if (multiPicklistfieldsToCheck.isEmpty()) return;
        
        for (OpportunityLineItem oli : OLIs) {
            for (Asana_Field_Mapping__mdt fieldMeta : multiPicklistfieldsToCheck) {
                
                String fieldAPI = fieldMeta.Salesforce_Field_API__c;
                String fieldValue = (String) oli.get(fieldAPI);
                
                if (String.isBlank(fieldValue)) continue;
                
                List<String> values = fieldValue.split(';');
                
                // Ignore if only one value
                if (values.size() <= 1) continue;
                
                List<String> filteredValues = new List<String>();
                
                for (String val : values) {
                    if (val != null && val.trim().toLowerCase() != 'none') {
                        filteredValues.add(val.trim());
                    }
                }
                
                // Update only if 'none' was removed
                if (filteredValues.size() != values.size()) {
                    oli.put(fieldAPI, String.join(filteredValues, ';'));
                }
            }
        }
    }
}