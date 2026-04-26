@isTest
private class OrgChartControllerTest {

    @TestSetup
    static void setup() {
        OrgUnit__c parent = new OrgUnit__c(
            Name = '理事会', UnitType__c = '理事会', Level__c = 1, IsActive__c = true, UnitCode__c = 'BOD'
        );
        insert parent;

        OrgUnit__c child = new OrgUnit__c(
            Name = '技術委員会', UnitType__c = '委員会', Level__c = 2,
            IsActive__c = true, ParentUnit__c = parent.Id, UnitCode__c = 'TECH'
        );
        insert child;

        Member__c m = new Member__c(
            LastName__c = '組織', FirstName__c = 'テスト',
            Email__c = 'orgtest@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員',
            OrgUnit__c = child.Id
        );
        insert m;

        OrgUnit__c withManager = new OrgUnit__c(
            Name = '事務局', UnitType__c = '事務局', Level__c = 2,
            IsActive__c = true, ParentUnit__c = parent.Id, UnitCode__c = 'SEC',
            Manager__c = m.Id
        );
        insert withManager;
    }

    @isTest
    static void testGetAllOrgUnits() {
        Test.startTest();
        List<OrgUnit__c> units = OrgChartController.getAllOrgUnits();
        Test.stopTest();
        System.assertNotEquals(0, units.size());
    }

    @isTest
    static void testGetAllMembers() {
        Test.startTest();
        List<Member__c> members = OrgChartController.getAllMembers();
        Test.stopTest();
        System.assertNotEquals(0, members.size());
    }

    @isTest
    static void testGetMembersByOrgUnit() {
        OrgUnit__c unit = [SELECT Id FROM OrgUnit__c WHERE UnitCode__c = 'TECH' LIMIT 1];
        Test.startTest();
        List<Member__c> members = OrgChartController.getMembersByOrgUnit(unit.Id);
        Test.stopTest();
        System.assertEquals(1, members.size());
    }

    @isTest
    static void testGetMembersByOrgUnitEmpty() {
        OrgUnit__c unit = [SELECT Id FROM OrgUnit__c WHERE UnitCode__c = 'SEC' LIMIT 1];
        Test.startTest();
        List<Member__c> members = OrgChartController.getMembersByOrgUnit(unit.Id);
        Test.stopTest();
        System.assertEquals(0, members.size(), '担当会員なしの場合空リスト');
    }
}
