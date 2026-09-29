//**********************		
// Created/Deployment Date: 6th Oct 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 290,283,276,375,287,387, 488, 463, SF-149
// Description: To sync with Asana from OLI	
// Last Modified Date: 02Apr2026		
//***********************	
public class AsanaIntegrationHandler {
    
    // Add a static set to track processed line items in the current transaction
    private static Set<Id> processedLineItemIds = new Set<Id>();	
    
    // Constants
    public static final String ASANA_ENDPOINT = 'callout:Asana_NC/tasks'; 
    public static final Integer SUCCESS_STATUS_201 = 201;
    public static final Integer SUCCESS_STATUS_200 = 200;
    public static final String BEARER_PREFIX = 'Bearer ';
    public static final String JSON_CONTENT_TYPE = 'application/json';
    public static final String HTTP_POST = 'POST';
    public static final String HTTP_PUT = 'PUT';
    
    // Status constants
    public static final String STATUS_SUCCESS = 'Success';
    public static final String STATUS_FAILURE = 'Failure';
    
    // Cache for configuration values
    public static Map<String, String> configCache = new Map<String, String>();
    
    @TestVisible
    public static void loadAllConfigValues() {
        if (!configCache.isEmpty()) return;
        List<AsanaConfig__mdt> allConfigs = [
            SELECT DeveloperName, Access_Token__c FROM AsanaConfig__mdt WHERE Access_Token__c != null
        ];
        for (AsanaConfig__mdt config : allConfigs) {
            configCache.put(config.DeveloperName, config.Access_Token__c);
        }
    }
    
    // ========== DYNAMIC MAPPING ENGINE ==========
    
    // Cache for metadata-driven field mappings
    private static Map<String, List<Asana_Field_Mapping__mdt>> fieldMappingCache = new Map<String, List<Asana_Field_Mapping__mdt>>();
    private static Map<String, Map<String, String>> valueMappingCache = new Map<String, Map<String, String>>();
    
