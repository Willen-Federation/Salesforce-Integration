@isTest
private class MemberRegistrationControllerTest {

    @TestSetup
    static void setup() {
        OrgUnit__c unit = new OrgUnit__c(Name = 'テスト部会', UnitType__c = 'その他', Level__c = 1, IsActive__c = true);
        insert unit;

        Member__c member = new Member__c(
            LastName__c     = 'テスト',
            FirstName__c    = '太郎',
            Email__c        = 'test@example.com',
            MemberStatus__c = '正会員',
            MemberType__c   = '個人会員',
            OrgUnit__c      = unit.Id
        );
        insert member;
    }

    @isTest
    static void testGetMemberById() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        Member__c result = MemberRegistrationController.getMemberById(m.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, '会員が取得できること');
        System.assertEquals('テスト', result.LastName__c);
    }

    @isTest
    static void testGetMemberByEmail() {
        Test.startTest();
        Member__c result = MemberRegistrationController.getMemberByEmail('test@example.com');
        Test.stopTest();
        System.assertNotEquals(null, result, 'メールで会員が取得できること');
    }

    @isTest
    static void testGetMemberByEmailNotFound() {
        Test.startTest();
        Member__c result = MemberRegistrationController.getMemberByEmail('notexist@example.com');
        Test.stopTest();
        System.assertEquals(null, result, '存在しないメールの場合nullを返すこと');
    }

    @isTest
    static void testRegisterMember() {
        Map<String, Object> data = new Map<String, Object>{
            'lastName'     => '新規',
            'firstName'    => '会員',
            'email'        => 'newmember@example.com',
            'memberType'   => '個人会員',
            'phone'        => '03-1234-5678',
            'organization' => 'テスト会社',
            'department'   => '開発部',
            'position'     => '課長'
        };
        Test.startTest();
        Id memberId = MemberRegistrationController.registerMember(data);
        Test.stopTest();
        System.assertNotEquals(null, memberId, '会員IDが返されること');
        Member__c created = [SELECT MemberStatus__c FROM Member__c WHERE Id = :memberId];
        System.assertEquals('申請中', created.MemberStatus__c, 'ステータスが申請中であること');
    }

    @isTest
    static void testUpdateMemberProfile() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Map<String, Object> updates = new Map<String, Object>{
            'phone' => '090-9999-0000',
            'department' => '更新部署'
        };
        Test.startTest();
        MemberRegistrationController.updateMemberProfile(m.Id, updates);
        Test.stopTest();
        Member__c updated = [SELECT Phone__c, Department__c FROM Member__c WHERE Id = :m.Id];
        System.assertEquals('090-9999-0000', updated.Phone__c);
        System.assertEquals('更新部署', updated.Department__c);
    }

    @isTest
    static void testSearchMembers() {
        Test.startTest();
        List<Member__c> results = MemberRegistrationController.searchMembers('テスト', '正会員');
        Test.stopTest();
        System.assertNotEquals(0, results.size(), '検索結果が返されること');
    }

    @isTest
    static void testSearchMembersNoFilter() {
        Test.startTest();
        List<Member__c> results = MemberRegistrationController.searchMembers('テスト', null);
        Test.stopTest();
        System.assertNotEquals(0, results.size());
    }

    @isTest
    static void testApproveMember() {
        Member__c m = [SELECT Id FROM Member__c WHERE MemberStatus__c = '正会員' LIMIT 1];
        update new Member__c(Id = m.Id, MemberStatus__c = '申請中');
        Test.startTest();
        MemberRegistrationController.approveMember(m.Id);
        Test.stopTest();
        Member__c approved = [SELECT MemberStatus__c FROM Member__c WHERE Id = :m.Id];
        System.assertEquals('正会員', approved.MemberStatus__c, '承認後は正会員になること');
    }
}
