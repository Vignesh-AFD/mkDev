//**********************		
// Created/Deployment Date: 6th Oct 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 290,283,276,375,287,387	
// Description: To sync with Asana from OLI		
// Last Modified Date: 3rd Oct 2025		
//***********************	
public class AsanaUpdateTaskStageQueueable implements Queueable, Database.AllowsCallouts {
    public class LineItemStageWrapper { 
        public String taskGid;
        public String stageName;
        public Id lineItemId;
        public String opportunityName;
        public Decimal opportunityAmount;
        public String accountManager;
        public String dealOwner;
        public String updateType; // 'stage', 'fields'
        
        // Constructor for stage updates (existing)
        public LineItemStageWrapper(String taskGid, String stageName, Id lineItemId) {
            this.taskGid = taskGid;
            this.stageName = stageName;
            this.lineItemId = lineItemId;
            this.updateType = 'stage';
        }
        
        // Constructor for field updates
        public LineItemStageWrapper(String taskGid, Id lineItemId, String updateType, 
                                   String opportunityName, Decimal opportunityAmount, 
                                   String accountManager, String dealOwner) {
            this.taskGid = taskGid;
            this.lineItemId = lineItemId;
            this.updateType = updateType;
            this.opportunityName = opportunityName;
            this.opportunityAmount = opportunityAmount;
            this.accountManager = accountManager;
            this.dealOwner = dealOwner;
        }
    }

    private List<LineItemStageWrapper> updates;
    public AsanaUpdateTaskStageQueueable(List<LineItemStageWrapper> updates) {
        this.updates = updates;
    }

    public void execute(QueueableContext context) {
        List<Error_Log__c> logs = new List<Error_Log__c>();

        for (LineItemStageWrapper u : updates) {
            if (u.updateType == 'stage') {
                // CHANGED: Only log failures for stage updates
                Error_Log__c stageLog = AsanaIntegrationHandler.updateAsanaTaskStage(u.taskGid, u.stageName, u.lineItemId);
                
                // Only add to logs if the stage update FAILED
                if (stageLog.Status__c == AsanaIntegrationHandler.STATUS_FAILURE) {
                    logs.add(stageLog);
                }
            } else if (u.updateType == 'fields') {
                // CHANGED: Only log failures for field updates
                Error_Log__c fieldUpdateLog = AsanaIntegrationHandler.updateAsanaTaskFields(u.taskGid, u.lineItemId, u.opportunityName, u.opportunityAmount, u.accountManager, u.dealOwner);
                
                // Only add to logs if the field update FAILED
                if (fieldUpdateLog.Status__c == AsanaIntegrationHandler.STATUS_FAILURE) {
                    logs.add(fieldUpdateLog);
                }
            }
        }

        if (!logs.isEmpty()) {
            insert logs;
        }
    }
}