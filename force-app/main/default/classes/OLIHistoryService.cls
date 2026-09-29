//**********************		
// Deployment Date: 27 Mar 2026		
// Created by: Dotsolved Development team		
// Jira Ticket # : SF-236, SF-279
// Description: To sync with Asana from OLI	
// Last Modified Date: 20 Apr 2026		
//***********************
public with sharing class OLIHistoryService {
    public static Boolean oliFieldUpdateDetectedAfterP4(OpportunityLineItem newOLI, OpportunityLineItem oldOLI){
        Boolean result = false;
        
        // set collection for the tracking fields
        Set<String> fieldsToTrack = getOLIFieldsToTrack('Update');
		if(fieldsToTrack.isEmpty()) return result;
        
        if(checkIfStageIsP5OrCC(newOLI.Opp_RecordType__c, newOLI.Deal_Stage__c)){
            for(String fieldApi : fieldsToTrack){
                Object oldVal = oldOLI.get(fieldApi);
                Object newVal = newOLI.get(fieldApi);
                
                if(oldVal != newVal){
                    result = true;
                }
            }
        }
        return result;
    }
    
    public static Boolean checkIfStageIsP5OrCC(String recordTypeName, String oppDealStage){
        Boolean result = false;
        if(recordTypeName <> System.Label.OLI_History_Tracking_Opp_RecordTypes){
            return result;
        }
        List<String> allowedOppStagesList = System.Label.OLI_History_Tracking_Opp_Stages.split(',');
        for(String stage: allowedOppStagesList){
            if(oppDealStage == stage){
                result = true;
                break;
            }
        }
        system.debug('result is '+result);
        return result;
    }
    
    public static Set<String> getOLIFieldsToTrack(String InsertOrUpdate){
        Set<String> result = new Set<String>();
        
        Map<String, Asana_Field_Mapping__mdt> metadataMap = Asana_Field_Mapping__mdt.getAll(); // get all metadata records
        
        for(Asana_Field_Mapping__mdt mdt : metadataMap.values()){
            if(InsertOrUpdate == 'Insert'){
                if(mdt.Salesforce_Object__c == 'OpportunityLineItem' && mdt.Track_History_On_Create__c){
                    result.add(mdt.Salesforce_Field_API__c);
                }
            }else if(InsertOrUpdate == 'Update'){
                if(mdt.Salesforce_Object__c == 'OpportunityLineItem' && mdt.Track_History__c){
                    result.add(mdt.Salesforce_Field_API__c);
                }
            }
        }
        system.debug('result is '+result);
        return result;
    }
    
    private static String formatValue(Object obj, Schema.DisplayType fieldType){
        if (obj == null) return null;
        if (obj instanceof Date) return formatDate(String.valueOf(obj));
        if (obj instanceof Datetime) return formatDatetime((Datetime)obj);
        if (obj instanceof Boolean) return ((Boolean)obj) ? 'true' : 'false';
        if (obj instanceof Decimal){
            if (fieldType == Schema.DisplayType.Currency) return formatCurrencyFullPrecision((Decimal)obj);
            else return String.valueOf(obj);
        }
        return String.valueOf(obj);
    }
    private static String formatDatetime(Datetime dt){
        system.debug('dt.format(\'yyyy-MM-dd HH:mm:ss\') ==> '+dt.format('yyyy-MM-dd HH:mm:ss'));
        return dt.format('yyyy-MM-dd HH:mm:ss');
    }
    private static String formatDate(String d){
        //system.debug('d.substring(0,10) ==> '+d.substring(0,10));
        return d.substring(0,10);
    }
    private static String formatCurrencyFullPrecision(Decimal value) {
        if (value == null) return null;
        
        String strVal = String.valueOf(value);
        
        // Split integer and decimal parts
        List<String> parts = strVal.split('\\.');
        String intPart = parts[0];
        String decPart = (parts.size() > 1) ? parts[1] : null;
        
        // Add commas to integer part
        String formattedInt = '';
        Integer count = 0;
        
        for (Integer i = intPart.length() - 1; i >= 0; i--) {
            formattedInt = intPart.substring(i, i+1) + formattedInt;
            count++;
            if (count == 3 && i > 0) {
                formattedInt = ',' + formattedInt;
                count = 0;
            }
        }
        
        // Reconstruct number
        if (decPart != null) {
            return '$' + formattedInt + '.' + decPart;
        } else {
            return '$' + formattedInt;
        }
    }

    public static void createOLIHistories(List<OpportunityLineItem> newList, Map<Id,OpportunityLineItem> oldMap){
        system.debug('inside createOLIHistories method');
		// return if the incoming OLI list is empty
        if(newList.isEmpty()) return;

        // set collection for the tracking fields
        Set<String> fieldsToTrack = getOLIFieldsToTrack('Update');
		if(fieldsToTrack.isEmpty()) return;
        
        Set<Id> oppIds = new Set<Id>(); // set collection to store related Opp Ids
        // store Opp Ids
        for(OpportunityLineItem oli : newList){
            oppIds.add(oli.OpportunityId);
        }

        // map collection to store Ad Sales opportunities
        Map<Id,Opportunity> oppMap = new Map<Id,Opportunity>(
            [SELECT Id, StageName FROM Opportunity
             WHERE Id IN :oppIds]
        );

        List<Opportunity_Product_History__c> historyRecords = new List<Opportunity_Product_History__c>(); //list to store to be created history records
        
        system.debug('entering for loop');
        for(OpportunityLineItem newOLI : newList){
            OpportunityLineItem oldOLI = oldMap.get(newOLI.Id); 
            Opportunity opp = oppMap.get(newOLI.OpportunityId);

            if(opp == null) continue; // continue processing next record if current OLI's Opp is null

            //system.debug('checkIfStageIsP5OrCC method returns ==> '+checkIfStageIsP5OrCC(newOLI.Opp_RecordType__c, newOLI.Deal_Stage__c));
            if(checkIfStageIsP5OrCC(newOLI.Opp_RecordType__c, newOLI.Deal_Stage__c)){
                for(String fieldApi : fieldsToTrack){
                    Object oldVal = oldOLI.get(fieldApi);
                    Object newVal = newOLI.get(fieldApi);
                    
                    if(oldVal != newVal){
                        system.debug('change detected on '+fieldApi);
                        Schema.SObjectField fieldToken = OpportunityLineItem.SObjectType.getDescribe().fields.getMap().get(fieldApi);
                        String fieldLabel = fieldToken.getDescribe().getLabel();
						Schema.DisplayType fieldType = fieldToken.getDescribe().getType();	
                        
                        // prepare history record for each trackable field value change
                        Opportunity_Product_History__c history = New Opportunity_Product_History__c();
                        history.Field_Label__c = fieldLabel;
                        history.Field_API_Name__c = fieldApi;
                        history.Opportunity_Product__c = newOLI.Id;
                        history.Old_Value__c = formatValue(oldVal, fieldType);
                        history.New_Value__c = formatValue(newVal, fieldType);
                        history.Modified_By__c = UserInfo.getUserId();
                        history.Modified_Date__c = System.now();
                        history.Deal_Stage__c = newOLI.Deal_Stage__c;
                        
                        historyRecords.add(history);
                    }
                }
            }
        }

        // call queueable class to insert history records
        if(!historyRecords.isEmpty()){
            System.enqueueJob(
                new OLIHistoryQueueable(historyRecords)
            );
        }
    }
    
    public static void CreateOLIHistoriesOnCreate(List<OpportunityLineItem> newList){
        System.debug('inside CreateOLIHistoriesOnCreate method');
        
        if(newList.isEmpty()) return;
        
        // get fields from metadata (Track_History_On_Create__c = TRUE)
        Set<String> fieldsToTrack = getOLIFieldsToTrack('Insert');
        if(fieldsToTrack.isEmpty()) return;
        
        // collect Opportunity Ids
        Set<Id> oppIds = new Set<Id>();
        for(OpportunityLineItem oli : newList){
            if(oli.OpportunityId != null){
                oppIds.add(oli.OpportunityId);
            }
        }
        
        // fetch Opportunities
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]
        );
        
        List<Opportunity_Product_History__c> historyRecords = new List<Opportunity_Product_History__c>();
        
        for(OpportunityLineItem oli : newList){
            Opportunity opp = oppMap.get(oli.OpportunityId);
            if(opp == null) continue;
            
            // Apply same stage + record type check (reuse existing logic)
            if(checkIfStageIsP5OrCC(oli.Opp_RecordType__c, oli.Deal_Stage__c)){
                
                for(String fieldApi : fieldsToTrack){
                    
                    Object value = oli.get(fieldApi);
                    
                    // Only create history if value is NOT null (optional but recommended)
                    if(oli != null){
                        
                        Schema.SObjectField fieldToken = OpportunityLineItem.SObjectType.getDescribe().fields.getMap().get(fieldApi);
                        
                        if(fieldToken == null) continue;
                        
                        String fieldLabel = fieldToken.getDescribe().getLabel();
                        Schema.DisplayType fieldType = fieldToken.getDescribe().getType();
                        
                        Opportunity_Product_History__c history = new Opportunity_Product_History__c();
                        history.Field_Label__c = fieldLabel;
                        history.Field_API_Name__c = fieldApi;
                        history.Opportunity_Product__c = oli.Id;
                        history.Old_Value__c = '';
                        history.New_Value__c = formatValue(value, fieldType);
                        history.Modified_By__c = UserInfo.getUserId();
                        history.Modified_Date__c = System.now();
                        history.Deal_Stage__c = oli.Deal_Stage__c;
                        
                        historyRecords.add(history);
                    }
                }
            }
        }
        
        // enqueue async insert
        if(!historyRecords.isEmpty()){
            System.enqueueJob(
                new OLIHistoryQueueable(historyRecords)
            );
        }
    }
}