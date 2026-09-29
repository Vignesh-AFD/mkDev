//**********************		
// Created/Deployment Date: 28th July 2025		
// Created by: Dotsolved Development team		
// Jira Ticket # : 212, 223, 336, 341, 370, 372, SF-308, SF-369
// Description: to assign record type for hubspot form leads, queue assginment, Company Name Match		
// Last Modified Date: 11th May 2026		
//***********************		
public class LeadBeforeTriggerHandler {		
    
    // MK - 25June2026 - Cache: Country based scoring metadata
    private static Map<String, Country_Based_Scoring__mdt> countryScoringMap;
    
    // MK - 25June2026 - Cache: region → list of its score-band queue rows
    private static Map<String, List<Ad_Sales_Region_Based_Queues__mdt>> regionBasedQueuesMdt; //getRegionBasedQueueMdt
    
    // this method is to process newly inserted leads		
    public static void processBeforeInsertLeads(List<Lead> leads) {		
        //check spam - pass leads - return list
        List<Lead> cleanLeads = LeadSpamCheck.checkForSpam(leads);
        
        // Pass cleanLeads to your main business logic
        if(!cleanLeads.isEmpty()){
            Map<String, List<Lead>> companyToLeadsMap = new Map<String, List<Lead>>();		
            List<Lead> leadsToProcess = new List<Lead>();		
            
            List<Account> accountsToProcess = New List<Account>();		
            Set<String> emailDomains = New Set<String>();		
            
            // Define set of restricted countries		
            Set<String> disqualifiedCountriesSet = convertLabelToSet(System.Label.Disqualified_Countries_for_Lead);		
            
            for (Lead lead : cleanLeads) {	
                system.debug('New Lead Country ==> '+lead.Country);
                system.debug('New Lead Country Code ==> '+lead.CountryCode);
                
                // 1. recordtype assignment		
                if (lead.Form_Type__c == 'Ad Sales') {		
                    lead.RecordTypeId = System.Label.Lead_Record_Type_ID_Ad_Sales;		
                    System.debug('lead.RecordTypeId ==> Ad Sales');		
                } else if (lead.Form_Type__c == 'Dev Solutions') {		
                    lead.RecordTypeId = System.Label.Lead_Record_Type_ID_Dev_Solutions;		
                    System.debug('lead.RecordTypeId ==> Dev Solutions');
                }	
                
                // 2. Disqualified country check	
                // MK - 25June2026 - redesigning the logic from custom label to custom Metadata types	
                //if (!String.isBlank(lead.Country) && disqualifiedCountriesSet.contains(lead.Country.trim().toLowercase())) {		
                if(isDisqualified(lead.CountryCode)){
                    lead.Lead_Score__c = Integer.valueof(System.Label.Disqualified_Countries_Score);
                    lead.Rating = 'Cold';
                    lead.OwnerId = System.Label.Disqualified_Queue;	
                    System.debug('Lead from Disqualified Country, assigned to Disqualified Queue');		
                }
                // 3. get email domains and leads for next steps	
                else {	
                    if (String.isNotBlank(lead.Company)) {		
                        String company = lead.Company.trim();		
                        system.debug('>>>>>>>company is '+company);		
                        
                        // add company to companyToLeadsMap	even when created from UI and Form_Type__c is blank	
                        if (!companyToLeadsMap.containsKey(company)) {		
                            companyToLeadsMap.put(company, new List<Lead>());		
                        }		
                        companyToLeadsMap.get(company).add(lead);		
                    }		
                    // add current lead's email domain in set		
                    emailDomains.add(getEmailDomain(lead.Email));		
                    leadsToProcess.add(lead);		
                }		
            }		
            system.debug('companyToLeadsMap ==> '+companyToLeadsMap.keySet());		
            
            // 4. process matching email domains and matching accounts		
            if (!companyToLeadsMap.isEmpty()) { // && !companyToLeadsMap.isEmpty()		
                // get SOQL query of companyToLeadsMap.KeySet() & emailDomains		
                accountsToProcess = getAllInvolvedAccounts(companyToLeadsMap.KeySet(),emailDomains);		
                system.debug('accountsToProcess ==> '+accountsToProcess);		
                
                // Perform matching email domain		
                matchEmailDomain(leadsToProcess, accountsToProcess);		
                
                // Perform matching account lookup  		
                matchAccountsAndUpdate(companyToLeadsMap, accountsToProcess, null);		
            }		
            // 5. process the leads for scoring and queue assignment		
            processAllLeadsForScoringAndAssignment(leadsToProcess, null);
            system.debug('leadsToProcessline66>>>'+leadsToProcess);
        }
    }		
    // this method is to process existing leads on update		
    public static void processBeforeUpdateLeads(List<Lead> leads, Map<Id, Lead> oldMap){ 
        system.debug('inside processBeforeUpdateLeads method');		
        
        Set<String> disqualifiedCountriesSet = convertLabelToSet(System.Label.Disqualified_Countries_for_Lead);		
    	Set<String> changedEmailDomains = new Set<String>();	
        List<Account> accountsToProcess = New List<Account>();		
        List<Lead> leadsToProcessEmailChange = New List<Lead>();		
        Map<String, List<Lead>> companyToLeadsMap = new Map<String, List<Lead>>();		
        List<Lead> leadsToProcess = New List<Lead>();		
		
        for (Lead lead : leads) {	
            system.debug('New Lead Country ==> '+lead.Country + ', CountryCode ==> '+lead.CountryCode);
            Lead oldLead = oldMap.get(lead.Id);	
            system.debug('Old Lead Country & code ==> '+oldLead.Country + ', CountryCode ==> '+lead.CountryCode);
            
            // 1. Check if the lead is SPAM
            if (lead.is_Spam_Lead__c == true){
                continue;
            }
            
            // 2. Disqualified country check	
            // // MK - 25June2026 - redesigning the logic from custom label to custom Metadata types	
            if(isDisqualified(lead.CountryCode)){	
            //if (!String.isBlank(lead.Country) && disqualifiedCountriesSet.contains(lead.Country.trim().toLowerCase())) {		
                lead.Lead_Score__c = Integer.valueof(System.Label.Disqualified_Countries_Score);		
                lead.OwnerId = System.Label.Disqualified_Queue;		
                continue; // skip rest of logic for disqualified leads		
            }
            
            // 3. flipping recordtype id and assign to Cross Sell queue 
            if (!String.isBlank(lead.Form_Type__c) && !String.isBlank(oldLead.Form_Type__c) && lead.Form_Type__c <> oldLead.Form_Type__c) {	
                Boolean flipped = false;
                if(lead.Form_Type__c == 'Ad Sales' && lead.RecordTypeId <> System.Label.Lead_Record_Type_ID_Ad_Sales){
                    flipped = true;
                    lead.RecordTypeId = System.Label.Lead_Record_Type_ID_Ad_Sales;		
                	System.debug('lead.RecordTypeId ==> Ad Sales');
                }else if(lead.Form_Type__c == 'Dev Solutions' && lead.RecordTypeId <> System.Label.Lead_Record_Type_ID_Dev_Solutions){
                    flipped = true;
                    lead.RecordTypeId = System.Label.Lead_Record_Type_ID_Dev_Solutions;		
                	System.debug('lead.RecordTypeId ==> Dev Solutions');
                }
                if(flipped){ 
                    lead.Rating = 'Cold';
                    lead.Lead_Score__c = Integer.valueOf(System.Label.Disqualified_Countries_Score); // run scoring based on recordtype id even if in cross sell queue
                    lead.is_Cross_Sell__c = true;
                    lead.OwnerId = System.Label.Cross_Sell_Queue; 
                    System.debug('Assigning to Cross sell queue');
                    //continue;
                }
            }else if(lead.OwnerId == System.Label.Cross_Sell_Queue){ // No account match check, lead scoring, etc., if in cross sell queue
                system.debug('Cross Sell queue - else if');
                /* // run scoring based on recordtype id even if in cross sell queue
                if(!String.isBlank(lead.Rating)) lead.Rating = '';
                if(lead.Lead_Score__c <> null) lead.Lead_Score__c = null;*/
            }
            
            // 4. company change and email change check(s)	
            if(lead.Company != oldLead.Company || lead.Email != oldLead.Email){		
                // Company change check		
                if (lead.Company != oldLead.Company) {		
                    if(lead.Matching_Account__c <> null) lead.Matching_Account__c = null;		
                    if (!companyToLeadsMap.containsKey(lead.company)) {		
                        companyToLeadsMap.put(lead.company, new List<Lead>());		
                    }		
                    companyToLeadsMap.get(lead.company).add(lead);		
                }		
                		
                // Email change check		
                if (lead.Email != oldLead.Email) {		
                    String emailDomain = getEmailDomain(lead.Email);		
                    changedEmailDomains.add(emailDomain);		
                    leadsToProcessEmailChange.add(lead);		
                }		
            }		
            leadsToProcess.add(lead);		
        }		
        		
        // 5. company matching and domain matching		
        if (!companyToLeadsMap.isEmpty() || !changedEmailDomains.isEmpty()) {		
            // get SOQL query of changedCompanies & changedEmailDomains		
            accountsToProcess = getAllInvolvedAccounts(companyToLeadsMap.KeySet(),changedEmailDomains);		
            system.debug('accountsToProcess ==> '+accountsToProcess);		
            		
            // Perform matching email domain		
            matchEmailDomain(leadsToProcessEmailChange, accountsToProcess);		
            		
            // perform company change leads		
            matchAccountsAndUpdate(companyToLeadsMap, accountsToProcess, oldMap);		
        }		
        // 6. process the leads for scoring and queue assignment		
        processAllLeadsForScoringAndAssignment(leadsToProcess, oldMap);		
    }		
    // to get all the matching accounts to process company match and email domain match		
    private static List<Account> getAllInvolvedAccounts(Set<String> companyNames, Set<String> emailDomains){		
        List<String> likeCompanyClauses = New List<String>();  		
        List<String> likeDomainClauses = New List<String>(); 		
        String likeClausesFinal = '';		
        List<Account> results = New List<Account>();		
        		
        for (String company : companyNames) {   // preparing like clause using company names		
            likeCompanyClauses.add('Name LIKE \'' + String.escapeSingleQuotes(company) + '%\''); 		
        }		
        for (String domain : emailDomains) {   // preparing like clause using email domains		
            likeDomainClauses.add('Website LIKE \'%' + String.escapeSingleQuotes(domain) + '%\''); 		
        } 		
        		
        // concatenating the like clauses		
        if(!likeCompanyClauses.isEmpty() && !likeDomainClauses.isEmpty()){		
            likeClausesFinal = String.join(likeCompanyClauses, ' OR ' ) + ' OR ' + String.join(likeDomainClauses, ' OR ' );		
            system.debug('likeCompanyClauses & likeDomainClauses are not empty');		
        }else if(likeCompanyClauses.isEmpty()){		
            likeClausesFinal = String.join(likeDomainClauses, ' OR ' );		
            system.debug('likeCompanyClauses is not empty');		
        }else if(likeDomainClauses.isEmpty()){		
            likeClausesFinal = String.join(likeCompanyClauses, ' OR ' );		
            system.debug('likeDomainClauses is not empty');		
        }else{		
            system.debug('both like clauses are empty');		
            return results;		
        }		
            		
        String queryString = 'SELECT Id, Name, Website, OwnerId, ParentId, Parent.Name, '		
            + 'Sales_Account_Executive__c,Sales_Account_Executive__r.isActive, Dev_Solutions_Lead__c, Dev_Solutions_Lead__r.isActive '		
            + 'FROM Account WHERE '  		
            + likeClausesFinal; 		
        system.debug('queryString ==> '+queryString);   		
        		
        List<Account> matchedAccounts = Database.query(queryString);		
        if(matchedAccounts.size() > 0){		
            results = matchedAccounts;		
        }		
        return results;		
    }		
    // this method is to check and update if email domain exists		
    private static void matchEmailDomain(List<Lead> incomingLeads, List<Account> accountsToProcess) {	
         system.debug('inside matchEmailDomain ==> ');	
        // get all Account websites		
        Set<String> accountWebsites = new Set<String>();		
        if (accountsToProcess != null) {		
            for (Account acc : accountsToProcess) {		
                if(acc.Website != null && acc.Website != ''){		
                    accountWebsites.add(acc.Website.toLowerCase());		
                }		
            }		
        }else{		
            return;		
        }		
        system.debug('accountWebsites ==> '+accountWebsites);		
        		
        // Prepare list of leads to update		
        for (Lead lead : incomingLeads) {		
            Boolean domainExists = false;		
            String domain = getEmailDomain(lead.Email); 		
            system.debug('domain ==> '+domain);		
            if (domain != null) {		
                for (String website : accountWebsites) {		
                    if (website.contains(domain)) {		
                        domainExists = true;		
                        break;		
                    }		
                }		
            }		
            lead.Email_Domain_Exists__c = domainExists;		
        }		
    }		
    // this method is to process Account matching/non matching leads, calling scoring and assignment methods		
    private static void matchAccountsAndUpdate(Map<String, List<Lead>> companyToLeadsMap, List<Account> accountsToProcess, Map<Id, Lead> oldMap) {		
        system.debug('Inside matchAccountsAndUpdate method');		
        if (companyToLeadsMap.isEmpty()) {		
            system.debug('companyToLeadsMap.isEmpty()');		
            return;		
        }		
        // process leads with matching/non-matching account names		
        Map<String, List<Account>> companyToAccountsMap = new Map<String, List<Account>>();		
        for (String company : companyToLeadsMap.KeySet()) { 		
            system.debug('current company name ==> '+company);		
            if (accountsToProcess != null) {		
                for (Account acc : accountsToProcess) { 		
                    if (acc.Name != null && acc.Name.toLowerCase().contains(company.toLowerCase())) {		
                        system.debug('matching company name ==> '+company);		
                        if (!companyToAccountsMap.containsKey(company)) {		
                            companyToAccountsMap.put(company, new List<Account>());		
                        }		
                        companyToAccountsMap.get(company).add(acc);		
                        system.debug('companyToAccountsMap ==> '+companyToAccountsMap);		
                    }		
                }		
            }		
        }		
        		
        // process account name matching leads		
        for (String company : companyToAccountsMap.keySet()) {		
            system.debug('Inside for loop companyToAccountsMap.keySet()');		
            List<Lead> leadsForCompany = companyToLeadsMap.get(company);		
            List<Account> accounts = companyToAccountsMap.get(company);		
            		
            for (Lead lead : leadsForCompany) {		
                system.debug('Inside for loop leadsForCompany');		
                if (accounts != null && !accounts.isEmpty()) {		
                    Account matchedAcc = null;	
                    // Case 1: Only 1 account found in wildcard search
                    if (accounts.size() == 1) {		
                        // check for 75% match, if yes, return partially matched account, else ignore		
                        if(isPartiallyMatchingAccountExists(company, accounts[0].Name) >= 75){		
                            matchedAcc = accounts[0];
                            System.debug('partial/single match found ==> '+matchedAcc.Name);
                        }		
                    } 
                    // Case 2: Multiple accounts found in wildcard search
                    else {	
                        Boolean exactMatchFound = false;
                        for (Account acc : accounts) {		
                            if (acc.Name.equalsIgnoreCase(company)) {		
                                matchedAcc = acc;
                                exactMatchFound = true;
                                system.debug('exact Match Found ==> '+matchedAcc.Name);
                                break;		
                            }		
                        }
                    }		
                    // update matching account id and lead owner from the matching account		
                    if (matchedAcc != null) {		
                        lead.Matching_Account__c = matchedAcc.Id;		
                        Boolean isupdated = checkIfOwnerAssignedAlready(lead, oldMap);		
                        if(isupdated == FALSE){		
                            system.debug('isupdated == FALSE');		
                            if (lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Ad_Sales && matchedAcc.Sales_Account_Executive__c != null && matchedAcc.Sales_Account_Executive__r.isActive) {		
                                system.debug('Setting Sales Account Executive as owner');		
                                lead.OwnerId = matchedAcc.Sales_Account_Executive__c;		
                            } else if (lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Dev_Solutions && matchedAcc.Dev_Solutions_Lead__c != null && matchedAcc.Dev_Solutions_Lead__r.isActive) {		
                                system.debug('Setting Dev Solution Lead as owner');		
                                lead.OwnerId = matchedAcc.Dev_Solutions_Lead__c;		
                            }		
                        }		
                    }		
                }		
            }		
        }		
    }		
    
