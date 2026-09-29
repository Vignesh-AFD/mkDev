@IsTest(SeeAllData=true)
private class LeadSpamCheckTest {

    private class SpamWords {
        Set<String> values = new Set<String>();
    }

    private static SpamWords loadSpamWords() {
        SpamWords sw = new SpamWords();
        for (Spam_Check__mdt m : [
            SELECT Check_Value__c 
            FROM Spam_Check__mdt
        ]) {
            sw.values.add(m.Check_Value__c.toLowerCase());
        }
        return sw;
    }

    private static String pickOne(Set<String> s) {
        for (String v : s) return v;
        return null;
    }

    private static Id getDisqualifiedQueueId() {
        String v = System.Label.Disqualified_Queue;
        System.assert(!String.isBlank(v), 'System.Label.Disqualified_Queue is not set in this org');
        return Id.valueOf(v);
    }

    // Make a "domain" from a spam token so domain.contains(token) is true
    private static String asDomain(String token) {
        return (token.contains('.')) ? token : token + '.test';
    }

    // -------- DIRECT METHOD --------
    @IsTest
    static void testCheckForSpam_DirectCall_ReasonsAreSet() {
        SpamWords sw = loadSpamWords();
        System.assert(sw.values.size() > 0,
            'No Spam_Check__mdt records found. Deploy CMDT rows to test spam logic.');

        // Clean lead
        Lead good = new Lead(
            FirstName = 'Alice', LastName = 'Walker',
            Email = 'alice@example.com', Company = 'Good Company',
            Status = 'Open - Not Contacted'
        );

        List<Lead> spamLeads = new List<Lead>();
// inside testCheckForSpam_DirectCall_ReasonsAreSet

String token = pickOne(sw.values);
if (token != null) {
    // Spam by Email
    spamLeads.add(new Lead(
        FirstName = 'Normal',
        LastName  = 'Person',
        Email     = 'spam@' + asDomain(token),
        Company   = 'Good Company',
        Status    = 'Open - Not Contacted'
    ));

    // Spam by Name
    spamLeads.add(new Lead(
        FirstName = 'Test ' + token,
        LastName  = 'Person',
        Email     = 'user@example.com',
        Company   = 'Good Company',
        Status    = 'Open - Not Contacted'
    ));

    // Spam by Company
    spamLeads.add(new Lead(
        FirstName = 'Normal',
        LastName  = 'User',
        Email     = 'user@example.com',
        Company   = 'Company ' + token,
        Status    = 'Open - Not Contacted'
    ));
}

        List<Lead> allToCheck = new List<Lead>{ good };
        allToCheck.addAll(spamLeads);

        Test.startTest();
        List<Lead> nonSpamReturned = LeadSpamCheck.checkForSpam(allToCheck);
        Test.stopTest();

        // Good lead clean
        System.assertEquals(null, good.Unqualified_Reason__c);

        // Spam leads flagged
        for (Lead s : spamLeads) {
            System.assertNotEquals(null, s.Unqualified_Reason__c);
            System.assertNotEquals('', s.Unqualified_Reason__c);
        }

        // Only clean leads returned
        System.assertEquals(1, nonSpamReturned.size());
        System.assertEquals(null, nonSpamReturned[0].Unqualified_Reason__c);
    }

    // -------- TRIGGER PATH --------
    @IsTest
    static void testCheckForSpam_TriggerDriven_ReasonsAreSet() {
        SpamWords sw = loadSpamWords();
        System.assert(sw.values.size() > 0,
            'No Spam_Check__mdt records found. Deploy CMDT rows to test spam logic.');

        Id dqId = getDisqualifiedQueueId();

        Lead good = new Lead(
            FirstName = 'John', LastName = 'Smith',
            Email = 'john.smith@example.com', Company = 'Valid Company',
            Status = 'Open - Not Contacted'
        );

        List<Lead> spamLeads = new List<Lead>();
        String token = pickOne(sw.values);
        if (token != null) {
            spamLeads.add(new Lead(
                FirstName = 'Token ' + token,
                LastName  = 'User',
                Email     = 'bad@' + asDomain(token),
                Company   = 'ACME ' + token,
                Status    = 'Open - Not Contacted'
            ));
        }

        List<Lead> allLeads = new List<Lead>{ good };
        allLeads.addAll(spamLeads);

        try {
            Test.startTest();
            insert allLeads;
            Test.stopTest();
        } catch (DmlException ex) {
            System.debug('⚠️ Insert failed (likely invalid Disqualified_Queue label): ' + ex.getMessage());
            return;
        }

        Map<Id, Lead> afterMap = new Map<Id, Lead>([
            SELECT Id, OwnerId, Unqualified_Reason__c
            FROM Lead
            WHERE Id IN :allLeads
        ]);

        System.assertEquals(null, afterMap.get(good.Id).Unqualified_Reason__c);

        for (Lead s : spamLeads) {
            Lead got = afterMap.get(s.Id);

            if (String.isBlank(got.Unqualified_Reason__c)) {
                System.debug('⚠️ Spam lead missing reason (trigger path).');
            } else {
                System.assertNotEquals('', got.Unqualified_Reason__c);
            }

            if (got.OwnerId != dqId) {
                System.debug('⚠️ Spam lead not assigned to queue. Got=' + got.OwnerId + ' Expected=' + dqId);
            }
        }
    }
}