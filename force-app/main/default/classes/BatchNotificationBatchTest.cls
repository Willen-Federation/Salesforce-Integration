@isTest
private class BatchNotificationBatchTest {

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
        OrgUnit__c unit = new OrgUnit__c(
            Name = 'テスト組織', UnitType__c = 'その他', Level__c = 1, IsActive__c = true
        );
        insert unit;

        List<Member__c> members = new List<Member__c>();
        for (Integer i = 0; i < 5; i++) {
            members.add(new Member__c(
                LastName__c     = 'バッチ',
                FirstName__c    = 'テスト' + i,
                Email__c        = 'batchtest' + i + '@example.com',
                MemberStatus__c = '正会員',
                MemberType__c   = '個人会員',
                OrgUnit__c      = unit.Id
            ));
        }
        insert members;

        BatchNotification__c notif = new BatchNotification__c(
            Name                  = 'テスト通知',
            NotificationType__c   = '全会員向け',
            Channel__c            = 'メール',
            Content__c            = '<p>テスト通知内容です。</p>',
            NotificationStatus__c = '送信予約済み',
            ScheduledDate__c      = Datetime.now().addMinutes(-1)
        );
        insert notif;
    }

    @isTest
    static void testBatchEmailOnly() {
        BatchNotification__c notif = [SELECT Id FROM BatchNotification__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        Database.executeBatch(new BatchNotificationBatch(notif.Id), 50);
        Test.stopTest();
        BatchNotification__c updated = [SELECT NotificationStatus__c, SentCount__c FROM BatchNotification__c WHERE Id = :notif.Id];
        System.assertNotEquals(null, updated.NotificationStatus__c);
    }

    @isTest
    static void testBatchSlackAndEmail() {
        BatchNotification__c notif = [SELECT Id FROM BatchNotification__c LIMIT 1];
        update new BatchNotification__c(Id = notif.Id, Channel__c = 'メール;Slack');
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        Database.executeBatch(new BatchNotificationBatch(notif.Id), 50);
        Test.stopTest();
    }

    @isTest
    static void testSchedulable() {
        BatchNotification__c notif = [SELECT Id FROM BatchNotification__c LIMIT 1];
        update new BatchNotification__c(Id = notif.Id, NotificationStatus__c = '送信予約済み');
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
        BatchNotificationBatch scheduler = new BatchNotificationBatch(notif.Id);
        String cronExp = '0 0 * * * ?';
        System.schedule('BatchNotificationTest', cronExp, scheduler);
        Test.stopTest();
    }
}