    // process all leads for scoring and queue assignment		
    private static void processAllLeadsForScoringAndAssignment(List<Lead> leadsToProcess, Map<Id, Lead> oldMap) {		
        if (leadsToProcess.isEmpty()) {		
            return;		
        }
        
        // get personal domains, email domains, metadata to process		
		Set<String> personalDomains = convertLabelToSet(System.label.Personal_Email_Domains);
        Map<Id, Lead_Scoring__mdt> adSalesMDT = New Map<Id, Lead_Scoring__mdt>([SELECT Id, Form_Type__c, Field_Name__c, Field_Value__c, Score__c FROM Lead_Scoring__mdt Where Form_Type__c = 'Ad Sales']);
        Map<Id, Lead_Scoring__mdt> devSolutionsMDT = New Map<Id, Lead_Scoring__mdt>([SELECT Id, Form_Type__c, Field_Name__c, Field_Value__c, Score__c FROM Lead_Scoring__mdt Where Form_Type__c = 'Dev Solutions']);
        Map<String, String> countryCodeToRegionMap = getCountryCodeToRegionMap();
        Map<String, List<Ad_Sales_Region_Based_Queues__mdt>> regionBasedQueuesMdt = getRegionBasedQueuesMdt();
        
        // MK - 25June2026 - deprecating the below collections with different logic
        //Set<String> highScoreCountries = convertLabelToSet(System.Label.High_Score_Countries); 
        //Set<String> mediumScoreCountries = convertLabelToSet(System.Label.Medium_Score_Countries); 
        //Map<String, String> regionToQueueMap = getRegionToQueueMap();
		//Set<String> adSalesRegionsSet = new Set<String>(); //getRegionValues();
        //Map<String, String> leadQueuesMap = getLeadQueueMap();
        
        //Current_Lead_Form_Names - MK - 08May2026 - commenting the below line of code as we moving to recordtype based scoring.
        //Set<String> currentFormNames = convertLabelToSet(System.label.Current_Lead_Form_Names);
        
        for (Lead lead : leadsToProcess) {	
            // Assign queue only if an owner has not been assigned already and the `checkIfOwnerAssignedAlready` method will handle if a user or queue is already assigned.		
            Boolean assignedAlready = (oldMap != null) ? checkIfOwnerAssignedAlready(lead, oldMap) : checkIfOwnerAssignedAlready(lead, New Map<Id, Lead>());		
            System.debug('assignedAlready ==> '+assignedAlready);
            
            /*String formNameToProcess = getFormNameToProcess(lead, currentFormNames);
            // assign leads based on formNameToProcess	
            if (!String.isBlank(formNameToProcess) && formNameToProcess.toLowerCase().contains(System.Label.TOFU_Form_Name.toLowerCase())){		
                toFuFormScoringAndAssignment(lead, assignedAlready, devSolutionsMDT, personalDomains, highScoreCountries, mediumScoreCountries);
            }else if (!String.isBlank(formNameToProcess) && formNameToProcess.toLowerCase().contains(System.Label.Ad_Sales_Form_Name.toLowerCase())){		
                adSalesFormScoringAndAssignment(lead, assignedAlready, adSalesMDT, personalDomains, highScoreCountries, mediumScoreCountries);
            }else{
                system.debug('assignLeadstoQueues method call');
                assignLeadstoQueues(lead, assignedAlready);
            }*/	

            if (lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Ad_Sales){		
                // MK - 25June2026 - reducing the old method parameters to exclude highScoreCountries and mediumScoreCountries
                adSalesFormScoringAndAssignment(lead, assignedAlready, adSalesMDT, personalDomains, countryCodeToRegionMap);
            	//adSalesFormScoringAndAssignment(lead, assignedAlready, adSalesMDT, personalDomains, highScoreCountries, mediumScoreCountries, countryCodeToRegionMap);
            }else if (lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Dev_Solutions){		
                // MK - 25June2026 - reducing the old method parameters to exclude highScoreCountries and mediumScoreCountries
                devSolutionsScoringAndAssignment(lead, assignedAlready, devSolutionsMDT, personalDomains);
                //devSolutionsScoringAndAssignment(lead, assignedAlready, devSolutionsMDT, personalDomains, highScoreCountries, mediumScoreCountries);
            }/*else{
                system.debug('assignLeadstoQueues method call');
                assignLeadstoQueues(lead, assignedAlready);
            }*/
        }		
    }
    // check if the lead is already assigned or not		
    private static Boolean checkIfOwnerAssignedAlready(Lead lead, Map<Id, Lead> oldMap){		
        Boolean result = FALSE;		
        Set<String> hubspotIds = convertLabelToSet(System.Label.Hubspot_Integration_User_ID);		
        system.debug('lead.CreatedById ==>'+lead.CreatedById);		
        system.debug('UserInfo.getUserId() ==>'+UserInfo.getUserId());		
        system.debug('lead.ownerId ==>'+lead.OwnerId);		
        if(oldMap == null || oldMap.isEmpty()){		
            if(!hubspotIds.contains(lead.OwnerId)){ 
                system.debug('New record created: '+lead.OwnerId);		
                result = TRUE; // --> assigned already		
            }		
        }else {		
            system.debug('OwnerID from oldMap ==>'+oldMap.get(lead.Id).OwnerId);		
        	if(String.ValueOf(oldMap.get(lead.Id).OwnerId).StartsWith('005') 
               || lead.OwnerId == System.Label.Cross_Sell_Queue
               || lead.OwnerId <> OldMap.get(lead.Id).OwnerId){	
                result = TRUE;		
            }		
        }		
        system.debug('checkIfOwnerAssignedAlready returns == '+result);		
        return result;		
    } 	
    // returns TRUE if the partially matching account has 75% score, else false		
    private static Decimal isPartiallyMatchingAccountExists(String company, String accountName){		
        Decimal result = 0;		
        long matchingCriteria = 0;		
        if (company <> '' && accountName <> ''){		
            matchingCriteria = (long)(((double)company.length() / accountName.length()) * 100);
            if (matchingCriteria >= 75) result = matchingCriteria;
        }		
        system.debug('matchAccountScore result == '+result);		
        return result;		
    }	
    // this method converts custom label to a Set collection
    private static Set<String> convertLabelToSet(String customLabel){		
        Set<String> result = New Set<String>();		
        if (String.isNotBlank(customLabel)) {		
            List<String> values = customLabel.split(',');		
            for (String value : values) {		
                if(customLabel == System.Label.Hubspot_Integration_User_ID){		
                	result.add(value.trim());	
                }else {		
                    result.add(value.trim().toLowerCase());		
                }		
            }		
        }		
        return result;		
    }
    // get the lead scoring metadata per field api name
    private static Map<String, Decimal> scoringPerField(String fieldAPIName, Map<Id, Lead_Scoring__mdt> leadScoringMDT) {
        Map<String, Decimal> scoreMap = new Map<String, Decimal>();
        
        Schema.SObjectType leadType = Schema.getGlobalDescribe().get('Lead');
        Schema.DescribeSObjectResult leadDescribe = leadType.getDescribe();
        Schema.SObjectField sField = leadDescribe.fields.getMap().get(fieldAPIName);
        Schema.DescribeFieldResult fieldDescribe = sField.getDescribe();

        if(leadScoringMDT.size() > 0){
            for (Lead_Scoring__mdt scoringRecord : leadScoringMDT.values()) {
                if (scoringRecord.Field_Name__c == fieldAPIName) {
                    if(fieldDescribe.getType() == Schema.DisplayType.String){
                        scoreMap.put(scoringRecord.Field_Value__c.toLowerCase(), scoringRecord.Score__c);
                    }else{
                        scoreMap.put(scoringRecord.Field_Value__c, scoringRecord.Score__c);
                    }
                }
            }
        }
        return scoreMap;
    }
    
