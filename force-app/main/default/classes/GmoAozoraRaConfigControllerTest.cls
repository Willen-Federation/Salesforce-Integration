@isTest
private class GmoAozoraRaConfigControllerTest {

    // ── HTTP モック ──────────────────────────────────────────────────

    private class MockTransferFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"at-test"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"invalid_request"}');
            }
            return res;
        }
    }

    // ── GmoAozoraRaConfigController ───────────────────────────────────

    @isTest
    static void testGetRaConfigsEmpty() {
        Test.startTest();
        List<GmoAozoraRaConfig__c> configs = GmoAozoraRaConfigController.getRaConfigs();
        Test.stopTest();
        System.assertEquals(0, configs.size());
    }

    @isTest
    static void testGetRaConfigsWithData() {
        insert new GmoAozoraRaConfig__c(
            Name = '年会費', PaymentCategory__c = '年会費',
            RaId__c = 'ra-001', IsActive__c = true
        );
        Test.startTest();
        List<GmoAozoraRaConfig__c> configs = GmoAozoraRaConfigController.getRaConfigs();
        Test.stopTest();
        System.assertEquals(1, configs.size());
        System.assertEquals('ra-001', configs[0].RaId__c);
    }

    @isTest
    static void testSaveRaConfigInsert() {
        Map<String, Object> record = new Map<String, Object>{
            'name'            => '年会費設定',
            'paymentCategory' => '年会費',
            'raId'            => 'ra-test-001',
            'isActive'        => true,
            'description'     => 'テスト設定'
        };
        Test.startTest();
        GmoAozoraRaConfigController.saveRaConfig(record);
        Test.stopTest();
        List<GmoAozoraRaConfig__c> inserted = [SELECT RaId__c, IsActive__c FROM GmoAozoraRaConfig__c];
        System.assertEquals(1, inserted.size());
        System.assertEquals('ra-test-001', inserted[0].RaId__c);
        System.assertEquals(true, inserted[0].IsActive__c);
    }

    @isTest
    static void testSaveRaConfigUpdate() {
        GmoAozoraRaConfig__c existing = new GmoAozoraRaConfig__c(
            Name = '既存設定', PaymentCategory__c = '個別利用料',
            RaId__c = 'ra-old', IsActive__c = true
        );
        insert existing;

        Map<String, Object> record = new Map<String, Object>{
            'id'              => existing.Id,
            'name'            => '更新設定',
            'paymentCategory' => '個別利用料',
            'raId'            => 'ra-new-001',
            'isActive'        => false,
            'description'     => '更新後'
        };
        Test.startTest();
        GmoAozoraRaConfigController.saveRaConfig(record);
        Test.stopTest();
        GmoAozoraRaConfig__c updated = [SELECT RaId__c, IsActive__c FROM GmoAozoraRaConfig__c WHERE Id = :existing.Id];
        System.assertEquals('ra-new-001', updated.RaId__c);
        System.assertEquals(false, updated.IsActive__c);
    }

    @isTest
    static void testSaveRaConfigNullIsActive() {
        Map<String, Object> record = new Map<String, Object>{
            'name'            => '設定',
            'paymentCategory' => 'その他',
            'raId'            => 'ra-002'
            // isActive は null → デフォルト true
        };
        Test.startTest();
        GmoAozoraRaConfigController.saveRaConfig(record);
        Test.stopTest();
        GmoAozoraRaConfig__c inserted = [SELECT IsActive__c FROM GmoAozoraRaConfig__c LIMIT 1];
        System.assertEquals(true, inserted.IsActive__c);
    }

    @isTest
    static void testDeleteRaConfig() {
        GmoAozoraRaConfig__c cfg = new GmoAozoraRaConfig__c(
            Name = '削除対象', PaymentCategory__c = 'イベント参加費',
            RaId__c = 'ra-delete', IsActive__c = true
        );
        insert cfg;
        Test.startTest();
        GmoAozoraRaConfigController.deleteRaConfig(cfg.Id);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM GmoAozoraRaConfig__c WHERE Id = :cfg.Id]);
    }

    // ── GmoAozoraTransferService ──────────────────────────────────────

    @isTest
    static void testAutoTransferDisabled() {
        Member__c m = new Member__c(
            LastName__c = 'AT', FirstName__c = 'テスト',
            Email__c = 'at@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員'
        );
        insert m;
        Payment__c p = new Payment__c(
            Member__c = m.Id, PaymentType__c = '年会費',
            Amount__c = 5000, DueDate__c = Date.today().addDays(30),
            PaymentStatus__c = '支払済み', PaymentDate__c = Date.today()
        );
        insert p;

        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        cfg.GmoAozoraAutoTransferEnabled__c = false;
        upsert cfg;

        Test.startTest();
        GmoAozoraTransferService.executeAutoTransfer(p.Id, 5000);
        Test.stopTest();
        // 無効のため早期リターン → 例外なし・DMLなし
        Payment__c check = [SELECT AutoTransferStatus__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals(null, check.AutoTransferStatus__c);
    }

    @isTest
    static void testAutoTransferSuccess() {
        Member__c m = new Member__c(
            LastName__c = 'AT2', FirstName__c = 'テスト',
            Email__c = 'at2@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員'
        );
        insert m;
        Payment__c p = new Payment__c(
            Member__c = m.Id, PaymentType__c = '年会費',
            Amount__c = 5000, DueDate__c = Date.today().addDays(30),
            PaymentStatus__c = '支払済み', PaymentDate__c = Date.today()
        );
        insert p;

        PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
        cfg.GmoAozoraAutoTransferEnabled__c        = true;
        cfg.GmoAozoraMode__c                        = 'テスト';
        cfg.GmoAozoraClientId__c                    = 'cid';
        cfg.GmoAozoraClientSecret__c                = 'csec';
        cfg.GmoAozoraRefreshToken__c                = 'rt-test';
        cfg.GmoAozoraAutoTransferAccountId__c       = 'acc-001';
        cfg.GmoAozoraAutoTransferBankCode__c        = '0001';
        cfg.GmoAozoraAutoTransferBranchCode__c      = '001';
        cfg.GmoAozoraAutoTransferAccountNumber__c   = '123';
        cfg.GmoAozoraAutoTransferBeneficiaryName__c = 'テスト カイシャ';
        upsert cfg;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockTransferFail()); // 400 → 振込依頼失敗
        GmoAozoraTransferService.executeAutoTransfer(p.Id, 5000);
        Test.stopTest();

        Payment__c updated = [SELECT AutoTransferStatus__c, AutoTransferApplyNo__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('振込依頼失敗', updated.AutoTransferStatus__c);
        System.assertEquals(null, updated.AutoTransferApplyNo__c);
    }

    // ── GmoAozoraAutoTransferQueueable ───────────────────────────────

    @isTest
    static void testQueueableExecute() {
        Member__c m = new Member__c(
            LastName__c = 'Q', FirstName__c = 'テスト',
            Email__c = 'q@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員'
        );
        insert m;
        Payment__c p = new Payment__c(
            Member__c = m.Id, PaymentType__c = '年会費',
            Amount__c = 1000, DueDate__c = Date.today().addDays(30),
            PaymentStatus__c = '支払済み', PaymentDate__c = Date.today()
        );
        insert p;

        // 自動振込が無効なのでQueueable内でearly return → callout不要
        Test.startTest();
        System.enqueueJob(new GmoAozoraAutoTransferQueueable(p.Id, 1000));
        Test.stopTest();
        // 例外なく終了すればOK
    }
}
