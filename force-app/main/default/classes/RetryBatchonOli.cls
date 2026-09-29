global class RetryBatchonOli implements Database.Batchable<SObject>, Database.AllowsCallouts {
    // Static timestamp to capture the start of the batch execution
    private static final Datetime batchStartTime = Datetime.now();
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        String queryStr = 'SELECT Id, Retry_Attempts__c, OpportunityId, Task_GID__c, Status__c, Method_Name__c, Request__c, Integration_Status__c, Integration_Message__c, Canceled_In_Asana__c FROM OpportunityLineItem '
            			  + 'WHERE Retry_Attempts__c < 3 AND Sync_to_Asana__c = \'Yes\' AND Integration_Status__c=\'Failure\' AND Canceled_In_Asana__c = FALSE';
        return Database.getQueryLocator(queryStr);
    }
    global void execute(Database.BatchableContext bc, List<OpportunityLineItem> scope) {
        HttpResponse res;
        String httpMethod;
        Map<String, String> headers = new Map<String, String>();
        Set<Id> oplinitemsList = new Set<Id>();
        List<Error_Log__c> newErrorLogs = new List<Error_Log__c>();

        List<OpportunityLineItem> oliUpdates = new List<OpportunityLineItem>();
        Integer maxAttempts = 3;
        try{ 
            
            headers.put('Authorization', AsanaIntegrationHandler.getAsanaAuthHeader());
            headers.put('Content-Type', AsanaIntegrationHandler.JSON_CONTENT_TYPE);
            
            //Proccessing all records in scope 
            for (OpportunityLineItem oli : scope) {
                Boolean Issuccess =false;
                Decimal retAttmpt = oli.Retry_Attempts__c;
                if(retAttmpt < maxAttempts){
                   // Determine HTTP method
                    if (oli.Method_Name__c == 'updateAsanaTaskName' ||
                        oli.Method_Name__c == 'updateAsanaTaskStage' ||
                        oli.Method_Name__c == 'updateAsanaTaskFields' ||
                        oli.Method_Name__c == 'updateAsanaTask') {
                            httpMethod = 'PUT';
                        } else if (oli.Method_Name__c == 'createAsanaTask') {
                            httpMethod = 'POST';
                        }
                        
                        // Make callout
                        res = makeCalloutUtilityMethod(oli.Method_Name__c, oli.Request__c, httpMethod, headers, oli.Task_GID__c);
                        
                        // Update current oli to log count 
                    if (res != null && (res.getStatusCode() >= 200 && res.getStatusCode() < 300)) {
                        Issuccess = true;
                    }else{
                        Error_Log__c newLog = new Error_Log__c(
                            Request__c = oli.Request__c,
                            Status__c = AsanaIntegrationHandler.STATUS_FAILURE,
                            Response__c = res != null ? res.getBody() : 'Null response',
                            OpportunityLineItem__c = oli.id,
                            Opportunity__c = oli.OpportunityId,
                            Method_Name__c = oli.Method_Name__c,
                            Retry_Attempts__c = oli.Retry_Attempts__c +1,
                            Integration_Message__c = 'Batch Processed - Attempt: ' + (oli.Retry_Attempts__c + 1) + ' >>>>>>>> ' + (res != null ? res.getBody() : 'Null response'),
                            Task_GID__c = oli.Task_GID__c
                        );
                        newErrorLogs.add(newLog);
                    }
                    system.debug('Response--->'+res.getBody()) ; 
                    oli.Integration_Message__c = (res != null ? res.getBody() : 'Null response');
                    oli.Retry_Attempts__c = Issuccess ? 0: oli.Retry_Attempts__c + 1;
                    oli.Integration_Status__c = Issuccess ? 'Success' : AsanaIntegrationHandler.STATUS_FAILURE;
                    oli.Canceled_in_Asana__c = (Issuccess && oli.Status__c == 'Canceled') ? TRUE : FALSE;
                    oli.Integration_Date_Time__c = System.now();
                    oliUpdates.add(oli);
                }
            }
           
            if (!oliUpdates.isEmpty()) {
                update oliUpdates;
            }
           if (!newErrorLogs.isEmpty()) {
                insert newErrorLogs;
            }
        }catch(Exception e){
            system.debug('Exception in batch class--->'+e);
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Batch execution completed');
    }
    
    public static HttpResponse makeCalloutUtilityMethod(String MethodName, String RequestBody, String CalloutMethod,Map<String, String> Headers, String TaskGid) {
        system.debug('inside makeCalloutUtilityMethod method!');
        HttpRequest req = new HttpRequest();
         HttpResponse response = new HttpResponse();
        
        try {
            req.setMethod(CalloutMethod);
            
            for (String key : Headers.keySet()) {
                req.setHeader(key, Headers.get(key));
            }
            
            if (MethodName == 'getAsanaUserGidByEmail') {
                system.debug('inside getAsanaUserGidByEmail logic!');
                req.setEndpoint('callout:Asana_NC/users?workspace=' + TaskGid + '&opt_fields=email,name');
            } else if (MethodName == 'createAsanaTask' || TaskGid == '') {
                system.debug('inside createAsanaTask logic!');
                req.setEndpoint(AsanaIntegrationHandler.ASANA_ENDPOINT);
            } else if (MethodName == 'updateAsanaTask' ||
                       MethodName == 'updateAsanaTaskStage' ||
                       MethodName == 'updateAsanaTaskFields' ||
                       MethodName == 'updateAsanaTaskName' ||
                       TaskGid != '') {
                           system.debug('inside update logic!');
                           req.setEndpoint(AsanaIntegrationHandler.ASANA_ENDPOINT + '/' + TaskGid);
                       }
            
            if (String.isNotBlank(RequestBody)) {
                req.setBody(RequestBody);
                req.setTimeout(120000);
                Http http = new Http();
                response = http.send(req);
            } 
            else {
            // Default when RequestBody is empty
            response.setStatusCode(400);
            response.setBody('No Request Body provided');
        }
        } catch (Exception ex) {
            System.debug('Callout exception: ' + ex.getMessage());
            response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('Callout failed: ' + ex.getMessage());
        }
        return response;
    }
}