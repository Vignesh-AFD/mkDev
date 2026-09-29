public with sharing class UserSalesInfoController {

    @AuraEnabled(cacheable=true)
    public static List<User> searchUsers(String searchTerm) {

        String keyword = '%' + searchTerm + '%';

        return [
            SELECT Id, Name, Email
            FROM User
            WHERE IsActive = true
            //AND Profile.name LIKE 'Ad Sales%'
            AND Name LIKE :keyword
            ORDER BY Name
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static User getUserDetails(Id userId) {

        return [
            SELECT Id,
                   Name,
                   Sales_Vertical__c,
                   Sales_Region__c
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static void updateUserSalesInfo(
        Id userId,
        String salesVertical,
        String salesRegion
    ) {

        User usr = new User(
            Id = userId,
            Sales_Vertical__c = salesVertical,
            Sales_Region__c = salesRegion
        );

        update usr;
    }
}