    /*private static String getFormNameToProcess(Lead lead, Set<String> formNames){
        String result = '';
        if(!String.isBlank(lead.Hubspot_Recent_Conversion__c)){
            result = getFormName(lead.Hubspot_Recent_Conversion__c, formNames);
        }
        if(result == '' && !String.isBlank(lead.Hubspot_First_Submission__c)){
            result = getFormName(lead.Hubspot_First_Submission__c, formNames);
        }
        if(result == '' && !String.isBlank(lead.Lead_Submission_Form__c)){
            result = getFormName(lead.Lead_Submission_Form__c, formNames);
        }
        system.debug('result ==> '+result);
        return result;
    }
    private static String getFormName(String fieldName, Set<String> formNames){
        String result = '';
        if(!String.isBlank(fieldName)){
            for(String fname: formNames){
                if(fieldName.toLowerCase().contains(fname.toLowerCase())){
                    result = fname.toLowerCase();
                    break;
                }
            }
        }
        system.debug('result ==> '+result);
        return result;
    }*/
    // to assign leads to queues when Lead_Submission_Form__c is blank		
    /*private static void assignLeadstoQueues(Lead lead, Boolean assignedAlready){
        system.debug('inside assignLeadstoQueues method');
        // setting null on lead score and rating fields if lead goes to generic queue
        if(lead.Lead_Score__c != null) lead.Lead_Score__c = null;
        if(lead.Rating != '') lead.Rating = '';
        
        if(!assignedAlready){
            if (lead.Form_Type__c == 'Ad Sales') {		
                system.debug('assigning ad sales queue');		
                lead.ownerId = System.Label.Ad_Sales_Queue_ID;		
            }else if(lead.Form_Type__c == 'Dev Solutions' ){		
                system.debug('assigning Dev Solutions queue');		
                lead.ownerId = System.Label.Dev_Solutions_Queue;		
            }else if (lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Ad_Sales) {		
                system.debug('assigning ad sales queue');		
                lead.ownerId = System.Label.Ad_Sales_Queue_ID;		
            }else if(lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Dev_Solutions){		
                system.debug('assigning Dev Solutions queue');		
                lead.ownerId = System.Label.Dev_Solutions_Queue;		
            }
        }		
    }*/		
    // get email domain from lead's email address
    private static String getEmailDomain(String leadEmail){		
        String result = '';		
        if (leadEmail != null) {		
            List<String> emailParts = leadEmail.split('@');		
            if (emailParts.size() > 1) {		
                result = emailParts[1].toLowerCase();		
            }		
        }		
        system.debug('getEmailDomain result: '+result);		
        return result;		
    }
    // get email domain only from lead's email address
    private static String getEmailDomainOnly(String leadEmail){
        String result = '';
        String domain = getEmailDomain(leadEmail);
        if (domain != null) {
            List<String> domainParts = domain.split('\\.');
            if (domainParts.size() > 1) {
                result = domainParts[0].toLowerCase();
            }
        }
        system.debug('getEmailDomainOnly result: '+result);
        return result;
    }
    // get email domain 'endswith' from lead's email address
    private static String getEmailDomianEnding(String leadEmail){
        String result = '';
        String domain = getEmailDomain(leadEmail);
        if (domain != null) {
            List<String> domainParts = domain.split('\\.');
            if (domainParts.size() > 1) {
                result = '.' + domainParts[domainParts.size() - 1].toLowerCase();
            }
        }
        system.debug('getEmailDomianEnding result: '+result);
        return result;
    }
    // process ad sales scoring and queue assignment
    private static void adSalesFormScoringAndAssignment(Lead lead, 
                                                        Boolean assignedAlready, 
                                                        Map<Id, Lead_Scoring__mdt> adSalesMDT, 
                                                        Set<String> personalDomains, 
                                                        /*Set<String> highScoreCountries, 
                                                        Set<String> mediumScoreCountries, */
                                                        Map<String, String> countryCodeToRegionMap){
        system.debug('inside adSalesFormScoringAndAssignment method');
        // run scoring based on recordtype id even if in cross sell queue
        //if(lead.OwnerId != System.Label.Cross_Sell_Queue){
            Decimal currentScore = 0;
            currentScore += companyOrEmailDomainMatchScore(lead, personalDomains);
            currentScore += emailDomainScore(lead, personalDomains);
            //currentScore += countryScore(lead.CountryCode); MK - 25June2026 - deprecaring old country score method
            currentScore += getCountryScore(lead.CountryCode); // MK - 25June2026 - new method to get country score
            System.debug('CountryCode is ' + lead.CountryCode + ', CountryScore is '+getCountryScore(lead.CountryCode));
            
            // get field names from metadata
            Set<String> fieldNames = getFieldNames(adSalesMDT);
            if(adSalesMDT.size() > 0){
                for (String fieldName : fieldNames) {
                    Object rawValue = lead.get(fieldName);
                    String fieldValue = String.valueOf(rawValue); // Convert to string for uniformity
                    System.debug('fieldName => ' + fieldName);
                    System.debug('fieldValue => ' + fieldValue);

                    // Get field describe info
                    Schema.SObjectType leadType = Schema.getGlobalDescribe().get('Lead');
                    Schema.DescribeSObjectResult leadDescribe = leadType.getDescribe();
                    Schema.SObjectField sField = leadDescribe.fields.getMap().get(fieldName);
                    Schema.DescribeFieldResult fieldDescribe = sField.getDescribe();

                    if (fieldName == 'Company_Type__c') {
                        currentScore += companyTypeScore(lead, scoringPerField('Company_Type__c', adSalesMDT));
                    }
                    // MK - 12Jun2026 - adding logic to score based on employee size buckets as defined in the metadata 
                    else if (fieldName == 'NumberOfEmployees' && !String.isBlank(fieldValue)) {
                        //Integer numValue = Integer.valueOf(fieldValue);
                        currentScore += getNoOfEmpScore(Integer.valueOf(fieldValue), adSalesMDT);
                    } else {
                    // Check if field is of type String/Text
                        if (fieldDescribe.getType() == Schema.DisplayType.String) {
                            currentScore += String.isBlank(fieldValue) ? 0 : getScore(fieldValue.toLowerCase(), scoringPerField(fieldName, adSalesMDT));
                        } else {
                            currentScore += getScore(fieldValue, scoringPerField(fieldName, adSalesMDT));
                        }
                    }
                    System.debug('currentScore => ' + currentScore);
                }
            }
            lead.Lead_Score__c = currentScore;
            system.debug('lead.Lead_Score__c ==> '+lead.Lead_Score__c);
            
            // MK - 17Jun2026 - adding logic to assign Rating based on record type
            if(lead.Rating != assignRating(lead)) lead.Rating = assignRating(lead);
            system.debug('lead.Rating ==> '+lead.Rating);
			
            // MK - 15Jun2026 - adding logic to populate region based on country code
			Lead.Region__c = (String.isBlank(lead.CountryCode) || String.isBlank(countryCodeToRegionMap.get(lead.CountryCode))) ? 'RoW' : countryCodeToRegionMap.get(lead.CountryCode);
            system.debug('Lead CountryCode ==> '+lead.CountryCode +', Lead Country ==> '+lead.Country +', lead.Region__c ==> '+lead.Region__c);
            
            // assign/reassign to cross-sell or other queue only if the owner id blank or in another queue
            if(!assignedAlready) assignAdSalesLeadsToQueues(lead); //assignAdSalesLeadsToQueues(lead, leadQueuesMap, regionToQueueMap);
        // }
    }
    
