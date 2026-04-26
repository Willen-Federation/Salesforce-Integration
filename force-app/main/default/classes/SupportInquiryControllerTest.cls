@isTest
private class SupportInquiryControllerTest {

    @TestSetup
    static void setup() {
        Member__c m = new Member__c(
            LastName__c = 'サポート', FirstName__c = 'テスト',
            Email__c = 'support@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員'
        );
        insert m;

        SupportInquiry__c inq = new SupportInquiry__c(
            Member__c       = m.Id,
            ContactName__c  = 'サポート テスト',
            ContactEmail__c = 'support@example.com',
            Category__c     = 'その他',
            Subject__c      = 'テスト問い合わせ',
            Body__c         = 'テスト本文内容です。',
            InquiryStatus__c = '受付済み',
            Priority__c     = '中',
            NotifySlack__c  = false,
            NotifyEmail__c  = false
        );
        insert inq;
    }

    @isTest
    static void testSubmitInquiry() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{
            'contactName'  => 'テスト ユーザー',
            'contactEmail' => 'testuser@example.com',
            'category'     => '支払い・請求',
            'subject'      => 'テスト件名',
            'body'         => 'テスト問い合わせ内容です。',
            'memberId'     => (Object)m.Id
        };
        Test.startTest();
        Id inquiryId = SupportInquiryController.submitInquiry(data);
        Test.stopTest();
        System.assertNotEquals(null, inquiryId);
        SupportInquiry__c created = [SELECT InquiryStatus__c FROM SupportInquiry__c WHERE Id = :inquiryId];
        System.assertEquals('受付済み', created.InquiryStatus__c);
    }

    @isTest
    static void testGetInquiriesByMember() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        List<SupportInquiry__c> results = SupportInquiryController.getInquiriesByMember(m.Id);
        Test.stopTest();
        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetInquiryDetail() {
        SupportInquiry__c inq = [SELECT Id FROM SupportInquiry__c LIMIT 1];
        Test.startTest();
        SupportInquiry__c detail = SupportInquiryController.getInquiryDetail(inq.Id);
        Test.stopTest();
        System.assertNotEquals(null, detail);
        System.assertEquals('テスト問い合わせ', detail.Subject__c);
    }

    @isTest
    static void testRespondToInquiry() {
        SupportInquiry__c inq = [SELECT Id FROM SupportInquiry__c LIMIT 1];
        Test.startTest();
        SupportInquiryController.respondToInquiry(inq.Id, 'ご質問の件について回答します。テスト回答内容。');
        Test.stopTest();
        SupportInquiry__c updated = [SELECT InquiryStatus__c, Response__c FROM SupportInquiry__c WHERE Id = :inq.Id];
        System.assertEquals('回答済み', updated.InquiryStatus__c);
        System.assertNotEquals(null, updated.Response__c);
    }

    @isTest
    static void testCloseInquiry() {
        SupportInquiry__c inq = [SELECT Id FROM SupportInquiry__c LIMIT 1];
        Test.startTest();
        SupportInquiryController.closeInquiry(inq.Id, '4 - 満足');
        Test.stopTest();
        SupportInquiry__c updated = [SELECT InquiryStatus__c, SatisfactionRating__c FROM SupportInquiry__c WHERE Id = :inq.Id];
        System.assertEquals('完了', updated.InquiryStatus__c);
        System.assertEquals('4 - 満足', updated.SatisfactionRating__c);
    }

    @isTest
    static void testGetOpenInquiries() {
        Test.startTest();
        List<SupportInquiry__c> results = SupportInquiryController.getOpenInquiries();
        Test.stopTest();
        System.assertNotEquals(0, results.size());
    }
}
