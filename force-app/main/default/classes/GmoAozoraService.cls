public with sharing class GmoAozoraService {

    public class GmoAozoraException extends Exception {}

    private static final String BANK_CODE = '0310';
    private static final String BANK_NAME = 'GMOあおぞらネット銀行';
    private static final String STG_BASE  = 'https://stg-api.gmo-aozora.com';
    private static final String PROD_BASE = 'https://api.gmo-aozora.com';
    private static final String AUTH_PATH = '/ganb/api/auth/v1/token';
    private static final String CORP_V1   = '/ganb/api/corporation/v1';

    public class VirtualAccountResult {
        @AuraEnabled public String  bankCode;
        @AuraEnabled public String  bankName;
        @AuraEnabled public String  branchCode;
        @AuraEnabled public String  branchNameKana;
        @AuraEnabled public String  accountNumber;
        @AuraEnabled public String  holderNameKana;
        @AuraEnabled public String  expiresAt;
        @AuraEnabled public String  transferId;
        @AuraEnabled public Decimal amount;
    }

    // ──────────────────────────────────────────────
    // デフォルト決済プロバイダーを返す
    // ──────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static String getDefaultProvider() {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        return String.isNotBlank(cfg?.DefaultPaymentProvider__c)
               ? cfg.DefaultPaymentProvider__c : 'GMOあおぞら';
    }

    // ──────────────────────────────────────────────
    // 保存済みバーチャル口座情報を返す
    // ──────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static VirtualAccountResult getVirtualAccountInfo(Id paymentId) {
        Payment__c p = [
            SELECT Id, Amount__c,
                   VirtualAccountNumber__c, VirtualAccountBranchCode__c,
                   VirtualAccountBranchName__c, VirtualAccountName__c,
                   VirtualAccountExpiresAt__c, GmoTransferId__c
            FROM Payment__c
            WHERE Id = :paymentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (String.isBlank(p.VirtualAccountNumber__c)) return null;

        VirtualAccountResult r = new VirtualAccountResult();
        r.bankCode       = BANK_CODE;
        r.bankName       = BANK_NAME;
        r.branchCode     = p.VirtualAccountBranchCode__c;
        r.branchNameKana = p.VirtualAccountBranchName__c;
        r.accountNumber  = p.VirtualAccountNumber__c;
        r.holderNameKana = p.VirtualAccountName__c;
        r.expiresAt      = p.VirtualAccountExpiresAt__c != null
                           ? p.VirtualAccountExpiresAt__c.format() : '';
        r.transferId     = p.GmoTransferId__c;
        r.amount         = p.Amount__c;
        return r;
    }

    // ──────────────────────────────────────────────
    // 振込入金口座を発行し Payment__c へ保存して返す
    // POST /ganb/api/corporation/v1/va/issue
    // ──────────────────────────────────────────────
    @AuraEnabled
    public static VirtualAccountResult createVirtualAccount(Id paymentId) {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();

        if (String.isBlank(cfg?.GmoAozoraClientId__c) || String.isBlank(cfg?.GmoAozoraClientSecret__c)) {
            throw new AuraHandledException('GMOあおぞらのクライアントID/シークレットが設定されていません。');
        }
        if (String.isBlank(cfg?.GmoAozoraRefreshToken__c)) {
            throw new AuraHandledException('GMOあおぞらのリフレッシュトークンが設定されていません。管理者に連絡してください。');
        }

        Payment__c payment = [
            SELECT Id, Amount__c, VirtualAccountNumber__c
            FROM Payment__c
            WHERE Id = :paymentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // 既に発行済みなら再利用
        if (String.isNotBlank(payment.VirtualAccountNumber__c)) {
            return getVirtualAccountInfo(paymentId);
        }

        String baseUrl = getBaseUrl(cfg);
        String token   = fetchAccessToken(cfg, baseUrl);

        // 振込入金口座_発行リクエスト
        Map<String, Object> reqBody = new Map<String, Object>{
            'vaTypeCode'        => '2',  // 継続型（有効期限なし）
            'issueRequestCount' => '1'
        };
        if (String.isNotBlank(cfg.GmoAozoraRaId__c)) {
            reqBody.put('raId', cfg.GmoAozoraRaId__c);
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + CORP_V1 + '/va/issue');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-access-token', token);
        req.setBody(JSON.serialize(reqBody));
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 201) {
            throw new GmoAozoraException(
                '振込入金口座の発行に失敗しました [' + res.getStatusCode() + ']: ' + res.getBody()
            );
        }

        Map<String, Object> data   = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        vaList = (List<Object>) data.get('vaList');
        if (vaList == null || vaList.isEmpty()) {
            throw new GmoAozoraException('振込入金口座の発行結果が空でした。');
        }
        Map<String, Object> va = (Map<String, Object>) vaList[0];

        String vaId            = (String) va.get('vaId');
        String vaBranchCode    = (String) va.get('vaBranchCode');
        String vaBranchNameKana = (String) va.get('vaBranchNameKana');
        String vaAccountNumber = (String) va.get('vaAccountNumber');
        String holderNameKana  = (String) data.get('vaHolderNameKana');
        String expireDt        = (String) data.get('expireDateTime');

        Date expiresDate = null;
        if (String.isNotBlank(expireDt)) {
            try { expiresDate = Date.valueOf(expireDt.substring(0, 10)); } catch (Exception ex) {}
        }

        update new Payment__c(
            Id                          = paymentId,
            PaymentMethod__c            = 'GMOあおぞら銀行振込',
            VirtualAccountNumber__c     = vaAccountNumber,
            VirtualAccountBranchCode__c = vaBranchCode,
            VirtualAccountBranchName__c = vaBranchNameKana,
            VirtualAccountName__c       = holderNameKana,
            VirtualAccountExpiresAt__c  = expiresDate,
            GmoTransferId__c            = vaId
        );

        VirtualAccountResult result = new VirtualAccountResult();
        result.bankCode       = BANK_CODE;
        result.bankName       = BANK_NAME;
        result.branchCode     = vaBranchCode;
        result.branchNameKana = vaBranchNameKana;
        result.accountNumber  = vaAccountNumber;
        result.holderNameKana = holderNameKana;
        result.expiresAt      = expireDt != null ? expireDt : '';
        result.transferId     = vaId;
        result.amount         = payment.Amount__c;
        return result;
    }

    // ──────────────────────────────────────────────
    // OAuth 2.0 リフレッシュトークンでアクセストークンを取得
    // POST /ganb/api/auth/v1/token
    // ──────────────────────────────────────────────
    @TestVisible
    private static String fetchAccessToken(PortalConfiguration__c cfg, String baseUrl) {
        String reqBody = 'grant_type=refresh_token'
            + '&refresh_token=' + EncodingUtil.urlEncode(cfg.GmoAozoraRefreshToken__c, 'UTF-8')
            + '&client_id='     + EncodingUtil.urlEncode(cfg.GmoAozoraClientId__c,     'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(cfg.GmoAozoraClientSecret__c, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + AUTH_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(reqBody);
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new GmoAozoraException(
                'アクセストークン取得失敗 [' + res.getStatusCode() + ']: ' + res.getBody()
            );
        }

        Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken = (String) tokenData.get('access_token');
        if (String.isBlank(accessToken)) {
            throw new GmoAozoraException('アクセストークンが空です。');
        }

        // 新しいリフレッシュトークンが返された場合は保存
        String newRefresh = (String) tokenData.get('refresh_token');
        if (String.isNotBlank(newRefresh) && newRefresh != cfg.GmoAozoraRefreshToken__c) {
            cfg.GmoAozoraRefreshToken__c = newRefresh;
            update cfg;
        }

        return accessToken;
    }

    private static String getBaseUrl(PortalConfiguration__c cfg) {
        return (cfg.GmoAozoraMode__c == '本番') ? PROD_BASE : STG_BASE;
    }
}