    //***************************************************
    // MK - 15June2026 - below are created for region based routing
    
    // deprecate this method if using getRegionToQueueMap
    /*public static Map<String, String> getLeadQueueMap() {
        Map<String, String> queueMap = new Map<String, String>();
        
        for (QueueSobject qs : [
            SELECT Queue.DeveloperName, Queue.Id, Queue.Name
            FROM QueueSobject
            WHERE SobjectType = 'Lead'
        ]) {
            queueMap.put(qs.Queue.Name, qs.Queue.Id);
        }
        
        return queueMap;
    }*/
    
    public static Map<String, String> getCountryCodeToRegionMap(){
        Map<String, String> countryToRegionMap = new Map<String, String>();
        
        for(Country_Region__mdt cr: [
            SELECT Id, DeveloperName, Country__c, CountryCode__c, Region__c 
            FROM Country_Region__mdt
        ]){
            countryToRegionMap.put(cr.CountryCode__c, cr.Region__c);
        }
        
        return countryToRegionMap;
    }
    
    private static void initializeCountryScoring() {
		// return if countryScoringMap is not null
        if (countryScoringMap != null) return;

        // load country based scoring metadata
        countryScoringMap = new Map<String, Country_Based_Scoring__mdt>();
		for (Country_Based_Scoring__mdt mdt : [SELECT Country_Code__c, Category__c, Score__c FROM Country_Based_Scoring__mdt]) {
            if (!String.isBlank(mdt.Country_Code__c)) {
                countryScoringMap.put(mdt.Country_Code__c.trim().toUpperCase(),mdt);
            }
        }
    }

