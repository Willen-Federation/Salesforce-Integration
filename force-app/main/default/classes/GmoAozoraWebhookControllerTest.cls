@isTest
private class GmoAozoraWebhookControllerTest {

    // ── HTTP モック（自動振込のcallout用）──────────────────────────

    private class MockTransferSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"at-test"}');
            } else {
                res.setStatusCode(201);
                res.setBody('{"applyNo":"APPL001","resultCode":"0"}');
            }
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Member__c m = new Member__c(
            LastName__c     = '入金',
            FirstName__c    = 'テスト',
            Email__c        = 'deposit@example.com',
            MemberStatus__c = '正会員',
            MemberType__c   = '個人会員'
        );
        insert m;

        // VA番号が既に設定された支払いレコード（トリガーはVA未設定かつ未払いのみ発行するのでスキップされる）
        Payment__c p = new Payment__c(
            Member__c               = m.Id,
            PaymentType__c          = '年会費',
            Amount__c               = 10000,
            DueDate__c              = Date.today().addDays(30),
            PaymentStatus__c        = '未払い',
            VirtualAccountNumber__c = 'VA-TEST-001'
        );
        insert p;
    }

    private static void initRestContext(String body, String eventType, String signature) {
        RestRequest req    = new RestRequest();
        req.requestURI     = '/services/apexrest/gmo-aozora/webhook';
        req.httpMethod     = 'POST';
        req.requestBody    = Blob.valueOf(body);
        if (eventType  != null) req.headers.put('x-eventType',           eventType);
        if (signature  != null) req.headers.put('x-webhook-signature',   signature);
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    // ── 正常入金 ────────────────────────────────────────────────────

    @isTest
    static void testValidDeposit() {
        Payment__c p = [SELECT Id, VirtualAccountNumber__c, Amount__c FROM Payment__c LIMIT 1];
        String body = JSON.serialize(new Map<String, Object>{
            'vaTransaction' => new Map<String, Object>{
                'vaAccountNumber' => p.VirtualAccountNumber__c,
                'depositAmount'   => String.valueOf(p.Amount__c.intValue()),
                'vaId'            => 'VA-001',
                'transactionDate' => String.valueOf(Date.today())
            }
        });
        initRestContext(body, 'va-deposit-transaction', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Payment__c updated = [SELECT PaymentStatus__c, AutoTransferStatus__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('支払済み', updated.PaymentStatus__c);
        System.assertEquals('未実行',   updated.AutoTransferStatus__c);
    }

    // ── 不足入金 ────────────────────────────────────────────────────

    @isTest
    static void testShortPayment() {
        Payment__c p = [SELECT Id, VirtualAccountNumber__c FROM Payment__c LIMIT 1];
        String body = JSON.serialize(new Map<String, Object>{
            'vaTransaction' => new Map<String, Object>{
                'vaAccountNumber' => p.VirtualAccountNumber__c,
                'depositAmount'   => '5000'    // 10000 未満
            }
        });
        initRestContext(body, 'va-deposit-transaction', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('short_payment'));
    }

    // ── 署名不正 ─────────────────────────────────────────────────────

    @isTest
    static void testInvalidSignature() {
        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        cfg.GmoAozoraWebhookSecret__c = 'my-webhook-secret';
        upsert cfg;

        initRestContext('{}', 'va-deposit-transaction', 'bad-sig');

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    // ── 無視イベント ─────────────────────────────────────────────────

    @isTest
    static void testIgnoredEventType() {
        initRestContext('{}', 'other-event-type', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('ignored'));
    }

    // ── vaTransaction 欠落 ────────────────────────────────────────────

    @isTest
    static void testMissingVaTransaction() {
        initRestContext('{}', 'va-deposit-transaction', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ── vaAccountNumber 欠落 ──────────────────────────────────────────

    @isTest
    static void testMissingVaAccountNumber() {
        String body = JSON.serialize(new Map<String, Object>{
            'vaTransaction' => new Map<String, Object>{
                'depositAmount' => '10000'
            }
        });
        initRestContext(body, 'va-deposit-transaction', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ── 対応 Payment__c なし ──────────────────────────────────────────

    @isTest
    static void testNoMatchingPayment() {
        String body = JSON.serialize(new Map<String, Object>{
            'vaTransaction' => new Map<String, Object>{
                'vaAccountNumber' => 'NONEXISTENT-VA',
                'depositAmount'   => '10000'
            }
        });
        initRestContext(body, 'va-deposit-transaction', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('no_match'));
    }

    // ── 自動振込 ON（成功）────────────────────────────────────────────

    @isTest
    static void testValidDepositWithAutoTransfer() {
        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        cfg.GmoAozoraAutoTransferEnabled__c        = true;
        cfg.GmoAozoraMode__c                        = 'テスト';
        cfg.GmoAozoraClientId__c                    = 'cid';
        cfg.GmoAozoraClientSecret__c                = 'csec';
        cfg.GmoAozoraRefreshToken__c                = 'rt-test';
        cfg.GmoAozoraAutoTransferAccountId__c       = 'acc-001';
        cfg.GmoAozoraAutoTransferBankCode__c        = '0001';
        cfg.GmoAozoraAutoTransferBranchCode__c      = '001';
        cfg.GmoAozoraAutoTransferAccountNumber__c   = '1234567';
        cfg.GmoAozoraAutoTransferBeneficiaryName__c = 'テスト カイシャ';
        upsert cfg;

        Payment__c p = [SELECT Id, VirtualAccountNumber__c, Amount__c FROM Payment__c LIMIT 1];
        String body = JSON.serialize(new Map<String, Object>{
            'vaTransaction' => new Map<String, Object>{
                'vaAccountNumber' => p.VirtualAccountNumber__c,
                'depositAmount'   => String.valueOf(p.Amount__c.intValue()),
                'vaId'            => 'VA-003'
            }
        });
        initRestContext(body, 'va-deposit-transaction', null);

        Test.setMock(HttpCalloutMock.class, new MockTransferSuccess());
        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Payment__c updated = [SELECT PaymentStatus__c, AutoTransferStatus__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('支払済み',   updated.PaymentStatus__c);
        System.assertEquals('振込依頼済', updated.AutoTransferStatus__c);
    }

    // ── 自動振込 ON・設定不完全（振込スキップ）────────────────────────

    @isTest
    static void testAutoTransferIncompleteConfig() {
        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        cfg.GmoAozoraAutoTransferEnabled__c = true;
        cfg.GmoAozoraRefreshToken__c        = 'rt-test';
        // BankCode 等未設定 → isTransferConfigComplete = false
        upsert cfg;

        Payment__c p = [SELECT Id, VirtualAccountNumber__c, Amount__c FROM Payment__c LIMIT 1];
        String body = JSON.serialize(new Map<String, Object>{
            'vaTransaction' => new Map<String, Object>{
                'vaAccountNumber' => p.VirtualAccountNumber__c,
                'depositAmount'   => String.valueOf(p.Amount__c.intValue())
            }
        });
        initRestContext(body, 'va-deposit-transaction', null);

        Test.startTest();
        GmoAozoraWebhookController.handleDepositNotification();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Payment__c updated = [SELECT AutoTransferStatus__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('未実行', updated.AutoTransferStatus__c, '設定不完全のため振込スキップ');
    }
}