    // Dynamic Mapping Engine
    @TestVisible
    public static Map<String, Object> buildDynamicFields(SObject srcRec) {
        system.debug('inside buildDynamicFields method');
        Map<String, Object> result = new Map<String, Object>();
        if (srcRec == null) return result;
    
        String objName = srcRec.getSObjectType().getDescribe().getName();
        
        // Load mappings into cache if not present
        if (!fieldMappingCache.containsKey(objName)) {
            List<Asana_Field_Mapping__mdt> mappings = [
                SELECT Salesforce_Object__c, Salesforce_Field_API__c, Asana_Field_GID__c, 
                       Data_Type__c, IsActive__c
                FROM Asana_Field_Mapping__mdt
                WHERE Salesforce_Object__c = :objName AND IsActive__c = TRUE
                ORDER BY Salesforce_Field_API__c
            ];
            fieldMappingCache.put(objName, mappings);
        }
    
        List<Asana_Field_Mapping__mdt> mappingsForObj = fieldMappingCache.get(objName);
        if (mappingsForObj == null || mappingsForObj.isEmpty()) return result;
    
        // Build a map of populated fields
        Map<String, Object> populated = srcRec.getPopulatedFieldsAsMap();
    
        for (Asana_Field_Mapping__mdt m : mappingsForObj) {
            if (m == null) continue;
            
            String sfFieldApi = m.Salesforce_Field_API__c;
            String asanaGid = m.Asana_Field_GID__c;
            String dataType = m.Data_Type__c;
            system.debug('sfFieldApi, asanaGid, dataType ==> '+ sfFieldApi + ', ' + asanaGid+', ' + dataType);
    
            if (String.isBlank(sfFieldApi) || String.isBlank(asanaGid)) continue;
            if (!populated.containsKey(sfFieldApi)){
                // MK - 02Apr2026 - to clear values in Asana if cleared in SF
                result.put(asanaGid, null);
                system.debug('the value is empty for this field: '+sfFieldApi);
                continue;
            } 
    
            Object rawVal;
            try {
                rawVal = srcRec.get(sfFieldApi);
                // system.debug('the raw value for this field ' + sfFieldApi + ': ' + rawVal);
            } catch (Exception ex) {
                rawVal = null;
            }
    
            if (rawVal == null) continue;
    
            // Transform based on declared Data_Type__c
            try {
                if (String.isBlank(dataType) || dataType == 'Text' || dataType == 'Number') {
                    if (dataType == 'Number') {
                        if (rawVal instanceof Decimal || rawVal instanceof Integer || rawVal instanceof Double) {
                            result.put(asanaGid, rawVal);
                        } else {
                            try {
                                Decimal d = Decimal.valueOf(String.valueOf(rawVal));
                                result.put(asanaGid, d);
                            } catch (Exception e) {
                                System.debug('Invalid number for field ' + sfFieldApi + ': ' + rawVal);
                            }
                        }
                    } else {
                        result.put(asanaGid, String.valueOf(rawVal));
                    }
                } else if (dataType == 'Date') {
                    Map<String, Object> dateObj = toAsanaDateObject(rawVal);
                    if (dateObj != null) result.put(asanaGid, dateObj);
                } else if (dataType == 'Boolean') {
                    Boolean bVal = null;
                    if (rawVal instanceof Boolean) bVal = (Boolean)rawVal;
                    else {
                        String s = String.valueOf(rawVal).toLowerCase();
                        if (s == 'true' || s == '1' || s == 'yes') bVal = true;
                        else if (s == 'false' || s == '0' || s == 'no') bVal = false;
                    }
                    if (bVal != null) result.put(asanaGid, bVal);
                } else if (dataType == 'Picklist') {
                    String mapped = mapPicklistValue(objName, sfFieldApi, String.valueOf(rawVal));
                    if (!String.isBlank(mapped)) result.put(asanaGid, mapped);
                    system.debug('Picklist map result key ==> '+asanaGid + ', value == '+result.get(asanaGid));
                } else if (dataType == 'MultiPicklist') {
                    List<String> parts = new List<String>();
                    String rawStr = String.valueOf(rawVal);
                    if (String.isNotBlank(rawStr)) {
                        parts = rawStr.split(';');
                    }
                    List<String> mappedEnumGids = mapMultiPicklistValues(objName, sfFieldApi, parts);
                    if (!mappedEnumGids.isEmpty()) result.put(asanaGid, mappedEnumGids);
                    else result.put(asanaGid, new List<String>());
                    system.debug('MultiPicklist map result key ==> '+asanaGid + ', value == '+result.get(asanaGid));
                } else {
                    result.put(asanaGid, String.valueOf(rawVal));
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error mapping field ' + sfFieldApi + ' : ' + e.getMessage());
            }
        }
        return result;
    }
    
    // Picklist value mapping helpers
    @TestVisible
    private static String mapPicklistValue(String sObjectName, String sfFieldApi, String sfValue) {
        if (String.isBlank(sfFieldApi) || String.isBlank(sfValue)) return null;
    
        String cacheKey = sObjectName + '.' + sfFieldApi;
        
        if (!valueMappingCache.containsKey(cacheKey)) {
            Map<String, String> vm = new Map<String, String>();
            List<Asana_Value_Mapping__mdt> rows = [
                SELECT Parent_Field__c, Salesforce_Value__c, Asana_Enum_GID__c
                FROM Asana_Value_Mapping__mdt
                WHERE Parent_Field__c = :sfFieldApi
            ];
            
            for (Asana_Value_Mapping__mdt r : rows) {
                if (!String.isBlank(r.Salesforce_Value__c) && !String.isBlank(r.Asana_Enum_GID__c)) {
                    vm.put(r.Salesforce_Value__c.trim(), r.Asana_Enum_GID__c);
                }
            }
            valueMappingCache.put(cacheKey, vm);
        }
    
        Map<String, String> mapForField = valueMappingCache.get(cacheKey);
        if (mapForField == null) return null;
    
        String found = mapForField.get(sfValue);
        if (found == null) found = mapForField.get(sfValue.trim());
        return found;
    }
    
    @TestVisible
    private static List<String> mapMultiPicklistValues(String sObjectName, String sfFieldApi, List<String> sfValues) {
        List<String> out = new List<String>();
        if (sfValues == null || sfValues.isEmpty()) return out;
    
        for (String v : sfValues) {
            if (String.isBlank(v)) continue;
            String gid = mapPicklistValue(sObjectName, sfFieldApi, v.trim());
            if (!String.isBlank(gid)) out.add(gid);
            else {
                System.debug(LoggingLevel.WARN, 'No mapping for multi-picklist value: ' + v + ' on ' + sfFieldApi);
            }
        }
        return out;
    }
    
    //updating opty stage from getting the access token from mdt
    @TestVisible
    public static String getAsanaAuthHeader() {
        if (configCache.isEmpty()) {
            loadAllConfigValues();
        }
        String token = configCache.get('Access_Token');
        if (String.isBlank(token)) {
            throw new CalloutException('Asana access token is missing from config metadata');
        }
        return BEARER_PREFIX + token;
    }
    
    // Helper method to update User record with Asana GID
    private static void updateUserGid(String email, String gid) {
        try {
            List<User> usersToUpdate = [
                SELECT Id, Asana_GID__c 
                FROM User 
                WHERE Email = :email 
                LIMIT 1
            ];
            
            if (!usersToUpdate.isEmpty()) {
                usersToUpdate[0].Asana_GID__c = gid;
                update usersToUpdate[0];
                System.debug('Updated Asana GID for user: ' + email + ' with GID: ' + gid);
            }
        } catch (Exception e) {
            System.debug('Failed to update User GID for ' + email + ': ' + e.getMessage());
        }
    }
    
    @TestVisible
    private static String getAsanaUserGidByEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        
        try {
            // FIRST: Check if we have the GID stored in Salesforce User record
            List<User> salesforceUsers = [
                SELECT Id, Email, Asana_GID__c 
                FROM User 
                WHERE Email = :email 
                AND Asana_GID__c != null 
                LIMIT 1
            ];
            
            // If we found a User with stored GID, use it
            if (!salesforceUsers.isEmpty() && String.isNotBlank(salesforceUsers[0].Asana_GID__c)) {
                System.debug('Found Asana GID in User record: ' + salesforceUsers[0].Asana_GID__c + ' for email: ' + email);
                return salesforceUsers[0].Asana_GID__c;
            }
            
            // SECOND: Fallback to Asana API lookup (your existing code)
            System.debug('GID not found in User record for ' + email + ', falling back to Asana API lookup');
            Http http = new Http();
            String workspaceId = configCache.get('WORKSPACE_ID');
            String baseEndpoint = 'callout:Asana_NC/users?workspace=' + workspaceId +
                '&email=' + EncodingUtil.urlEncode(email, 'UTF-8') +
                '&opt_fields=email,name,gid' +
                '&limit=100';
            
            String nextPageEndpoint = baseEndpoint;
            Integer pageCount = 0;
            final Integer MAX_PAGES = 10;
            
            while (nextPageEndpoint != null && pageCount < MAX_PAGES) {
                pageCount++;
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(nextPageEndpoint);
                req.setMethod('GET');
                req.setHeader('Authorization', getAsanaAuthHeader());
                req.setTimeout(120000);
                
                HttpResponse res = http.send(req);
                System.debug('Asana User Lookup Response Page ' + pageCount + ' for ' + email + ': ' + res.getBody());
                
                if (res.getStatusCode() == 200) {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> users = (List<Object>) parsed.get('data');
                    
                    for (Object o : users) {
                        Map<String, Object> userObj = (Map<String, Object>) o;
                        String userEmail = (String) userObj.get('email');
                        String userName  = (String) userObj.get('name');
                        String userGid   = (String) userObj.get('gid');
                        
                        // Log every user returned
                        System.debug('User from Asana → Name: ' + userName + ', Email: ' + userEmail + ', GID: ' + userGid);
                        
                        // Compare with input
                        System.debug('Comparing Asana email: ' + userEmail + ' with input email: ' + email);
                        
                        if (userEmail != null && userEmail.trim().toLowerCase() == email.trim().toLowerCase()) {
                            System.debug('Found user GID via API: ' + userGid + ' for email: ' + userEmail);
                            
                            // OPTIONAL: Update the User record with this GID for future use
                            updateUserGid(email, userGid);
                            
                            return userGid;
                        }
                    }
                    
                    // Next page check
                    Map<String, Object> nextPage = (Map<String, Object>) parsed.get('next_page');
                    if (nextPage != null && nextPage.get('offset') != null) {
                        nextPageEndpoint = baseEndpoint + '&offset=' + nextPage.get('offset');
                    } else {
                        nextPageEndpoint = null;
                    }
                } else {
                    System.debug(LoggingLevel.ERROR, 'Asana API error: ' + res.getStatusCode() + ' - ' + res.getBody());
                    break;
                }
            }
            
            if (pageCount >= MAX_PAGES) {
                System.debug(LoggingLevel.WARN, 'Reached maximum page limit without finding user');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking Asana user by email: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        
        return null;
    }
    
    public static void logAsanaSyncResult(
        String status,
        String reason,
        Id lineItemId,
        Id oppId,
        String taskGid,
        String reqBody,
        String resBody,
        String methodName
    ) {
        System.debug('@@ReqBody: ' + reqBody);
        System.debug('@@ResBody: ' + resBody);
        System.debug('@@MethodName: ' + methodName);
        
        // Basic parameter validation
        if (String.isBlank(status) || String.isBlank(reason) || lineItemId == null || String.isBlank(methodName)) {
            System.debug(LoggingLevel.WARN, 
                         'Incomplete log parameters: ' + 
                         'status=' + status + 
                         ', reason=' + reason + 
                         ', lineItemId=' + lineItemId + 
                         ', methodName=' + methodName);
            return;
        }
        
        try {
            // Always create a fresh error log record — no duplicate prevention
            Error_Log__c log = new Error_Log__c(
                Status__c            = status,
                Integration_Message__c = reason,
                OpportunityLineItem__c = lineItemId,
                Opportunity__c       = oppId,
                Task_GID__c          = taskGid,
                Request__c           = reqBody,
                Response__c          = resBody,
                Retry_Attempts__c    = 0,
                Method_Name__c       = methodName
            );
            
            insert log;
            System.debug('Error log inserted for OLI ' + lineItemId + ' | Method: ' + methodName);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                         'Failed to insert Error_Log__c for ' + lineItemId + ': ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
    }
    
    public static void createAsanaTask(OpportunityLineItem lineItem) {
        if (lineItem?.OpportunityId == null) {
            System.debug(LoggingLevel.INFO, 'Skipping line item without opportunity: ' + lineItem?.Name);
            return;
        }
        
        // Guard clause to prevent duplicate processing in the same transaction
        if (processedLineItemIds.contains(lineItem.Id)) {
            System.debug(LoggingLevel.WARN, 'Line item ' + lineItem.Id + ' already processed in this transaction');
            return;
        }
        processedLineItemIds.add(lineItem.Id);
        
        loadAllConfigValues();
        
        AsanaTaskRequest taskRequest = null;
        AsanaTaskResponse response = null;
        Boolean hasHandledError = false; // Track if error has been handled
        
        try {
            Opportunity opp = getOpportunityData(lineItem);
            System.debug('Retrieved Opportunity: ' + (opp != null ? opp.Name : 'null'));
            
            if (opp == null) {
                System.debug(LoggingLevel.WARN, 'Could not retrieve opportunity data for line item: ' + lineItem.Name);
                handleTaskCreationFailure(lineItem, 'Opportunity not found', null, null, null, 'createAsanaTask');
                hasHandledError = true;
                return;
            }
            
            System.debug('Opportunity Stage: ' + opp.StageName);
            
            taskRequest = buildTaskRequest(lineItem, opp);
            System.debug('Task Request: ' + taskRequest.toJsonString());
            
            response = sendTaskCreationRequest(taskRequest);
            System.debug('Response Status: ' + response.isSuccess);
            System.debug('Response Task GID: ' + response.taskGid);
            System.debug('Response Error: ' + response.errorMessage);            
            
            if (response.isSuccess) {
                handleTaskCreationSuccess(lineItem, response.taskGid);
            } else {
                handleTaskCreationFailure(lineItem, response.errorMessage, taskRequest.toJsonString(), response.taskGid, response.errorMessage, 'createAsanaTask');
                hasHandledError = true;
            }
            
        } catch (Exception e) {
            // Only handle in catch if not already handled in try block
            if (!hasHandledError) {
                System.debug(LoggingLevel.ERROR, 'Error creating Asana task for line item ' + lineItem.Id + ': ' + e.getMessage());
                System.debug('Exception Type: ' + e.getTypeName());
                System.debug('Exception Stack Trace: ' + e.getStackTraceString());
                System.debug('Config Cache at time of error: ' + JSON.serializePretty(configCache));
                
                String reqBody = taskRequest != null ? taskRequest.toJsonString() : null;
                String resBody = response != null ? response.errorMessage : null;
                handleTaskCreationFailure(lineItem, 'Exception during task creation: ' + e.getMessage(), reqBody, response != null ? response.taskGid : null, resBody, 'createAsanaTask');
            }
        }
    }
    
    
    // Overload the existing method for backward compatibility
    public static AsanaTaskResponse sendTaskUpdateRequest(String taskGid, Map<String, Object> customFields) {
        return sendTaskUpdateRequest(taskGid, customFields, new Map<String, Object>());
    } 
    
    //Update logic
    public static void updateAsanaTask(OpportunityLineItem lineItem) {
        System.debug('Starting updateAsanaTask for line item: ' + lineItem.Id);
        
        if (String.isBlank(lineItem.Task_GID__c)) {
            System.debug('Skipping update - Task_GID__c is blank for line item: ' + lineItem.Id);
            updateLineItemIfSuccessOrFailure(lineItem.Id, '', STATUS_FAILURE, 'Quest ID is missing',null,'updateAsanaTask');
            return;
        }
        
        loadAllConfigValues();
        
        try {
            Opportunity opp = getOpportunityData(lineItem);
            if (opp == null) {
                System.debug('Could not retrieve opportunity data for line item: ' + lineItem.Id);
                updateLineItemIfSuccessOrFailure(lineItem.Id, lineItem.Task_GID__c, STATUS_FAILURE, 'Opportunity not found',null,'updateAsanaTask');
                return;
            }
            
            // Build the update request with custom fields
            Map<String, Object> customFields = getCustomFieldsForUpdate(lineItem, opp);
            
            // Check if we need to update task name or assignee (for opportunity name/owner changes)
            Map<String, Object> directUpdates = new Map<String, Object>();
            
            // Update task name if opportunity name changed
            if (lineItem.Opportunity_Name__c != null) {
                Map<Id, Integer> sequenceMap = getSequenceNumbersForAllTasks(opp.Id);
                String newTaskName = rebuildTaskName(lineItem.Opportunity_Name__c, lineItem, opp.Id, sequenceMap);
                directUpdates.put('name', newTaskName);
            }
            
            // Update assignee if account manager changed
            String assigneeGid = determineAssigneeGid(opp, lineItem);
            if (assigneeGid != null) {
                directUpdates.put('assignee', assigneeGid);
            }
            
            // If no fields need updating, mark as success and return
            if (customFields.isEmpty() && directUpdates.isEmpty()) {
                System.debug('No fields to update for line item: ' + lineItem.Id);
                updateLineItemIfSuccessOrFailure(lineItem.Id, lineItem.Task_GID__c, STATUS_SUCCESS, 'No fields changed',null,'updateAsanaTask');
                return;
            }
            
            // Send the update request to Asana
            AsanaTaskResponse response = sendTaskUpdateRequest(lineItem.Task_GID__c, customFields, directUpdates);
            
            if (response.isSuccess) {
                handleTaskUpdateSuccess(lineItem);
            } else {
                // Create request data for error logging
                Map<String, Object> requestData = new Map<String, Object>{
                    'data' => new Map<String, Object>()
                        };
                            
                            Map<String, Object> dataMap = (Map<String, Object>)requestData.get('data');
                
                if (!directUpdates.isEmpty()) {
                    dataMap.putAll(directUpdates);
                }
                
                if (!customFields.isEmpty()) {
                    dataMap.put('custom_fields', customFields);
                }
                
                handleTaskUpdateFailure(lineItem, response.errorMessage, JSON.serialize(requestData), 'updateAsanaTask');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error updating Asana task for line item ' + lineItem.Id + ': ' + e.getMessage());
            updateLineItemIfSuccessOrFailure(lineItem.Id, lineItem.Task_GID__c, STATUS_FAILURE, 'Exception: ' + e.getMessage(),null,'updateAsanaTask');
            logAsanaSyncResult(STATUS_FAILURE, 'Exception during task update: ' + e.getMessage(), lineItem.Id, lineItem.OpportunityId ,lineItem.Task_GID__c,null,null,'updateAsanaTask');
        }
    }
    
    // Add this enhanced method to handle both custom fields and direct updates
    public static AsanaTaskResponse sendTaskUpdateRequest(String taskGid, Map<String, Object> customFields, Map<String, Object> directUpdates) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint(ASANA_ENDPOINT + '/' + taskGid);
        req.setMethod(HTTP_PUT);
        req.setHeader('Authorization', getAsanaAuthHeader());
        req.setHeader('Content-Type', JSON_CONTENT_TYPE);
        req.setTimeout(120000);
        
        Map<String, Object> requestData = new Map<String, Object>{
            'data' => new Map<String, Object>()
                };
                    
                    Map<String, Object> dataMap = (Map<String, Object>)requestData.get('data');
        
        // Add direct updates (name, assignee, etc.)
        if (!directUpdates.isEmpty()) {
            dataMap.putAll(directUpdates);
        }
        
        // Add custom fields
        if (!customFields.isEmpty()) {
            dataMap.put('custom_fields', customFields);
        }
        
        req.setBody(JSON.serialize(requestData));
        HttpResponse res = http.send(req);
        
        return new AsanaTaskResponse(res);
    }
    
    public static void handleTaskUpdateSuccess(OpportunityLineItem lineItem) {
        System.debug('Task Updated successfully for line item: ' + lineItem.Id);
        
        try {
            OpportunityLineItem oliUpdate = new OpportunityLineItem(
                Id = lineItem.Id,
                Integration_Status__c = STATUS_SUCCESS,
                Integration_Message__c = 'Task updated successfully in Asana',
                Integration_Date_Time__c = System.now()
            );
            // Step 2: If the line item is Cancelled, update the Status__c (or similar) field
            if (lineItem.Status__c == 'Canceled') {
                System.debug('Line item has Status__c = Cancelled. Updating Canceled_in_Asana__c to TRUE.');
                //oliUpdate.Status__c = 'Canceled in Asana';
                oliUpdate.Canceled_in_Asana__c = TRUE;
            }
            
            Database.SaveResult sr = Database.update(oliUpdate, false);
            
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('Update failed for OLI ' + lineItem.Id + ': ' + err.getMessage());
                }
                logAsanaSyncResult(
                    STATUS_FAILURE,
                    'Failed to update OLI after task update: ' + sr.getErrors()[0].getMessage(),
                    lineItem.Id,
                    lineItem.OpportunityId,
                    lineItem.Task_GID__c,null,null,'handleTaskUpdateSuccess'                  
                );
                return;
            }
            
            System.debug('OLI successfully updated to Success after update: ' + lineItem.Id);
            
        } catch (Exception e) {
            System.debug('Exception while updating OLI after task update: ' + e.getMessage());
            logAsanaSyncResult(
                STATUS_FAILURE,
                'Exception while updating OLI after task update: ' + e.getMessage(),
                lineItem.Id,
                lineItem.OpportunityId,
                lineItem.Task_GID__c,null,null,'handleTaskUpdateSuccess'
            );
        }
    }
    
    public static void handleTaskUpdateFailure(OpportunityLineItem lineItem, String errorMessage,String Reqbody,String methodNAme) {
        System.debug('Failed to update Asana task. Error: ' + errorMessage);
        updateLineItemIfSuccessOrFailure(lineItem.Id, lineItem.Task_GID__c, STATUS_FAILURE, errorMessage,Reqbody,methodNAme);
        logAsanaSyncResult(STATUS_FAILURE, 'Failed to update task | ' + errorMessage, lineItem.Id, lineItem.OpportunityId, lineItem.Task_GID__c,Reqbody,errorMessage,methodNAme);
    }
    
    //OLI
    public static Opportunity getOpportunityData(OpportunityLineItem lineItem) {
        if (lineItem.Opportunity != null &&
            String.isNotBlank(lineItem.Opportunity.Name) &&
            String.isNotBlank(lineItem.Opportunity.StageName) &&
            String.isNotBlank(lineItem.Opportunity.SalesVertical__c)) {
                return lineItem.Opportunity;
            }
        
        try {
            List<Opportunity> opps = [
                SELECT Id, Name, StageName, Account_Manager__r.Email, Account_Manager__r.Asana_GID__c, 
                       Amount, CloseDate, Account.Name, Owner.Asana_GID__c, Owner.Name, Owner.Email, 
                       SalesVertical__c, Opportunity_Number__c
                FROM Opportunity
                WHERE Id = :lineItem.OpportunityId
                LIMIT 1
            ];
            return opps.isEmpty() ? null : opps[0];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying opportunity: ' + e.getMessage());
            return null;
        }
    }
    
    // 
    public static AsanaTaskRequest buildTaskRequest(OpportunityLineItem lineItem, Opportunity opp) {
        // Build dynamic field payload from BOTH Opportunity and Line Item
        Map<String, Object> customFields = new Map<String, Object>();
        
        try { 
            customFields.putAll(buildDynamicFields(opp)); 
        } catch (Exception e) { 
            System.debug('Error building dynamic fields for Opportunity: ' + e.getMessage());
        }
        
        try { 
            customFields.putAll(buildDynamicFields(lineItem)); 
        } catch (Exception e) { 
            System.debug('Error building dynamic fields for OLI: ' + e.getMessage());
        }
        
        // SPECIAL HANDLING FOR QUEST TYPE (Product2 lookup)
        String questTypeFieldGid = configCache.get('OPP_PROD_Quest_Type');
        if (String.isNotBlank(questTypeFieldGid) && lineItem.Product2Id != null) {
            try {
                Product2 prod = [
                    SELECT Asana_Enum_GID__c
                    FROM Product2
                    WHERE Id = :lineItem.Product2Id
                    LIMIT 1
                ];
                
                if (String.isNotBlank(prod.Asana_Enum_GID__c)) {
                    customFields.put(questTypeFieldGid, prod.Asana_Enum_GID__c);
                    System.debug('Mapped Quest Type: ' + prod.Asana_Enum_GID__c);
                }
            } catch (Exception e) {
                System.debug('Error fetching Product2 for Quest Type mapping: ' + e.getMessage());
            }
        }
        
        // SPECIAL HANDLING FOR OPPORTUNITY NUMBER (from Opportunity object)
        String oppUniqNum = configCache.get('Opportunity_Number');
        if (String.isNotBlank(oppUniqNum)) {
            try {
                // Safely check if the field exists and has value
                if (opp.get('Opportunity_Number__c') != null) {
                    String oppNumber = String.valueOf(opp.get('Opportunity_Number__c'));
                    customFields.put(oppUniqNum, oppNumber);
                    System.debug('Mapped Opportunity Number: ' + oppNumber);
                }
            } catch (Exception e) {
                System.debug('Opportunity_Number__c field not accessible: ' + e.getMessage());
            }
        }
        
        // SPECIAL HANDLING FOR OWNER FIELDS (Keep original logic)
        // Deal Owner
        String oppDealOwner = configCache.get('Deal_Owner');
        if (String.isNotBlank(oppDealOwner)) {
            if (String.isNotBlank(opp.OwnerId)) {
                User owner = [SELECT Email FROM User WHERE Id = :opp.OwnerId LIMIT 1];
                String ownerGid = getAsanaUserGidByEmail(owner.Email);
                if (String.isNotBlank(ownerGid)) {
                    customFields.put(oppDealOwner, ownerGid);
                    System.debug('Mapped Deal Owner: ' + owner.Email + ' -> GID: ' + ownerGid);
                }
            }
        }
        
        // Account Manager
        String oppAccMan = configCache.get('Account_Manager');
        if (String.isNotBlank(oppAccMan)) {
            if (String.isNotBlank(opp.Account_Manager__c)) {
                User accMan = [SELECT Email FROM User WHERE Id = :opp.Account_Manager__c LIMIT 1];
                String accManGid = getAsanaUserGidByEmail(accMan.Email);
                if (String.isNotBlank(accManGid)) {
                    customFields.put(oppAccMan, accManGid);
                    System.debug('Mapped Account Manager: ' + accMan.Email + ' -> GID: ' + accManGid);
                }
            }
        }
    
        // Use the new determineAssigneeGid method for consistency
        String assigneeGid = determineAssigneeGid(opp, lineItem);
        
        // Use the enhanced sequence number logic
        Integer sequenceNumber = getNextSequenceNumber(opp.Id);
        
        // Get product name
        String productName = lineItem.Product_Name__c;
        /*String productName;
         try {
            productName = [
                SELECT Name
                FROM Product2
                WHERE Id = :lineItem.Product2Id
                LIMIT 1
            ].Name;
        } catch (Exception e) {
            productName = lineItem.Name;
        }*/
        
        String taskName = String.format('{0} - {1} {2}', new List<String>{
            opp.Name, 
            productName,
            String.valueOf(sequenceNumber)
        });
        
        String notes = '';
        
        return new AsanaTaskRequest(
            taskName,
            new List<String>{configCache.get('FIXED_PROJECT_ID')},
            configCache.get('WORKSPACE_ID'),
            customFields,
            notes,
            assigneeGid
        );
    }    
    
    //
    public static Map<String, Object> getCustomFieldsForUpdate(OpportunityLineItem lineItem, Opportunity opp) {
        // Build dynamic field payload from BOTH Opportunity and Line Item
        Map<String, Object> customFields = new Map<String, Object>();
        
        try { 
            customFields.putAll(buildDynamicFields(opp)); 
        } catch (Exception e) { 
            System.debug('Error building dynamic fields for Opportunity: ' + e.getMessage());
        }
        
        try { 
            customFields.putAll(buildDynamicFields(lineItem)); 
        } catch (Exception e) { 
            System.debug('Error building dynamic fields for OLI: ' + e.getMessage());
        }
        
        // SPECIAL HANDLING FOR OPPORTUNITY NUMBER (from Opportunity object)
        String oppUniqNum = configCache.get('Opportunity_Number');
        if (String.isNotBlank(oppUniqNum)) {
            try {
                // Safely check if the field exists and has value
                if (opp.get('Opportunity_Number__c') != null) {
                    String oppNumber = String.valueOf(opp.get('Opportunity_Number__c'));
                    customFields.put(oppUniqNum, oppNumber);
                    System.debug('Mapped Opportunity Number: ' + oppNumber);
                }
            } catch (Exception e) {
                System.debug('Opportunity_Number__c field not accessible: ' + e.getMessage());
            }
        }
    
        // SPECIAL HANDLING FOR OWNER FIELDS (Keep original logic)
        // Deal Owner
        String oppDealOwner = configCache.get('Deal_Owner');
        if (String.isNotBlank(oppDealOwner)) {
            if (String.isNotBlank(opp.OwnerId)) {
                User owner = [SELECT Email FROM User WHERE Id = :opp.OwnerId LIMIT 1];
                String ownerGid = getAsanaUserGidByEmail(owner.Email);
                if (String.isNotBlank(ownerGid)) {
                    customFields.put(oppDealOwner, ownerGid);
                    System.debug('Mapped Deal Owner for update: ' + owner.Email + ' -> GID: ' + ownerGid);
                }
            }
        }
        
        // Account Manager
        String oppAccMan = configCache.get('Account_Manager');
        if (String.isNotBlank(oppAccMan)) {
            if (String.isNotBlank(opp.Account_Manager__c)) {
                User accMan = [SELECT Email FROM User WHERE Id = :opp.Account_Manager__c LIMIT 1];
                String accManGid = getAsanaUserGidByEmail(accMan.Email);
                if (String.isNotBlank(accManGid)) {
                    customFields.put(oppAccMan, accManGid);
                    System.debug('Mapped Account Manager for update: ' + accMan.Email + ' -> GID: ' + accManGid);
                }
            }
        }
        
        // Quest Type (Product Mapping) - ADD THIS SECTION
        String questTypeFieldGid = configCache.get('OPP_PROD_Quest_Type');
        if (String.isNotBlank(questTypeFieldGid) && lineItem.Product2Id != null) {
            try {
                Product2 prod = [
                    SELECT Asana_Enum_GID__c
                    FROM Product2
                    WHERE Id = :lineItem.Product2Id
                    LIMIT 1
                ];
                
                if (String.isNotBlank(prod.Asana_Enum_GID__c)) {
                    customFields.put(questTypeFieldGid, prod.Asana_Enum_GID__c);
                    System.debug('Mapped Quest Type: ' + prod.Asana_Enum_GID__c);
                }
            } catch (Exception e) {
                System.debug('Error fetching Product2 for Quest Type mapping: ' + e.getMessage());
            }
        }
    
        return customFields;
    }
    
    
    // CORRECTED: Proper fallback logic with fixed line item creator access
    @TestVisible
    private static String determineAssigneeGid(Opportunity opp, OpportunityLineItem lineItem) {
        system.debug('inside determineAssigneeGid method!');
        String assigneeEmail = null;
        String assigneeGid = null;
        
        // PRIORITY 1: Account Manager (same as buildTaskRequest)
        if (opp.Account_Manager__r != null && String.isNotBlank(opp.Account_Manager__r.Email)) {
            assigneeEmail = opp.Account_Manager__r.Email;
            system.debug('assigneeEmail ==> '+assigneeEmail);
            
            // First try to get GID from User field directly
            if (String.isNotBlank(opp.Account_Manager__r.Asana_GID__c)) {
                assigneeGid = opp.Account_Manager__r.Asana_GID__c;
                System.debug('Using Account Manager GID from User field: ' + assigneeGid + ' for email: ' + assigneeEmail);
            } else {
                assigneeGid = getAsanaUserGidByEmail(assigneeEmail);
                System.debug('Using Account Manager via email lookup: ' + assigneeEmail + ' | GID: ' + assigneeGid);
            }
        }
        
        // PRIORITY 2: Fallback to Line Item Creator
        if (String.isBlank(assigneeGid) && lineItem != null) {
            system.debug('inside PRIORITY 2 condition');
            // Query for the line item creator with Asana GID
            List<OpportunityLineItem> lineItemsWithCreator = [
                SELECT Id, CreatedBy.Email, CreatedBy.Asana_GID__c 
                FROM OpportunityLineItem 
                WHERE Id = :lineItem.Id 
                LIMIT 1
            ];
            
            if (!lineItemsWithCreator.isEmpty() && 
                lineItemsWithCreator[0].CreatedBy != null && 
                String.isNotBlank(lineItemsWithCreator[0].CreatedBy.Email)) {
                    system.debug('inside lineItemsWithCreator logic');
                    assigneeEmail = lineItemsWithCreator[0].CreatedBy.Email;
                    
                    // Check if GID is directly on User record first
                    if (String.isNotBlank(lineItemsWithCreator[0].CreatedBy.Asana_GID__c)) {
                        assigneeGid = lineItemsWithCreator[0].CreatedBy.Asana_GID__c;
                        System.debug('Using Line Item Creator GID from User field: ' + assigneeGid);
                    } else {
                        assigneeGid = getAsanaUserGidByEmail(assigneeEmail);
                        System.debug('Using Line Item Creator via email lookup: ' + assigneeEmail + ' | GID: ' + assigneeGid);
                    }
                }
        }
        
        System.debug('Final assignee determination - Email: ' + assigneeEmail + ' | GID: ' + assigneeGid);
        return assigneeGid;
    }
    
    // Date format for custom date fields
    // Asana only supports ISO 8601 date format for custom fields of type date
    @TestVisible
    private static Map<String, Object> toAsanaDateObject(Object sfDateOrDatetime) {
        if (sfDateOrDatetime == null) return null;
        
        Date d;
        if (sfDateOrDatetime instanceof Date) {
            d = (Date) sfDateOrDatetime;
        } else if (sfDateOrDatetime instanceof Datetime) {
            d = ((Datetime) sfDateOrDatetime).date();
        } else {
            return null;
        }
        
        String isoDate = String.format('{0}-{1}-{2}', new List<Object>{
            String.valueOf(d.year()),
                d.month() < 10 ? '0' + d.month() : String.valueOf(d.month()),
                    d.day()   < 10 ? '0' + d.day()   : String.valueOf(d.day())
                        });
        
        return new Map<String, Object>{ 'date' => isoDate };
            }
    
    public static AsanaTaskResponse sendTaskCreationRequest(AsanaTaskRequest taskRequest) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint(ASANA_ENDPOINT);
        req.setMethod(HTTP_POST);
        req.setHeader('Authorization', getAsanaAuthHeader());
        req.setHeader('Content-Type', JSON_CONTENT_TYPE);
        req.setTimeout(120000);
        
        req.setBody(taskRequest.toJsonString());
        HttpResponse res = http.send(req);
        
        return new AsanaTaskResponse(res);
    }
    