    public static Boolean isDisqualified(String countryCode) {
		// initialize country scoring metadata
        initializeCountryScoring();

        if (String.isBlank(countryCode)) return false;

        Country_Based_Scoring__mdt mdt = countryScoringMap.get(countryCode.trim().toUpperCase());

        return mdt != null && mdt.Category__c == 'Disqualified';
    }

    public static Decimal getCountryScore(String countryCode) {
		// initialize country scoring metadata
        initializeCountryScoring();

        if (String.isBlank(countryCode)) return 0;

        Country_Based_Scoring__mdt mdt = countryScoringMap.get(countryCode.trim().toUpperCase());

        if (mdt == null || mdt.Category__c == 'Disqualified') {
            return 0;
        }

        return mdt.Score__c == null ? 0 : mdt.Score__c;
    }
    
    /*private static final Decimal HOT_SCORE_THRESHOLD = 40;
	private static Map<String, String> regionRatingToQueueId;
    
    private static Map<String, String> getRegionToQueueMap(){
        if (regionRatingToQueueId == null){
            regionRatingToQueueId = new Map<String, String>();
            
            for(Ad_Sales_Region_Based_Queues__mdt m: Ad_Sales_Region_Based_Queues__mdt.getAll().values()){
                String key = m.Region__c + '|' + m.Rating__c;
                regionRatingToQueueId.put(key, m.Queue_Id__c);
            }
        }
        return regionRatingToQueueId;
    }
    
    private static void assignAdSalesLeadsToQueues(Lead lead) { //Map<String, String> leadQueuesMap, Set<String> adSalesRegionsSet
        System.debug('inside assginAdSalesLeadstoQueues method');
        String ownerId;
        
        if(String.isNotBlank(lead.Region__c)){
            //String rating = (lead.Lead_Score__c <> null && lead.Lead_Score__c >= HOT_SCORE_THRESHOLD) ? 'Hot' : 'Cold';
            String key = lead.Region__c + '|' + lead.Rating; //rating;
            ownerId = getRegionToQueueMap().get(key);
            System.debug('Looking up queue for: ' + key + ' → ' + ownerId);
        }
        
        if(String.isBlank(ownerId)){
            System.debug('Assigning to generic RoW queue');
            if(lead.Lead_Score__c >= HOT_SCORE_THRESHOLD){
                ownerId = getRegionToQueueMap().get('RoW|Hot');
            }else{
                ownerId = getRegionToQueueMap().get('RoW|Cold');
            }
        }
        
        lead.ownerId = ownerId;
    }*/
    
    
    private static Map<String, List<Ad_Sales_Region_Based_Queues__mdt>> getRegionBasedQueuesMdt() {
        if (regionBasedQueuesMdt == null) {
            regionBasedQueuesMdt = new Map<String, List<Ad_Sales_Region_Based_Queues__mdt>>();
            for (Ad_Sales_Region_Based_Queues__mdt m : Ad_Sales_Region_Based_Queues__mdt.getAll().values()) {
                     if (m.Region__c == null) continue;
                     if (!regionBasedQueuesMdt.containsKey(m.Region__c)) {
                         regionBasedQueuesMdt.put(m.Region__c, new List<Ad_Sales_Region_Based_Queues__mdt>());
                     }
                     regionBasedQueuesMdt.get(m.Region__c).add(m);
                 }
        }
        return regionBasedQueuesMdt;
    }
    @TestVisible
    private static void assignAdSalesLeadsToQueues(Lead lead) { //assginAdSalesLeadstoQueues 
        System.debug('inside assignAdSalesLeadsToQueues method');
        
        String ownerId;
        
        if (lead.Region__c != null && lead.Lead_Score__c != null) {
            Decimal score = lead.Lead_Score__c;
            List<Ad_Sales_Region_Based_Queues__mdt> queueList = getRegionBasedQueuesMdt().get(lead.Region__c);
            
            if (queueList != null) {
                for (Ad_Sales_Region_Based_Queues__mdt m : queueList) {
                    if (m.Min_Value__c != null && m.Max_Value__c != null
                        && score >= m.Min_Value__c && score <= m.Max_Value__c) {
                            ownerId = m.Queue_Id__c;
                            System.debug('Matched ' + lead.Region__c + ' / ' + m.Rating__c + ' between [' + m.Min_Value__c + '..' + m.Max_Value__c + '] → ' + ownerId);
                            break;
                        }
                }
            }
        }
        
        if (String.isBlank(ownerId)) {
            System.debug('Assigning to RoW queue');
            ownerId = System.Label.RoW_Queue;
        }
        
        lead.OwnerId = ownerId;
    }
    
