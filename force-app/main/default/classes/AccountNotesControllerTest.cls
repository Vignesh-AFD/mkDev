@isTest
private class AccountNotesControllerTest {
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        // Create test contact related to the account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
        // Create test opportunity related to the account
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id
        );
        insert testOpp;
        // Create a content document (note)
        ContentVersion testNote = new ContentVersion(
            Title = 'Test Note',
            PathOnClient = 'TestNote.snote',
            VersionData = Blob.valueOf('<p>This is a test note content</p>')
        );
        insert testNote;
        // Get the content document ID
        testNote = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testNote.Id];
        // Link the note to the account
        ContentDocumentLink accountLink = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = testNote.ContentDocumentId,
            ShareType = 'V'
        );
        insert accountLink;
        // Link the same note to the contact (to test multiple relationships)
        ContentDocumentLink contactLink = new ContentDocumentLink(
            LinkedEntityId = testContact.Id,
            ContentDocumentId = testNote.ContentDocumentId,
            ShareType = 'V'
        );
        insert contactLink;
    }
    @isTest
    static void testGetRelatedNotesWithValidAccountId() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes(testAccount.Id);
        Test.stopTest();
        System.assertNotEquals(0, notes.size(), 'Should return at least one note');
        System.assertEquals('Test Note', notes[0].title, 'Note title should match');
        System.assert(notes[0].textPreview.contains('This is a test note content'), 'Note content should match');
        System.assertEquals(2, notes[0].relatedEntities.size(), 'Note should be linked to 2 entities');
    }
    @isTest
    static void testGetRelatedNotesWithInvalidAccountId() {
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes('001000000000000');
        Test.stopTest();
        System.assertEquals(0, notes.size(), 'Should return empty list for invalid account ID');
    }
    @isTest
    static void testNoteWrapperProperties() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        ContentDocument doc = [SELECT Id, CreatedDate, CreatedBy.Name, LastModifiedBy.Name FROM ContentDocument LIMIT 1];
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes(testAccount.Id);
        Test.stopTest();
        System.assertEquals(doc.CreatedBy.Name, notes[0].createdBy, 'CreatedBy should match ContentDocument');
        System.assertEquals(doc.CreatedDate, notes[0].createdDate, 'CreatedDate should match ContentDocument');
        System.assertEquals(doc.LastModifiedBy.Name, notes[0].lastModifiedBy, 'LastModifiedBy should match ContentDocument');
    }
    @isTest
    static void testRelatedEntityWrapperProperties() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes(testAccount.Id);
        AccountNotesController.RelatedEntityWrapper entityWrapper = notes[0].relatedEntities[0];
        Test.stopTest();
        System.assertNotEquals(null, entityWrapper.id, 'Entity ID should not be null');
        System.assertNotEquals(null, entityWrapper.type, 'Entity type should not be null');
        System.assertNotEquals(null, entityWrapper.name, 'Entity name should not be null');
        System.assert(entityWrapper.label.contains(entityWrapper.type), 'Label should contain entity type');
        System.assert(entityWrapper.label.contains(entityWrapper.name), 'Label should contain entity name');
    }
    @isTest
    static void testNoNotesForAccount() {
        Account newAccount = new Account(Name = 'New Test Account');
        insert newAccount;
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes(newAccount.Id);
        Test.stopTest();
        System.assertEquals(0, notes.size(), 'Should return empty list for account with no notes');
    }
    @isTest
    static void testContentModifiedDate() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        ContentVersion note = [SELECT Id, ContentModifiedDate FROM ContentVersion WHERE Title = 'Test Note'];
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes(testAccount.Id);
        Test.stopTest();
        System.assertEquals(note.ContentModifiedDate, notes[0].contentModifiedDate, 'ContentModifiedDate should match ContentVersion');
    }
    @isTest
    static void testTextPreviewHandling() {
        // Create a new note with special characters
        ContentVersion testNote = new ContentVersion(
            Title = 'Special Chars Note',
            PathOnClient = 'SpecialNote.snote',
            VersionData = Blob.valueOf('<p>This has &quot;quotes&quot; and &#39;apostrophes&#39; &amp; ampersands</p>')
        );
        insert testNote;
        // Link to account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        testNote = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testNote.Id];
        ContentDocumentLink link = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = testNote.ContentDocumentId,
            ShareType = 'V'
        );
        insert link;
        Test.startTest();
        List<AccountNotesController.NoteWrapper> notes = AccountNotesController.getRelatedNotes(testAccount.Id);
        Test.stopTest();
        // Find our test note in the results
        AccountNotesController.NoteWrapper testWrapper;
        for (AccountNotesController.NoteWrapper wrapper : notes) {
            if (wrapper.title == 'Special Chars Note') {
                testWrapper = wrapper;
                break;
            }
        }
        System.assertNotEquals(null, testWrapper, 'Test note should be found');
        System.assert(testWrapper.textPreview.contains('This has "quotes" and \'apostrophes\' & ampersands'),
                     'Special characters should be properly decoded');
    }
}