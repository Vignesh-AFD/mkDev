public class SendStalledOpportunityEmailBatch implements Database.Batchable<sObject>, Database.Stateful{
    private String soqlQuery;
    private Map<Id, List<Opportunity>> ownerToOpportunitiesMap = new Map<Id, List<Opportunity>>();
    
    public SendStalledOpportunityEmailBatch(String queryOverride) {
        this.soqlQuery = queryOverride;
    }
    
    public SendStalledOpportunityEmailBatch() {
        this.soqlQuery = 'SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, Owner.FirstName, ' +
            'Owner.LastName, StageName, LastStageChangeInDays, RecordType.Name ' +
            'FROM Opportunity ' +
            'WHERE LastStageChangeInDays >= 90 AND StageName = \'Stalled\' AND RecordType.Name = \'Global Partnership\' ' +
            'ORDER BY Owner.Name';
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator(soqlQuery);
    }
    
    public void execute(Database.BatchableContext bc, List<Opportunity> scope){
        for (Opportunity opp : scope) {
            if (!ownerToOpportunitiesMap.containsKey(opp.OwnerId)) {
                ownerToOpportunitiesMap.put(opp.OwnerId, new List<Opportunity>());
            }
            ownerToOpportunitiesMap.get(opp.OwnerId).add(opp);
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        String salesforceBaseURL = URL.getOrgDomainUrl().toExternalForm();
        Id emailTemplateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Stalled_Opportunity_Email_Template' LIMIT 1].Id;
        
        for (Id ownerId : ownerToOpportunitiesMap.keySet()) {
            List<Opportunity> oppList = ownerToOpportunitiesMap.get(ownerId);
            
            String ownerEmail = oppList[0].Owner.Email;
            String ownerFirstName = oppList[0].Owner.FirstName;
            String ownerLastName = oppList[0].Owner.LastName;
            
            if (String.isBlank(ownerEmail)) {
                continue;
            }
            
            String opportunityLinks = '<ul>';
            for (Opportunity opp : oppList) {
                opportunityLinks += '<li><a href="' + salesforceBaseURL + '/' + opp.Id + '">' + opp.Name + '</a></li>';
            }
            opportunityLinks += '</ul>';
            
            String emailBody = '<html><body>';
            emailBody += 'Hi ' + ownerFirstName + ' ' + ownerLastName + ',<br><br>';
            emailBody += 'This notification is to remind you that the following opportunities have remained in the ‘Stalled’ status for 90 days or more as of today:<br><br>';
            emailBody += '<strong>Opportunities:</strong>';
            emailBody += opportunityLinks;
            emailBody += '<br>Please reconnect with the client and/or update these opportunities to closed/lost if there is no new traction.<br><br>';
            emailBody += 'Thanks,<br>';
            emailBody += 'Salesforce Team';
            emailBody += '</body></html>';
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
         /*   email.setTemplateId(emailTemplateId); 
            email.setTargetObjectId(ownerId); 
            email.setSaveAsActivity(false); 
            Map<String, Object> dynamicMergeFields = new Map<String, Object>{
                'Opportunity_List_HTML' => opportunityLinks
                    };
                        email.setParamMap(dynamicMergeFields);*/
            email.setToAddresses(new List<String>{ownerEmail});
            email.setCcAddresses(new List<String>{'nandini.tiwari@discordapp.com'});
            email.setSubject('Daily Reminder: Opportunities in ‘Stalled’ Status for 90+ Days');
            email.setHtmlBody(emailBody);
            
            
            emails.add(email);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}