    // Cache so describe runs once per transaction, not per lead
    /*private static Set<String> adSalesRegions;
    
    private static Set<String> getRegionValues() {
        if (adSalesRegions == null) {
            adSalesRegions = new Set<String>();
            for (Schema.PicklistEntry entry :
                 Lead.Region__c.getDescribe().getPicklistValues()) {
                     if (entry.isActive()) {
                         adSalesRegions.add(entry.getValue());
                     }
                 }
        }
        return adSalesRegions;
    }

    private static void assignAdSalesLeadsToQueues(Lead lead, Map<String, String> leadQueuesMap, Set<String> adSalesRegionsSet) {
        System.debug('inside assginAdSalesLeadstoQueues method');
        String ownerId;
        
        if (lead.Region__c != null && adSalesRegionsSet.contains(lead.Region__c)) {
            String queueKey = (lead.Lead_Score__c != null && lead.Lead_Score__c >= HOT_SCORE_THRESHOLD)
                ? lead.Region__c
                : lead.Region__c + ' - Cold';
            ownerId = leadQueuesMap.get(queueKey);
            System.debug('Assigning to queue: ' + queueKey);
        }
        
        if (String.isBlank(ownerId)) {
            System.debug('Assigning to generic ad sales queue');
            ownerId = System.Label.Ad_Sales_Queue_ID;
        }
        
        lead.OwnerId = ownerId;
    }*/
    //***************************************************
    
