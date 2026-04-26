@isTest
private class SlackAndEmailServiceTest {

    // Slack/Okta HTTP callout のモック
    private class MockHttpSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        OrgUnit__c fromUnit = new OrgUnit__c(
            Name = '元部門', UnitType__c = 'その他', Level__c = 1,
            IsActive__c = true, SlackChannelId__c = 'C0TESTFROM'
        );
        insert fromUnit;
        OrgUnit__c toUnit = new OrgUnit__c(
            Name = '新部門', UnitType__c = 'その他', Level__c = 1,
            IsActive__c = true, SlackChannelId__c = 'C0TESTTO'
        );
        insert toUnit;

        Member__c m = new Member__c(
            LastName__c = '通知', FirstName__c = 'テスト',
            Email__c = 'notify@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員',
            OrgUnit__c = fromUnit.Id,
            SlackUserId__c = 'U0TESTUSER',
            OktaUserId__c  = 'okta-user-001'
        );
        insert m;

        PersonnelChange__c pc = new PersonnelChange__c(
            Member__c        = m.Id,
            ChangeType__c    = '異動',
            FromUnit__c      = fromUnit.Id,
            ToUnit__c        = toUnit.Id,
            EffectiveDate__c = Date.today(),
            ApprovalStatus__c = '承認済み',
            NotifySlack__c   = true,
            NotifyEmail__c   = true,
            SlackNotificationSent__c = false
        );
        insert pc;

        SupportInquiry__c inq = new SupportInquiry__c(
            ContactName__c  = '通知 テスト',
            ContactEmail__c = 'notify@example.com',
            Subject__c      = 'テスト問い合わせ',
            Category__c     = 'その他',
            Body__c         = 'テスト内容',
            InquiryStatus__c = '受付済み',
            Priority__c     = '高',
            NotifySlack__c  = true,
            NotifyEmail__c  = false
        );
        insert inq;
    }

    @isTest
    static void testSlackNotifyPersonnelChange() {
        PersonnelChange__c pc = [SELECT Id FROM PersonnelChange__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        SlackIntegrationService.notifyPersonnelChange(pc.Id);
        Test.stopTest();
        PersonnelChange__c updated = [SELECT SlackNotificationSent__c FROM PersonnelChange__c WHERE Id = :pc.Id];
        System.assertEquals(true, updated.SlackNotificationSent__c);
    }

    @isTest
    static void testSlackNotifyPersonnelChangeNoSlack() {
        PersonnelChange__c pc = [SELECT Id FROM PersonnelChange__c LIMIT 1];
        update new PersonnelChange__c(Id = pc.Id, NotifySlack__c = false);
        Test.startTest();
        SlackIntegrationService.notifyPersonnelChange(pc.Id);
        Test.stopTest();
        // 通知OFFなので処理なし（例外なし）
    }

    @isTest
    static void testSlackNotifySupportInquiry() {
        SupportInquiry__c inq = [SELECT Id FROM SupportInquiry__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        SlackIntegrationService.notifySupportInquiry(inq.Id);
        Test.stopTest();
    }

    @isTest
    static void testEmailPersonnelChange() {
        PersonnelChange__c pc = [SELECT Id FROM PersonnelChange__c LIMIT 1];
        Test.startTest();
        EmailNotificationService.sendPersonnelChangeNotification(pc.Id);
        Test.stopTest();
    }

    @isTest
    static void testEmailMemberRegistrationConfirmation() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        EmailNotificationService.sendMemberRegistrationConfirmation(m.Id);
        Test.stopTest();
    }

    @isTest
    static void testEmailMemberApprovalNotification() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        EmailNotificationService.sendMemberApprovalNotification(m.Id);
        Test.stopTest();
    }

    @isTest
    static void testEmailDonationConfirmation() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Donation__c d = new Donation__c(
            Member__c = m.Id, DonorName__c = '通知 テスト',
            DonorEmail__c = 'notify@example.com',
            Amount__c = 1000, Purpose__c = '一般活動費',
            DonationDate__c = Date.today(), DonationStatus__c = '入金確認済み',
            IsAnonymous__c = false
        );
        insert d;
        Test.startTest();
        EmailNotificationService.sendDonationConfirmation(d.Id);
        Test.stopTest();
    }

    @isTest
    static void testEmailDonationConfirmationAnonymous() {
        Donation__c d = new Donation__c(
            Amount__c = 1000, Purpose__c = '一般活動費',
            DonationDate__c = Date.today(), DonationStatus__c = '入金確認済み',
            IsAnonymous__c = true
        );
        insert d;
        Test.startTest();
        EmailNotificationService.sendDonationConfirmation(d.Id);
        Test.stopTest();
        // 匿名なのでメール送信されないこと（例外なし）
    }

    @isTest
    static void testEmailInquiryAutoReply() {
        SupportInquiry__c inq = [SELECT Id FROM SupportInquiry__c LIMIT 1];
        update new SupportInquiry__c(Id = inq.Id, NotifyEmail__c = true,
                                      ContactEmail__c = 'notify@example.com');
        Test.startTest();
        EmailNotificationService.sendInquiryAutoReply(inq.Id);
        Test.stopTest();
    }
}
