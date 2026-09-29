//**********************		
// Created/Deployment Date: 6th Oct 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 290,283,276,375,287,387	
// Description: To sync with Asana from OLI		
// Last Modified Date: 3rd Oct 2025		
//***********************	
public class AsanaUpdateTaskNameQueueable implements Queueable, Database.AllowsCallouts {
    
    // ENHANCED wrapper class
    public class LineItemStageWrapper {
        public String taskGid;
        public String opportunityName;
        public String assigneeGid;        
        public String accountManagerEmail; 
        public Id lineItemId;
        public Id oppId;                  

        public LineItemStageWrapper(String taskGid, String opportunityName, String assigneeGid, 
                                   String accountManagerEmail, Id lineItemId, Id oppId) {
            this.taskGid = taskGid;
            this.opportunityName = opportunityName;
            this.assigneeGid = assigneeGid;
            this.accountManagerEmail = accountManagerEmail;
            this.lineItemId = lineItemId;
            this.oppId = oppId;
        }
    }
    
    public List<LineItemStageWrapper> updates;
    
    public AsanaUpdateTaskNameQueueable(List<LineItemStageWrapper> updates) { 
        this.updates = updates;
    }
    
    public void execute(QueueableContext context) { 
        List<Error_Log__c> logs = new List<Error_Log__c>();

        for (LineItemStageWrapper updateRecord : updates) {
            System.debug('Processing update - TaskGID: ' + updateRecord.taskGid + 
                        ' | New Name: ' + updateRecord.opportunityName +
                        ' | AssigneeGID: ' + updateRecord.assigneeGid +
                        ' | AccountManagerEmail: ' + updateRecord.accountManagerEmail);
            
            Error_Log__c updateLog = AsanaIntegrationHandler.updateAsanaTaskName(
                updateRecord.taskGid,
                updateRecord.opportunityName,
                updateRecord.assigneeGid,
                updateRecord.accountManagerEmail,
                updateRecord.lineItemId,
                updateRecord.oppId
            );
            
            // CHANGED: Only add to logs if the task name update FAILED
            if (updateLog.Status__c == AsanaIntegrationHandler.STATUS_FAILURE) {
                logs.add(updateLog);
            }
            // For successful task name updates, don't create any log
        }

        if (!logs.isEmpty()) {
            insert logs;
        }
    }
}