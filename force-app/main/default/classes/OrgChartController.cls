public with sharing class OrgChartController {

    @AuraEnabled(cacheable=true)
    public static List<OrgUnit__c> getAllOrgUnits() {
        return [
            SELECT Id, Name, UnitCode__c, UnitType__c, Level__c, IsActive__c,
                   ParentUnit__c, EstablishedDate__c, Description__c,
                   OktaGroupId__c, SlackChannelId__c,
                   Manager__r.LastName__c, Manager__r.FirstName__c
            FROM OrgUnit__c
            WHERE IsActive__c = true
            WITH SECURITY_ENFORCED
            ORDER BY Level__c ASC, Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Member__c> getAllMembers() {
        return [
            SELECT Id, Name, LastName__c, FirstName__c, Position__c,
                   MemberStatus__c, OrgUnit__c
            FROM Member__c
            WHERE MemberStatus__c IN ('正会員', '準会員')
            WITH SECURITY_ENFORCED
            ORDER BY LastName__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Member__c> getMembersByOrgUnit(Id orgUnitId) {
        return [
            SELECT Id, Name, LastName__c, FirstName__c, Position__c, Email__c
            FROM Member__c
            WHERE OrgUnit__c = :orgUnitId
            AND MemberStatus__c IN ('正会員', '準会員')
            WITH SECURITY_ENFORCED
            ORDER BY LastName__c ASC
        ];
    }
}
