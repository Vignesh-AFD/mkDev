public with sharing class AccountNotesController {
    @AuraEnabled(cacheable=true)
    public static List<NoteWrapper> getRelatedNotes(Id accountId) {
        List<NoteWrapper> result = new List<NoteWrapper>();
        // First get all ContentDocumentIds related to the accounts
        List<ContentDocumentLink> accountDocLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accountId
        ];
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : accountDocLinks) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        if (contentDocumentIds.isEmpty()) return result;
        // Get the ContentDocuments for original creation info
        Map<Id, ContentDocument> contentDocuments = new Map<Id, ContentDocument>([
            SELECT Id, CreatedBy.Name, CreatedDate, LastModifiedBy.Name, LastModifiedDate
            FROM ContentDocument
            WHERE Id IN :contentDocumentIds
        ]);
        // Now get ALL ContentDocumentLinks for these documents (including links to other records)
        List<ContentDocumentLink> allDocLinks = [
            SELECT ContentDocumentId, LinkedEntityId, LinkedEntity.Type
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
        ];
        // Group by ContentDocumentId
        Map<Id, List<RelatedEntity>> docToEntities = new Map<Id, List<RelatedEntity>>();
        Set<Id> allLinkedEntityIds = new Set<Id>();
        for (ContentDocumentLink link : allDocLinks) {
            if (!docToEntities.containsKey(link.ContentDocumentId)) {
                docToEntities.put(link.ContentDocumentId, new List<RelatedEntity>());
            }
            docToEntities.get(link.ContentDocumentId).add(
                new RelatedEntity(link.LinkedEntityId, link.LinkedEntity.Type)
            );
            allLinkedEntityIds.add(link.LinkedEntityId);
        }
        // Get names for all related entities
        Map<Id, String> entityNames = new Map<Id, String>();
        for (Account acc : [SELECT Id, Name FROM Account WHERE Id IN :allLinkedEntityIds]) {
            entityNames.put(acc.Id, acc.Name);
        }
        for (Contact con : [SELECT Id, Name FROM Contact WHERE Id IN :allLinkedEntityIds]) {
            entityNames.put(con.Id, con.Name);
        }
        for (Opportunity opp : [SELECT Id, Name FROM Opportunity WHERE Id IN :allLinkedEntityIds]) {
            entityNames.put(opp.Id, opp.Name);
        }
        for (Lead leads : [SELECT Id, Name FROM Lead WHERE Id IN :allLinkedEntityIds]) {
            entityNames.put(leads.Id, leads.Name);
        }
        // Get the ContentVersions (notes)
        List<ContentVersion> noteVersions = [
            SELECT Id, Title, ContentModifiedDate,
                   ContentDocumentId, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND FileType = 'SNOTE'
            AND IsLatest = true
            ORDER BY CreatedDate DESC
        ];
        // Build the result
        for (ContentVersion noteVersion : noteVersions) {
            if (!docToEntities.containsKey(noteVersion.ContentDocumentId) ||
                !contentDocuments.containsKey(noteVersion.ContentDocumentId)) {
                continue;
            }
            ContentDocument doc = contentDocuments.get(noteVersion.ContentDocumentId);
            NoteWrapper wrap = new NoteWrapper();
            wrap.noteId = noteVersion.Id;
            wrap.contentDocumentId = noteVersion.ContentDocumentId;
            wrap.title = noteVersion.Title;
            // Get text preview
            try {
                String textContent = noteVersion.VersionData?.toString();
                String plainText = textContent != null ? textContent.replaceAll('<[^>]*>', '') : null;
                if (plainText != null) {
                    plainText = plainText
                        .replace('&#39;', '\'')
                        .replace('&quot;', '"')
                        .replace('&amp;', '&')
                        .replace('&lt;', '<')
                        .replace('&gt;', '>')
                        .replace('&nbsp;', ' ');
                }
                wrap.textPreview = plainText != null && !String.isEmpty(plainText)
                    ? plainText.abbreviate(100)
                    : 'No preview available';
            } catch (Exception e) {
                wrap.textPreview = 'Preview unavailable';
            }
            // Use ContentDocument for original creation info
            wrap.createdBy = doc.CreatedBy.Name;
            wrap.createdDate = doc.CreatedDate;
            // Use ContentVersion for content modified date
            wrap.contentModifiedDate = noteVersion.ContentModifiedDate;
            // Use ContentDocument for last modified info
            wrap.lastModifiedBy = doc.LastModifiedBy.Name;
            // Build related entities list
            List<RelatedEntityWrapper> relatedEntities = new List<RelatedEntityWrapper>();
            for (RelatedEntity entity : docToEntities.get(noteVersion.ContentDocumentId)) {
                if (entityNames.containsKey(entity.entityId)) {
                    relatedEntities.add(new RelatedEntityWrapper(
                        entity.entityId,
                        entity.entityType,
                        entityNames.get(entity.entityId)
                    ));
                }
            }
            wrap.relatedEntities = relatedEntities;
            result.add(wrap);
        }
        return result;
    }
    public class NoteWrapper {
        @AuraEnabled public String noteId;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String textPreview;
        @AuraEnabled public String createdBy;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public DateTime contentModifiedDate;
        @AuraEnabled public String lastModifiedBy;
        @AuraEnabled public List<RelatedEntityWrapper> relatedEntities;
    }
    public class RelatedEntity {
        public Id entityId;
        public String entityType;
        public RelatedEntity(Id entityId, String entityType) {
            this.entityId = entityId;
            this.entityType = entityType;
        }
    }
    public class RelatedEntityWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public String name;
        @AuraEnabled public String label {
            get {
                return type + ': ' + name;
            }
        }
        public RelatedEntityWrapper(Id id, String type, String name) {
            this.id = id;
            this.type = type;
            this.name = name;
        }
    }
}