    private static set<String> getFieldNames(Map<Id, Lead_Scoring__mdt> scoringMDT){
        set<String> fieldNames = new set<String>();
        for (Lead_Scoring__mdt mdt : scoringMDT.values()) {
            fieldNames.add(mdt.Field_Name__c);
        }
        system.debug('fieldNames ==> '+fieldNames);
        return fieldNames;
    }
    private static decimal getScore(String fieldValue, Map<String, Decimal> scoringMDT){
        // calculate Studio size score and return
        decimal result = 0;
        system.debug('fieldValue ==> '+fieldValue);
        if (scoringMDT.containsKey(fieldValue)) { 
            result = scoringMDT.get(fieldValue);
        }
        system.debug('scoringMDT result: '+result);
        return result;
    }
    // process Dev Solutions form scoring and queue assignment
    private static void devSolutionsScoringAndAssignment(Lead lead, Boolean assignedAlready, Map<Id, Lead_Scoring__mdt> devSolutionssMDT, Set<String> personalDomains){ /*, Set<String> highScoreCountries, Set<String> mediumScoreCountries*/
        system.debug('inside devSolutionsScoringAndAssignment method');
        
        // run scoring based on recordtype id even if in cross sell queue
        // if(lead.OwnerId != System.Label.Cross_Sell_Queue){
            Decimal currentScore = 0;
            currentScore += companyOrEmailDomainMatchScore(lead, personalDomains);
            currentScore += emailDomainScore(lead, personalDomains);
            //currentScore += countryScore(lead, highScoreCountries, mediumScoreCountries); MK - 25June2026 - deprecaring old country score method
            currentScore += getCountryScore(lead.CountryCode); // MK - 25June2026 - new method to get country score
        	System.debug('CountryCode is ' + lead.CountryCode + ', CountryScore is '+getCountryScore(lead.CountryCode));
            
            Set<String> fieldNames = getFieldNames(devSolutionssMDT);
            if(devSolutionssMDT.size() > 0){
                for (String fieldName : fieldNames) {
                    Object rawValue = lead.get(fieldName);
                    String fieldValue = String.valueOf(rawValue); // Convert to string for uniformity
                    System.debug('fieldName => ' + fieldName);
                    System.debug('fieldValue => ' + fieldValue);

                    // Get field describe info
                    Schema.SObjectType leadType = Schema.getGlobalDescribe().get('Lead');
                    Schema.DescribeSObjectResult leadDescribe = leadType.getDescribe();
                    Schema.SObjectField sField = leadDescribe.fields.getMap().get(fieldName);
                    Schema.DescribeFieldResult fieldDescribe = sField.getDescribe();

                    if (fieldName == 'Player_Communication_Medium__c') {
                        currentScore += playerCommMediumScore(lead, scoringPerField('Player_Communication_Medium__c', devSolutionssMDT));
                    } else if (fieldName == 'Intended_Platforms__c') {
                        currentScore += intendedPlatformScore(lead, scoringPerField('Intended_Platforms__c', devSolutionssMDT));
                    }
                    // MK - 12Jun2026 - adding logic to score based on employee size buckets as defined in the metadata 
                    else if (fieldName == 'NumberOfEmployees' && !String.isBlank(fieldValue)) {
                        //Integer numValue = Integer.valueOf(fieldValue);
                        currentScore += getNoOfEmpScore(Integer.valueOf(fieldValue), devSolutionssMDT);
                    } else {
                    // Check if field is of type String/Text
                        if (fieldDescribe.getType() == Schema.DisplayType.String) {
                            currentScore += String.isBlank(fieldValue) ? 0 : getScore(fieldValue.toLowerCase(), scoringPerField(fieldName, devSolutionssMDT));
                        } else {
                            currentScore += getScore(fieldValue, scoringPerField(fieldName, devSolutionssMDT));
                        }
                    }
                    System.debug('currentScore => ' + currentScore);
                }
            }
            if(lead.Lead_Score__c != currentScore) lead.Lead_Score__c = currentScore;
            system.debug('lead.Lead_Score__c ==> '+lead.Lead_Score__c);
            
            if(lead.Rating != assignRating(lead)) lead.Rating = assignRating(lead);
            system.debug('lead.Rating ==> '+lead.Rating);
            
            // assign/reassign only if the owner id blank or in another queue
            if(!assignedAlready) assignDevSolLeadstoQueues(lead);
        // }
        
    }
    
    public static Decimal getNoOfEmpScore(Integer noOfEmployees, Map<Id, Lead_Scoring__mdt> leadScoreMdt){
        Decimal result = 0;
        Decimal empCount = Integer.valueOf(noOfEmployees);
        if(empCount >= 10 && empCount <= 50){
            result = getScore('10-50', scoringPerField('NumberOfEmployees', leadScoreMdt));
        } else if(empCount >= 51 && empCount < 300){
            result = getScore('51-299', scoringPerField('NumberOfEmployees', leadScoreMdt));
        } else if(empCount >= 300){
            result = getScore('300+', scoringPerField('NumberOfEmployees', leadScoreMdt));
        }
        return result;
    }
    // assign rating based on lead score - MK - 17June2026 - deprecating the old logic
    /*private static String assignRating(Decimal leadScore) {
        system.debug('inside assignRating method');
        //if(lead)
        if (leadScore > 70) return 'Hot';
        else if (leadScore >= 40) return 'Warm';
        else return 'Cold';
    }*/
    // MK - 17Jun2026 (modified date) - assign rating based on Recortype name and lead score
    private static String assignRating(Lead lead) {
        system.debug('inside assignRating method');
        if(lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Dev_Solutions){
            if (lead.lead_Score__c > 70) return 'Hot';
            else if (lead.lead_Score__c >= 40) return 'Warm';
        }else if(lead.RecordTypeId == System.Label.Lead_Record_Type_ID_Ad_Sales){
           return getAdSalesRating(lead);
        }
        return 'Cold';
    }
    
