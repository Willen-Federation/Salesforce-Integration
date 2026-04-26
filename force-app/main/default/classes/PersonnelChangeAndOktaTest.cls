@isTest
private class PersonnelChangeAndOktaTest {

    private class MockHttpSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        OrgUnit__c from = new OrgUnit__c(
            Name = '異動元', UnitType__c = 'その他', Level__c = 1,
            IsActive__c = true, OktaGroupId__c = 'okta-grp-from'
        );
        insert from;
        OrgUnit__c to = new OrgUnit__c(
            Name = '異動先', UnitType__c = 'その他', Level__c = 1,
            IsActive__c = true, OktaGroupId__c = 'okta-grp-to'
        );
        insert to;

        Member__c m = new Member__c(
            LastName__c = '異動', FirstName__c = 'テスト',
            Email__c = 'transfer@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員',
            OktaUserId__c = 'okta-user-test',
            OrgUnit__c = from.Id
        );
        insert m;
    }

    @isTest
    static void testPersonnelChangeTriggerOnApproval() {
        Member__c m   = [SELECT Id FROM Member__c LIMIT 1];
        OrgUnit__c from = [SELECT Id FROM OrgUnit__c WHERE Name = '異動元' LIMIT 1];
        OrgUnit__c to   = [SELECT Id FROM OrgUnit__c WHERE Name = '異動先' LIMIT 1];

        PersonnelChange__c pc = new PersonnelChange__c(
            Member__c         = m.Id,
            ChangeType__c     = '異動',
            FromUnit__c       = from.Id,
            ToUnit__c         = to.Id,
            EffectiveDate__c  = Date.today(),
            ApprovalStatus__c = '申請中',
            NotifySlack__c    = false,
            NotifyEmail__c    = false
        );
        insert pc;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        update new PersonnelChange__c(Id = pc.Id, ApprovalStatus__c = '承認済み');
        Test.stopTest();

        Member__c updated = [SELECT OrgUnit__c FROM Member__c WHERE Id = :m.Id];
        System.assertEquals(to.Id, updated.OrgUnit__c, '所属組織が更新されること');
    }

    @isTest
    static void testPersonnelChangeTriggerInsertApproved() {
        Member__c m   = [SELECT Id FROM Member__c LIMIT 1];
        OrgUnit__c to = [SELECT Id FROM OrgUnit__c WHERE Name = '異動先' LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        PersonnelChange__c pc = new PersonnelChange__c(
            Member__c = m.Id, ChangeType__c = '配属', ToUnit__c = to.Id,
            EffectiveDate__c = Date.today(), ApprovalStatus__c = '承認済み',
            NotifySlack__c = false, NotifyEmail__c = false
        );
        insert pc;
        Test.stopTest();
    }

    @isTest
    static void testOktaSyncMemberFromSaml() {
        Map<String, String> attrs = new Map<String, String>{
            'email'       => 'jit@example.com',
            'sub'         => 'okta-jit-001',
            'given_name'  => '一郎',
            'family_name' => '山田',
            'department'  => 'テスト部',
            'orgUnit'     => 'TEST'
        };
        Test.startTest();
        OktaIntegrationService.syncMemberFromSamlAssertion(attrs);
        Test.stopTest();
        List<Member__c> created = [SELECT Id, OktaUserId__c FROM Member__c WHERE Email__c = 'jit@example.com'];
        System.assertEquals(1, created.size(), 'JITでMemberが作成されること');
        System.assertEquals('okta-jit-001', created[0].OktaUserId__c);
    }

    @isTest
    static void testOktaSyncMemberFromSamlUpdate() {
        Member__c existing = [SELECT Id FROM Member__c LIMIT 1];
        Map<String, String> attrs = new Map<String, String>{
            'email'       => 'transfer@example.com',
            'sub'         => 'okta-user-updated',
            'given_name'  => '更新',
            'family_name' => '異動',
            'department'  => '更新部署'
        };
        Test.startTest();
        OktaIntegrationService.syncMemberFromSamlAssertion(attrs);
        Test.stopTest();
        Member__c updated = [SELECT OktaUserId__c FROM Member__c WHERE Id = :existing.Id];
        System.assertEquals('okta-user-updated', updated.OktaUserId__c);
    }

    @isTest
    static void testOktaDeactivateUser() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        OktaIntegrationService.deactivateOktaUser('okta-user-test');
        Test.stopTest();
    }

    @isTest
    static void testOktaUpdateProfile() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        OktaIntegrationService.updateOktaUserProfile(
            'okta-user-test', '太郎', '鈴木', 'suzuki@example.com', '開発部'
        );
        Test.stopTest();
    }
}