    public static void handleTaskCreationSuccess(OpportunityLineItem lineItem, String taskGid) {
        System.debug(LoggingLevel.INFO, 'Task Created with GID: ' + taskGid);
        try {
            OpportunityLineItem oliUpdate = new OpportunityLineItem(
                Id = lineItem.Id,
                Task_GID__c = taskGid,
                Integration_Status__c = STATUS_SUCCESS,               
                Integration_Message__c = 'Task created successfully in Asana', // ✅ Set a clear message
                Integration_Date_Time__c = System.now()
            );
            
            Database.SaveResult sr = Database.update(oliUpdate, false);
            
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('Update failed for OLI ' + lineItem.Id + ': ' + err.getMessage());
                }
                logAsanaSyncResult(
                    STATUS_FAILURE,
                    'Failed to update OLI after task creation: ' + sr.getErrors()[0].getMessage(),
                    lineItem.Id,
                    lineItem.OpportunityId,
                    taskGid,null,null,'handleTaskCreationSuccess'
                );
                return;
            }
            
            System.debug('OLI successfully updated to Success: ' + lineItem.Id);            
            
        } catch (Exception e) {
            System.debug('Exception while updating OLI: ' + e.getMessage());
            logAsanaSyncResult(
                STATUS_FAILURE,
                'Exception while updating OLI after task creation: ' + e.getMessage(),
                lineItem.Id,
                lineItem.OpportunityId,
                taskGid,null,null,'handleTaskCreationSuccess'
            );
        }
    }
    
    @TestVisible
    public static void handleTaskCreationFailure(
        OpportunityLineItem lineItem, 
        String errorMessage,
        String reqBody,
        String taskGid, 
        String resBody,
        String methodName
    ) {
        System.debug(LoggingLevel.ERROR, 'Failed to create Asana task. Error: ' + errorMessage);
        System.debug('taskGid: ' + taskGid);
        System.debug('reqBody: ' + reqBody);
        
        // Ensure line item update doesn’t block logging
        try {
            updateLineItemIfSuccessOrFailure(
                lineItem.Id,
                '',
                STATUS_FAILURE,
                errorMessage,
                reqBody,
                methodName
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to update OpportunityLineItem: ' + e.getMessage());
        }
        
        // Always try to log the failure
        try {
            logAsanaSyncResult(
                STATUS_FAILURE,
                'Failed to create task | ' + errorMessage,
                lineItem.Id,
                lineItem.OpportunityId,
                taskGid,
                reqBody,
                resBody,
                methodName
            );
        } catch (Exception logEx) {
            System.debug(LoggingLevel.ERROR, 'Failed to create Error_Log__c record: ' + logEx.getMessage());
        }
    }
    
    public static void updateLineItemIfSuccessOrFailure(
        Id lineItemId, 
        String taskGid, 
        String status, 
        String message,
        String reqBody,
        String methodName
    ) {
        try {
            OpportunityLineItem lineItemToUpdate = new OpportunityLineItem(
                Id = lineItemId,
                Task_GID__c = taskGid, 
                Integration_Status__c = status,
                Integration_Message__c = message,
                Integration_Date_Time__c = System.now(),
                Method_Name__c = methodName,
                Request__c = reqBody
            );
            update lineItemToUpdate;
            System.debug('Updated OpportunityLineItem successfully: ' + lineItemId);
        } catch (DmlException dmle) {
            System.debug(LoggingLevel.ERROR, 'Failed to update OpportunityLineItem: ' + dmle.getMessage());
            // Do not throw — we still want logging to continue
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected error updating OpportunityLineItem: ' + e.getMessage());
        }
    }
    
    public static String buildStageUpdateRequestBody(String asanaStageEnumGid) {
        Map<String, Object> requestData = new Map<String, Object>{
            'data' => new Map<String, Object>{
                'custom_fields' => new Map<String, Object>{
                    configCache.get('CUSTOM_FIELD_STAGE_ID') => asanaStageEnumGid
                        }
            }
        };
            return JSON.serialize(requestData);
    }
    
    public class AsanaTaskRequest {
        public String taskName { get; private set; }
        public List<String> projects { get; private set; }
        public String workspace { get; private set; }
        public Map<String, Object> customFields { get; private set; }
        public String notes { get; private set; }
        public String assignee { get; private set; }
        
        public AsanaTaskRequest(String taskName, List<String> projects, String workspace, 
                                Map<String, Object> customFields, String notes, String assignee) {
                                    this.taskName = taskName;
                                    this.projects = projects;
                                    this.workspace = workspace;
                                    this.customFields = customFields;
                                    this.notes = notes;
                                    this.assignee = assignee;
                                }
        
        public String toJsonString() {
            Map<String, Object> dataMap = new Map<String, Object>{
                'name' => taskName,
                    'projects' => projects,
                    'workspace' => workspace,
                    'custom_fields' => customFields,
                    'notes' => notes
                    };
                        
                        if (String.isNotBlank(assignee)) {
                            dataMap.put('assignee', assignee);
                        }
            
            return JSON.serialize(new Map<String, Object>{ 'data' => dataMap });
        }
    }
    
    public class AsanaTaskResponse {
        public Boolean isSuccess { get; private set; }
        public String taskGid { get; private set; }
        public String errorMessage { get; private set; }
        
        public AsanaTaskResponse(HttpResponse response) {
            if (response == null) {
                this.isSuccess = false;
                this.errorMessage = 'Null response received from Asana';
                return;
            }
            
            // Handle both POST (201) and PUT (200) success statuses
            if (response.getStatusCode() == SUCCESS_STATUS_201 || response.getStatusCode() == SUCCESS_STATUS_200) {
                this.isSuccess = true;
                Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                this.taskGid = (String) ((Map<String, Object>) parsedResponse.get('data')).get('gid');
            } else {
                this.isSuccess = false;
                this.errorMessage = response.getBody();
            }
        }
    }
    
    // Helper method to rebuild task name using existing logic
    @TestVisible
    private static String rebuildTaskName(String opportunityName, OpportunityLineItem lineItem, Id oppId, Map<Id, Integer> sequenceMap) {
        // Get sequence number from the map
        Integer sequenceNumber = sequenceMap.get(lineItem.Id);
        
        // Get product name
        String productName;
        try {
            productName = [
                SELECT Name
                FROM Product2
                WHERE Id = :lineItem.Product2Id
                LIMIT 1
            ].Name;
        } catch (Exception e) {
            productName = lineItem.Name; 
        }
        
        return String.format('{0} - {1} {2}', new List<String>{
            opportunityName, 
                productName,
                String.valueOf(sequenceNumber)
                });
    }
    
    // Helper method to get the next sequence number for an Opportunity
    public static Integer getNextSequenceNumber(Id opportunityId) {
        // Count only line items that already have Asana tasks
        Integer existingTaskCount = [
            SELECT COUNT() 
            FROM OpportunityLineItem 
            WHERE OpportunityId = :opportunityId
            AND Task_GID__c != null
        ];
        
        return existingTaskCount + 1;
    }
    
    // NEW: Method to rebuild sequence numbers for ALL tasks when opportunity name changes
    @TestVisible
    private static Map<Id, Integer> getSequenceNumbersForAllTasks(Id opportunityId) {
        Map<Id, Integer> lineItemToSequenceMap = new Map<Id, Integer>();
        
        // Query all line items ordered by creation date
        List<OpportunityLineItem> allLineItems = [
            SELECT Id, Task_GID__c, CreatedDate
            FROM OpportunityLineItem 
            WHERE OpportunityId = :opportunityId 
            ORDER BY CreatedDate
        ];
        
        // Assign sequence numbers to ALL line items (including those without Quest IDs)
        for (Integer i = 0; i < allLineItems.size(); i++) {
            lineItemToSequenceMap.put(allLineItems[i].Id, i + 1);
        }
        
        return lineItemToSequenceMap;
    }  
}