//************************
// Created/Deployment Date: 21th July 2025	
// Created by: Dotsolved Development team	
// Jira Ticket # : 196	
// Description: Restrict Finance user to upload any files/documents	
// Last Modified Date: 10th August 2025
//************************
trigger triggerOnContentDocumentLink on ContentDocumentLink (before insert) {
    Profile financeProfile = [SELECT Id FROM Profile WHERE Name = 'Finance' LIMIT 1];

    for (ContentDocumentLink cdl : Trigger.new) {
        if (UserInfo.getProfileId() == financeProfile.Id) {
            cdl.addError('You are not allowed to upload files');
        }
    }
}