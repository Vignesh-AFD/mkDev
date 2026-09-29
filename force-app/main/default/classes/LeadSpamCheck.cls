//**************************************************************
// Created/Deployment Date: 25th August 2025		
// Created by: Dotsolved Development team
// Jira Ticket # : DISCORD -356, SF-308
// Description: Check if given Leads contain spam in their email or name.
//              If spam is found: - Assign to Disqualified Queue
//              				  - Populate Unqualified_Reason__c	
// Last Modified Date: 11th May 2026			
//*****************************************************************
public class LeadSpamCheck {
    
    public static List<Lead> checkForSpam(List<Lead> leadList){
        // main list leadList
        Map<Id,List<String>> leadvsReasonofSpam = new Map<Id,List<String>>();
        
        // Sets to hold spam keywords
        Set<String> spamWords   = new Set<String>();
        
        // Query spam rules from Custom Metadata
        Spam_Check__mdt[] spamCheckmdt = [
            SELECT MasterLabel, Check_Value__c 
            FROM Spam_Check__mdt
        ];
        
        // Populate spam sets
        for(Spam_Check__mdt record: spamCheckmdt) {
            spamWords.add(record.Check_Value__c.toLowerCase());
        }
        
        // New list for only non-spam leads
        List<Lead> nonSpamLeads = new List<Lead>();
        
        // Iterate over leads
        for(Lead l: leadList){
            Boolean isSpam = false;
            List<String> spamFields = new List<String>();
            
            // --------------------
            // Email spam check
            // --------------------
            if(String.isNotBlank(l.Email)){
                List<String> emailParts = l.Email.split('@');
                if (emailParts.size() > 1) {
                    String domainName = emailParts[1].toLowerCase();
                    String firstEmailName =  emailParts[0].toLowerCase();
                    for(String s: spamWords){
                        if(domainName.contains(s) || firstEmailName.contains(s)){
                            isSpam = true;
                            
                            if(!leadvsReasonofSpam.containsKey(l.Id)){
                                leadvsReasonofSpam.put(l.Id, new List<String>());
                            }
                            leadvsReasonofSpam.get(l.Id).add('Email');
                            //leadvsReasonofSpam.put(l.id, spamFields.add('Email'));
                            break;
                        }   
                    }
                }
            }
            
            // --------------------
            // Name spam check
            // --------------------
            if((String.isNotBlank(l.FirstName) || String.isNotBlank(l.LastName))){
                for(String sname: spamWords){
                    system.debug('sname ==> '+sname);
                    if((l.FirstName != null && l.FirstName.toLowerCase().contains(sname)) ||
                       (l.LastName != null && l.LastName.toLowerCase().contains(sname))) {
                           isSpam = true;
                           if(!leadvsReasonofSpam.containsKey(l.Id)){
                               leadvsReasonofSpam.put(l.Id, new List<String>());
                           }
                           leadvsReasonofSpam.get(l.Id).add('Name');
                        //leadvsReasonofSpam.put(l.id, spamFields.add('Name'));
                        break;
                    }
                }
            }
            
            // --------------------
            // Company spam check
            // --------------------
            if(String.isNotBlank(l.Company)){
                for(String sCompany: spamWords){
                    if(l.Company.toLowerCase().contains(sCompany)) {
                        isSpam = true;
                        if(!leadvsReasonofSpam.containsKey(l.Id)){
                            leadvsReasonofSpam.put(l.Id, new List<String>());
                        }
                        leadvsReasonofSpam.get(l.Id).add('Company Name');
                        //leadvsReasonofSpam.put(l.id, spamFields.add('Company Name'));
                        break;
                    }
                }
            }
            
            // --------------------
            // Assign Owner / Collect for return
            // --------------------
            if(isSpam){
                if (l.Form_Type__c == 'Ad Sales') l.RecordTypeId = System.Label.Lead_Record_Type_ID_Ad_Sales;	
                else if (l.Form_Type__c == 'Dev Solutions') l.RecordTypeId = System.Label.Lead_Record_Type_ID_Dev_Solutions;	
                
                l.OwnerId = System.Label.Disqualified_Queue;
                l.Unqualified_Reason__c = String.join(leadvsReasonofSpam.get(l.Id), ' / ') + ' contains spam word(s)';
                l.is_Spam_Lead__c = true;
                
                l.Rating = 'Cold';
                l.lead_Score__c = Integer.valueOf(System.Label.Disqualified_Countries_Score);
                // Don’t add spam leads to nonSpamLeads
            } else {
                nonSpamLeads.add(l);
            }
        }
        
        // return only clean leads for further processing
        return nonSpamLeads;
    }
}