    @TestVisible
    private static String getAdSalesRating(Lead lead) { 
        System.debug('inside assignAdSalesRating method');
        
        String result;
        
        if (lead.Region__c != null && lead.Lead_Score__c != null) {
            Decimal score = lead.Lead_Score__c;
            List<Ad_Sales_Region_Based_Queues__mdt> regionMdtList = getRegionBasedQueuesMdt().get(lead.Region__c);
            
            if (regionMdtList != null) {
                for (Ad_Sales_Region_Based_Queues__mdt m : regionMdtList) {
                    if (m.Min_Value__c != null && m.Max_Value__c != null
                        && score >= m.Min_Value__c && score <= m.Max_Value__c) {
                            result = m.Rating__c;
                            System.debug('Matched ' + lead.Region__c + ' / ' + lead.Lead_Score__c + ' band [' + m.Min_Value__c + '..' + m.Max_Value__c + '] → ' + lead.Rating);
                            break;
                        }
                }
            }
        }
        
        return result;
    }
    
    //Deprecating this method due to region based lead routing on Ad sales leads
    //  assign lead to ad sales queue(s) based on rating
    /*@TestVisible
    private static void assginAdSalesLeadstoQueues(Lead lead){
        system.debug('inside assginAdSalesLeadstoQueues method');
        String ownerId = '';
        if (lead.Rating == 'Hot') {
            system.debug('lead.OwnerId should be HOT queue');
            ownerId = System.Label.Ad_Sales_Hot_Queue;
        }else if (lead.Rating == 'Warm'){
            system.debug('lead.OwnerId should be Warm queue');
            ownerId = System.Label.Ad_Sales_Warm_Queue;
        }else if (lead.Rating == 'Cold'){
            system.debug('lead.OwnerId should be Cold queue');
            ownerId = System.Label.Ad_Sales_Cold_Queue;
        }else{
            system.debug('What went wrong?');
            ownerId = System.Label.Ad_Sales_Queue_ID;
        }
        lead.OwnerId = ownerId;  
    }*/
    // assign lead to Dev solutions queue(s) based on rating
     @TestVisible
    private static void assignDevSolLeadstoQueues(Lead lead) {
        System.debug('Inside assignDevSolLeadstoQueues method');
        String ownerId = '';
        if (lead.Rating == 'Hot') {
            system.debug('lead.OwnerId should be HOT queue');
            ownerId = System.Label.Dev_Solutions_Hot_Queue;
        } else if (lead.Rating == 'Warm') {
            system.debug('lead.OwnerId should be WARM queue');
            ownerId = System.Label.Dev_Solutions_Warm_Queue;
        } else if (lead.Rating == 'Cold') {
            system.debug('lead.OwnerId should be Cold queue');
            ownerId = System.Label.Dev_Solutions_Cold_Queue;
        }else{
            system.debug('What went wrong?');
            ownerId = System.Label.Dev_Solutions_Queue;
        }
        lead.OwnerId = ownerId;
    }
    // get company or email domain matching score
    private static decimal companyOrEmailDomainMatchScore(Lead lead, Set<String> personalDomains){
        decimal result = 0;
        if(lead.Matching_Account__c <> null  
           || (lead.Email_Domain_Exists__c == true && !personalDomains.contains(getEmailDomainOnly(lead.Email)))){ 
            result = Integer.valueOf(System.Label.Company_Or_Email_Domain_Match_Score);
        }
        system.debug('companyOrEmailDomainMatchScore result: '+result);
        return result;
    }
    // get company type score
    private static decimal companyTypeScore(Lead lead, Map<String, Decimal> companyTypeScores){
        // check the email domain in Email_Domain__mdt and return score
        decimal result = 0;
        if (!String.isBlank(lead.Company_Type__c) && lead.Company_Type__c <> 'Other') {
            List<String> companyTypeParts = lead.Company_Type__c.split(';');
            for(String str: companyTypeParts){
                if(companyTypeScores.containsKey(str)){
                    result = companyTypeScores.get(str);
                    break;
                }
            }
        }
        system.debug('companyTypeScore result: '+result);
        return result;
    }
    // get email domain score
    private static decimal emailDomainScore(Lead lead, Set<String> personalDomains){
        //Set<String> excludeEmailDomainSet = convertLabelToSet(System.label.Personal_Email_Domains);
        Set<String> eduDomains = convertLabelToSet(System.Label.UniversityDomains);
        
        decimal result = 0;
        system.debug('personalDomains.contains(getEmailDomainOnly(lead.Email) ==> '+personalDomains.contains(getEmailDomainOnly(lead.Email)));
        system.debug('getEmailDomainOnly(lead.Email) == '+getEmailDomainOnly(lead.Email));
        system.debug('getEmailDomianEnding(lead.Email)== '+getEmailDomianEnding(lead.Email));
        if (personalDomains.contains(getEmailDomainOnly(lead.Email)) || eduDomains.contains(getEmailDomianEnding(lead.Email))) {
            result = Integer.valueOf(System.Label.Email_Domain_Score);
        }
        system.debug('emailDomainScore result: '+result);
        return result;
    }
    // MK - 26June2026 - deprecating the old method to get the country score
    // get country score
    /*private static decimal countryScore(Lead lead, Set<String> highScoreCountries, Set<String> mediumScoreCountries){
        // calculate country score and return 
        decimal result = 0;
        if (!String.isBlank(lead.Country)) {
            if (highScoreCountries.contains(lead.Country.tolowerCase())) {
                result = Integer.valueof(System.Label.High_Score_Countries_Score);
            } else if (mediumScoreCountries.contains(lead.Country.toLowerCase())) {
                result = Integer.valueof(System.Label.Medium_Score_Countries_Score);
            }
        }
        system.debug('countryScore result: '+result);
        return result;
    }*/
    
    // get player comm medium score
    private static decimal playerCommMediumScore(Lead lead, Map<String, Decimal> playerCommMediumScores){
        // calculate player communication medium score and return
        decimal result = 0;
        if (playerCommMediumScores.containsKey(lead.Player_Communication_Medium__c)) { 
            result = playerCommMediumScores.get(lead.Player_Communication_Medium__c);
        }
        system.debug('playerCommMediumScore result: '+result);
        return result;
    }
    // get intended platform score
    private static Decimal intendedPlatformScore(Lead lead, Map<String, Decimal> platformScores) {
        // Check if the multipicklist field is not null
        decimal result = 0;
        if (platformScores.containsKey(lead.Intended_Platforms__c)) { 
            result = platformScores.get(lead.Intended_Platforms__c);
        }
        system.debug('intendedPlatformScore result: '+result);
        return result;
    }
}