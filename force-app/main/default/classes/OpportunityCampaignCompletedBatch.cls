global class OpportunityCampaignCompletedBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, StageName
            FROM Opportunity
            WHERE End_Date__c <= :Date.today()
            AND StageName = 'P5: Signed/Won'
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        for(Opportunity opp : scope) {
            opp.StageName = 'Campaign Completed';
        }
        if(!scope.isEmpty()) {
            update scope;
        }
    }

    global void finish(Database.BatchableContext BC) {

    }
}