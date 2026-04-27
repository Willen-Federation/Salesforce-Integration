/**
 * GMOあおぞらネット銀行 振込依頼サービス。
 * 入金確認後に自動振込（スイープ）を実行する。
 *
 * API: POST /ganb/api/corporation/v1/transfer/request
 * ヘッダ: x-access-token, Idempotency-Key
 */
public with sharing class GmoAozoraTransferService {

    private static final String CORP_V1 = '/ganb/api/corporation/v1';

    /**
     * 自動振込を実行する。Queueable から呼ばれる。
     * callout → callout → DML の順序を守る。
     */
    public static void executeAutoTransfer(Id paymentId, Decimal depositAmount) {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();

        if (cfg == null || cfg.GmoAozoraAutoTransferEnabled__c != true) return;

        if (!isTransferConfigComplete(cfg)) {
            System.debug(LoggingLevel.WARN, 'Auto-transfer config incomplete — skipping.');
            return;
        }

        String baseUrl = GmoAozoraService.getBaseUrl(cfg);

        // Callout 1: アクセストークン取得（DMLなし）
        String[] tokens = GmoAozoraService.refreshToken(cfg, baseUrl);
        String accessToken    = tokens[0];
        String newRefreshToken = tokens[1];

        // 口座番号を7桁ゼロ埋め
        String accountNumber = cfg.GmoAozoraAutoTransferAccountNumber__c.trim();
        while (accountNumber.length() < 7) accountNumber = '0' + accountNumber;

        Map<String, Object> transfer = new Map<String, Object>{
            'transferAmount'        => String.valueOf(depositAmount.intValue()),
            'beneficiaryBankCode'   => cfg.GmoAozoraAutoTransferBankCode__c,
            'beneficiaryBranchCode' => cfg.GmoAozoraAutoTransferBranchCode__c,
            'accountTypeCode'       => String.isNotBlank(cfg.GmoAozoraAutoTransferAccountType__c)
                                       ? cfg.GmoAozoraAutoTransferAccountType__c : '1',
            'accountNumber'         => accountNumber,
            'beneficiaryName'       => cfg.GmoAozoraAutoTransferBeneficiaryName__c
        };

        Map<String, Object> body = new Map<String, Object>{
            'accountId'              => cfg.GmoAozoraAutoTransferAccountId__c,
            'transferDesignatedDate' => Date.today().format(),
            'transfers'              => new List<Object>{ transfer }
        };

        // 冪等キー: paymentId + タイムスタンプ（24時間以内の重複リクエスト防止）
        String idempotencyKey = paymentId + '-AT-' + String.valueOf(Datetime.now().getTime());

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + CORP_V1 + '/transfer/request');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-access-token', accessToken);
        req.setHeader('Idempotency-Key', idempotencyKey);
        req.setBody(JSON.serialize(body));
        req.setTimeout(30000);

        // Callout 2: 振込依頼
        HttpResponse res = new Http().send(req);

        String applyNo       = null;
        String transferStatus = '振込依頼失敗';

        if (res.getStatusCode() == 201) {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            applyNo       = (String) data.get('applyNo');
            transferStatus = '振込依頼済';
            System.debug('Auto-transfer applyNo: ' + applyNo + ' resultCode: ' + data.get('resultCode'));
        } else {
            System.debug(LoggingLevel.ERROR,
                'Auto-transfer failed [' + res.getStatusCode() + ']: ' + res.getBody());
        }

        // DML: callout 完了後にまとめて実行
        if (String.isNotBlank(newRefreshToken) && newRefreshToken != cfg.GmoAozoraRefreshToken__c) {
            cfg.GmoAozoraRefreshToken__c = newRefreshToken;
            update cfg;
        }

        update new Payment__c(
            Id                    = paymentId,
            AutoTransferApplyNo__c = applyNo,
            AutoTransferStatus__c  = transferStatus
        );
    }

    private static Boolean isTransferConfigComplete(PortalConfiguration__c cfg) {
        return String.isNotBlank(cfg.GmoAozoraRefreshToken__c)
            && String.isNotBlank(cfg.GmoAozoraAutoTransferAccountId__c)
            && String.isNotBlank(cfg.GmoAozoraAutoTransferBankCode__c)
            && String.isNotBlank(cfg.GmoAozoraAutoTransferBranchCode__c)
            && String.isNotBlank(cfg.GmoAozoraAutoTransferAccountNumber__c)
            && String.isNotBlank(cfg.GmoAozoraAutoTransferBeneficiaryName__c);
    }
}
