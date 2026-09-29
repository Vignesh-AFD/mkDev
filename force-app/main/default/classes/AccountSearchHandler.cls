public class AccountSearchHandler {
    
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccountLookup(String searchTerm){
        String searchAccStringLike = '%'+searchTerm+'%';
        String searchKey = generateAccountUniqueKey(searchTerm) + '%';
        String searchAccSoundexStringLike = (searchKey <> null && searchKey.length() > 1) ? '%' + generateAccountUniqueKey(searchTerm).substring(1) : '';
        List<Account> acclist =[Select id, Name, Sales_Account_Executive__r.Name, Dev_Solutions_Lead__r.Name from Account 
                                where name Like:searchAccStringLike 
                                OR Unique_Key__c like : searchKey 
                                //OR Unique_Key__c like : searchAccSoundexStringLike
                                Order by Lastmodifieddate desc
                                Limit 15];
        //system.debug('Account search list -->'+acclist);
        return acclist;
    }

    @AuraEnabled
    public static String attachAccountToLead(String accName, String leadId){
        system.debug('Attaching Account: ' + accName + ' to Lead ID: ' + leadId);
        if(String.isBlank(accName) || String.isBlank(leadId)) {
            throw new AuraHandledException('Account name and Lead ID must be provided.');
        }
        try{
            Lead leadToUpdate = [Select Id, Company from Lead where Id =:leadId limit 1];
            leadToUpdate.Company = accName;
            update leadToUpdate;
            return 'Lead updated with Account: ' + accName;
        }catch(Exception e){
            throw new AuraHandledException('Error attaching Account to Lead: ' + e.getMessage());
        }
    }
    
    // Soundex mapping for consonants
    private static final Map<String, Integer> SOUNDEX_MAP = new Map<String, Integer>{
        'F' => 0, 'V' => 0,
        'B' => 1, 'P' => 1,
        'C' => 2, 'K' => 2, 'Q' => 2, 
        'D' => 3, 'T' => 3,
        'L' => 4,
        'M' => 5, 'N' => 5,
        'R' => 6,
        'Y' => 7, 'H' => 7, 'W' => 7,
        'G' => 8, 'J' => 8, 
        'S' => 9, 'X' => 9, 'Z' => 9
    };
    
    // Vowels to be ignored
    private static final Set<String> VOWELS = new Set<String>{
        'A', 'E', 'I', 'O', 'U' 
    };
    
    public static String generateSoundexKey(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        
        // Convert to uppercase and remove non-alphabetic characters
        String cleaned = input.toUpperCase().replaceAll('[^A-Z]', '');
        
        if (cleaned.length() == 0) {
            return null;
        }
        
        // Keep first character
        String firstChar = cleaned.substring(0, 1);
        List<Integer> codes = new List<Integer>();
        
        // Process remaining characters
        for (Integer i = 0; i < cleaned.length(); i++) {
            String currentChar = cleaned.substring(i, i + 1);
            
            // Skip vowels and specific consonants
            if (i > 0 && VOWELS.contains(currentChar)) {
                continue;
            }
            
            // Get soundex code for the character
            Integer code = SOUNDEX_MAP.get(currentChar);
            if (code != null) {
                // Don't add duplicate codes consecutively
                if (codes.size() == 0 || codes[codes.size() - 1] != code) {
                    codes.add(code);
                }
            }
        }
        
        // Build the final key
        String soundexKey = firstChar;
        
        // Add codes (limit to 6 digits total including first char)
        for (Integer i = 0; i < Math.min(codes.size(), 9); i++) {
            soundexKey += String.valueOf(codes[i]);
        }
        
        // Return first 8 characters
        return soundexKey.length() > 8 ? soundexKey.substring(0, 8) : soundexKey;
    }
    
    // Generate unique key from Account Name (first two words)
    public static String generateAccountUniqueKey(String accountName) {
        if (String.isBlank(accountName)) {
            return null;
        }
        
        // Extract first two words
        String cleanedName = accountName.trim().replaceAll('\\s+', ' ');
        List<String> words = cleanedName.split(' ');
        
        String keyBase = '';
        if (words.size() >= 2) {
            keyBase = words[0] + ' ' + words[1];
        } else if (words.size() == 1) {
            keyBase = words[0];
        }
        
        // Generate Soundex key from the base
        return generateSoundexKey(keyBase);
    }
    
    // One-time batch job to update all existing accounts
    public static void updateAllAccountUniqueKeys() {
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Account acc : [SELECT Id, Name FROM Account WHERE Unique_Key__c = '']) { // Unique_Key__c = null OR
            String uniqueKey = generateAccountUniqueKey(acc.Name);
            if (uniqueKey != null) {
                acc.Unique_Key__c = uniqueKey;
                accountsToUpdate.add(acc);
            }
            
            // Batch update to avoid governor limits
            if (accountsToUpdate.size() == 100) {
                update accountsToUpdate;
                accountsToUpdate.clear();
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
    
    // Batchable version for large data volumes
    /*public class SoundexBatch implements Database.Batchable<SObject> {
        public Database.QueryLocator start(Database.BatchableContext bc) {
            return Database.getQueryLocator('SELECT Id, Name FROM Account');
        }
        
        public void execute(Database.BatchableContext bc, List<Account> scope) {
            List<Account> accountsToUpdate = new List<Account>();
            
            for (Account acc : scope) {
                String uniqueKey = generateAccountUniqueKey(acc.Name);
                if (uniqueKey != null) {
                    acc.Unique_Key__c = uniqueKey;
                    accountsToUpdate.add(acc);
                }
            }
            
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        }
        
        public void finish(Database.BatchableContext bc) {
            System.debug('Soundex batch processing completed');
        }
    }*/
}