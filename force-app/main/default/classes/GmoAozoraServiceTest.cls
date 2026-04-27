@isTest
private class GmoAozoraServiceTest {

    // ── HTTP モック ──────────────────────────────────────────────────

    private class MockVaSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"at-test","refresh_token":"rt-new"}');
            } else {
                res.setStatusCode(201);
                res.setBody('{"vaList":[{"vaId":"VA001","vaBranchCode":"005","vaBranchNameKana":"シブヤ","vaAccountNumber":"1234567"}],"vaHolderNameKana":"テスト カイシャ"}');
            }
            return res;
        }
    }

    private class MockTokenFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"invalid_grant"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Member__c m = new Member__c(
            LastName__c     = 'GMO',
            FirstName__c    = 'テスト',
            Email__c        = 'gmo@example.com',
            MemberStatus__c = '正会員',
            MemberType__c   = '個人会員'
        );
        insert m;

        Payment__c p = new Payment__c(
            Member__c        = m.Id,
            PaymentType__c   = '年会費',
            Amount__c        = 10000,
            DueDate__c       = Date.today().addDays(30),
            PaymentStatus__c = '未払い'
        );
        insert p;
    }

    private static void insertCfg(Boolean hasToken) {
        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        cfg.DefaultPaymentProvider__c = 'GMOあおぞら';
        cfg.GmoAozoraMode__c          = 'テスト';
        cfg.GmoAozoraClientId__c      = 'client-id';
        cfg.GmoAozoraClientSecret__c  = 'client-secret';
        cfg.GmoAozoraRaId__c          = 'ra-default';
        if (hasToken) cfg.GmoAozoraRefreshToken__c = 'rt-test';
        upsert cfg;
    }

    @isTest
    static void testGetBaseUrl() {
        PortalConfiguration__c cfgStg  = new PortalConfiguration__c(GmoAozoraMode__c = 'テスト');
        PortalConfiguration__c cfgProd = new PortalConfiguration__c(GmoAozoraMode__c = '本番');
        System.assertEquals('https://stg-api.gmo-aozora.com', GmoAozoraService.getBaseUrl(cfgStg));
        System.assertEquals('https://api.gmo-aozora.com',     GmoAozoraService.getBaseUrl(cfgProd));
    }

    @isTest
    static void testGetDefaultProvider() {
        insertCfg(false);
        Test.startTest();
        String prov = GmoAozoraService.getDefaultProvider();
        Test.stopTest();
        System.assertEquals('GMOあおぞら', prov);
    }

    @isTest
    static void testGetDefaultProviderFallback() {
        // カスタム設定未設定 → デフォルト値 'GMOあおぞら' を返す
        Test.startTest();
        String prov = GmoAozoraService.getDefaultProvider();
        Test.stopTest();
        System.assertEquals('GMOあおぞら', prov);
    }

    @isTest
    static void testGetVirtualAccountInfoNull() {
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        Test.startTest();
        GmoAozoraService.VirtualAccountResult r = GmoAozoraService.getVirtualAccountInfo(p.Id);
        Test.stopTest();
        System.assertEquals(null, r, '口座未発行の場合はnull');
    }

    @isTest
    static void testGetVirtualAccountInfoExists() {
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        update new Payment__c(
            Id                          = p.Id,
            VirtualAccountNumber__c     = '9876543',
            VirtualAccountBranchCode__c = '005',
            VirtualAccountBranchName__c = 'シブヤ',
            VirtualAccountName__c       = 'テスト カイシャ',
            GmoTransferId__c            = 'VA-EXIST-001'
        );
        Test.startTest();
        GmoAozoraService.VirtualAccountResult r = GmoAozoraService.getVirtualAccountInfo(p.Id);
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assertEquals('9876543',      r.accountNumber);
        System.assertEquals('0310',         r.bankCode);
        System.assertEquals('VA-EXIST-001', r.transferId);
    }

    @isTest
    static void testCreateVaNoConfig() {
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        Test.startTest();
        try {
            GmoAozoraService.createVirtualAccount(p.Id);
            System.assert(false, '例外が発生するべき');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateVaNoToken() {
        insertCfg(false);
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        Test.startTest();
        try {
            GmoAozoraService.createVirtualAccount(p.Id);
            System.assert(false, '例外が発生するべき');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('リフレッシュトークン'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateVaSuccess() {
        insertCfg(true);
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockVaSuccess());
        GmoAozoraService.VirtualAccountResult r = GmoAozoraService.createVirtualAccount(p.Id);
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assertEquals('1234567', r.accountNumber);
        System.assertEquals('VA001',   r.transferId);
        Payment__c updated = [SELECT VirtualAccountNumber__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('1234567', updated.VirtualAccountNumber__c);
    }

    @isTest
    static void testCreateVaAlreadyIssued() {
        insertCfg(true);
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        update new Payment__c(
            Id                          = p.Id,
            VirtualAccountNumber__c     = '9876543',
            VirtualAccountBranchCode__c = '005',
            VirtualAccountBranchName__c = 'シブヤ',
            VirtualAccountName__c       = 'テスト'
        );
        Test.startTest();
        GmoAozoraService.VirtualAccountResult r = GmoAozoraService.createVirtualAccount(p.Id);
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assertEquals('9876543', r.accountNumber);
    }

    @isTest
    static void testRefreshTokenFail() {
        insertCfg(true);
        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        String baseUrl = GmoAozoraService.getBaseUrl(cfg);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockTokenFail());
        try {
            GmoAozoraService.refreshToken(cfg, baseUrl);
            System.assert(false, '例外が発生するべき');
        } catch (GmoAozoraService.GmoAozoraException e) {
            System.assert(e.getMessage().contains('アクセストークン取得失敗'));
        }
        Test.stopTest();
    }

    @isTest
    static void testResolveRaIdWithConfig() {
        insert new GmoAozoraRaConfig__c(
            Name = '年会費設定', PaymentCategory__c = '年会費',
            RaId__c = 'ra-specific', IsActive__c = true
        );
        Test.startTest();
        String raId = GmoAozoraService.resolveRaId('年会費', 'ra-default');
        Test.stopTest();
        System.assertEquals('ra-specific', raId);
    }

    @isTest
    static void testResolveRaIdFallback() {
        Test.startTest();
        String raId = GmoAozoraService.resolveRaId('存在しない種別', 'ra-default');
        Test.stopTest();
        System.assertEquals('ra-default', raId);
    }

    @isTest
    static void testResolveRaIdNullCategory() {
        Test.startTest();
        String raId = GmoAozoraService.resolveRaId(null, 'ra-default');
        Test.stopTest();
        System.assertEquals('ra-default', raId);
    }

    @isTest
    static void testPaymentVaTriggerNoConfig() {
        // カスタム設定なし → ハンドラが早期リターン
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        Payment__c p = new Payment__c(
            Member__c        = m.Id,
            PaymentType__c   = '年会費',
            Amount__c        = 5000,
            DueDate__c       = Date.today().addDays(30),
            PaymentStatus__c = '未払い'
        );
        insert p;
        Test.stopTest();
        Payment__c updated = [SELECT VirtualAccountNumber__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals(null, updated.VirtualAccountNumber__c, 'VA発行が呼ばれないこと');
    }

    @isTest
    static void testPaymentVaTriggerWithConfig() {
        insertCfg(true);
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockVaSuccess());
        Test.startTest();
        Payment__c p = new Payment__c(
            Member__c        = m.Id,
            PaymentType__c   = '年会費',
            Amount__c        = 5000,
            DueDate__c       = Date.today().addDays(30),
            PaymentStatus__c = '未払い'
        );
        insert p;
        Test.stopTest();
        Payment__c updated = [SELECT VirtualAccountNumber__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('1234567', updated.VirtualAccountNumber__c, '@futureでVA発行されること');
    }
}
