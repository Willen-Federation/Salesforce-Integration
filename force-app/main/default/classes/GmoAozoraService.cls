public with sharing class GmoAozoraService {

    public class GmoAozoraException extends Exception {}

    private static final String BANK_CODE  = '0310';
    private static final String BANK_NAME  = 'GMOあおぞらネット銀行';
    // Named Credential はモード別に切り替え
    private static final String NC_SANDBOX = 'callout:GmoAozoraAPI';
    private static final String NC_PROD    = 'callout:GmoAozoraAPI_Prod';

    public class VirtualAccountResult {
        @AuraEnabled public String  bankCode;
        @AuraEnabled public String  bankName;
        @AuraEnabled public String  branchCode;
        @AuraEnabled public String  branchName;
        @AuraEnabled public String  accountNumber;
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  expiresAt;
        @AuraEnabled public String  transferId;
        @AuraEnabled public Decimal amount;
    }

    // ──────────────────────────────────────────────
    // バーチャル口座を発行し Payment__c へ保存して返す
    // ──────────────────────────────────────────────
    @AuraEnabled
    public static VirtualAccountResult createVirtualAccount(Id paymentId) {
        Payment__c payment = [
            SELECT Id, Amount__c, DueDate__c, Name,
                   Member__r.LastName__c, Member__r.FirstName__c
            FROM Payment__c
            WHERE Id = :paymentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // 既に発行済みなら再利用
        if (String.isNotBlank(payment.VirtualAccountNumber__c)) {
            return getVirtualAccountInfo(paymentId);
        }

        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        String baseUrl = resolveBaseUrl(cfg);
        String token   = fetchAccessToken(cfg, baseUrl);

        // 振込期限: DueDate__c または 14日後
        Date expiryDate = payment.DueDate__c != null
            ? payment.DueDate__c
            : Date.today().addDays(14);

        Map<String, Object> body = new Map<String, Object>{
            'depositAmount'  => Integer.valueOf(payment.Amount__c),
            'depositName'    => buildDepositName(payment.Member__r.LastName__c, payment.Member__r.FirstName__c),
            'expirationDate' => expiryDate.format(),
            'clientCode'     => payment.Name
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/virtual-accounts');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(body));
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new GmoAozoraException(
                'バーチャル口座発行エラー [' + res.getStatusCode() + ']: ' + res.getBody()
            );
        }

        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        VirtualAccountResult result = buildResult(data, payment.Amount__c);

        // Payment__c を更新
        Payment__c upd = new Payment__c(
            Id                          = paymentId,
            PaymentMethod__c            = 'GMOあおぞら銀行振込',
            PaymentProvider__c          = 'GMOあおぞら',
            VirtualAccountNumber__c     = result.accountNumber,
            VirtualAccountBranchCode__c = result.branchCode,
            VirtualAccountBranchName__c = result.branchName,
            VirtualAccountName__c       = result.accountName,
            VirtualAccountExpiresAt__c  = expiryDate,
            GmoTransferId__c            = result.transferId
        );
        update upd;

        return result;
    }

    // ──────────────────────────────────────────────
    // 保存済みバーチャル口座情報を返す（キャッシュ可）
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

        VirtualAccountResult result = new VirtualAccountResult();
        result.bankCode      = BANK_CODE;
        result.bankName      = BANK_NAME;
        result.branchCode    = p.VirtualAccountBranchCode__c;
        result.branchName    = p.VirtualAccountBranchName__c;
        result.accountNumber = p.VirtualAccountNumber__c;
        result.accountName   = p.VirtualAccountName__c;
        result.expiresAt     = p.VirtualAccountExpiresAt__c != null
                               ? p.VirtualAccountExpiresAt__c.format() : '';
        result.transferId    = p.GmoTransferId__c;
        result.amount        = p.Amount__c;
        return result;
    }

    // ──────────────────────────────────────────────
    // デフォルト決済プロバイダーを返す
    // ──────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static String getDefaultProvider() {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        return String.isNotBlank(cfg.DefaultPaymentProvider__c)
               ? cfg.DefaultPaymentProvider__c : 'GMOあおぞら';
    }

    // ──────────────────────────────────────────────
    // OAuth 2.0 アクセストークン取得 (Client Credentials)
    // ──────────────────────────────────────────────
    @TestVisible
    private static String fetchAccessToken(PortalConfiguration__c cfg, String baseUrl) {
        if (String.isBlank(cfg.GmoAozoraClientId__c) || String.isBlank(cfg.GmoAozoraClientSecret__c)) {
            throw new GmoAozoraException('GMOあおぞらネット銀行のクライアントID/シークレットが未設定です。');
        }

        String requestBody = 'grant_type=client_credentials'
            + '&client_id='     + EncodingUtil.urlEncode(cfg.GmoAozoraClientId__c,     'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(cfg.GmoAozoraClientSecret__c, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(requestBody);
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new GmoAozoraException('トークン取得失敗 [' + res.getStatusCode() + ']: ' + res.getBody());
        }

        Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String token = (String) tokenData.get('access_token');
        if (String.isBlank(token)) {
            throw new GmoAozoraException('アクセストークンが空です。');
        }
        return token;
    }

    private static String resolveBaseUrl(PortalConfiguration__c cfg) {
        return (cfg.GmoAozoraMode__c == '本番') ? NC_PROD : NC_SANDBOX;
    }

    // 振込依頼人名（口座名義）: 姓名を半角英大文字に変換（20文字以内）
    @TestVisible
    private static String buildDepositName(String lastName, String firstName) {
        String combined = ((lastName ?? '') + ' ' + (firstName ?? '')).trim();
        // 全角スペース → 半角、英小文字 → 大文字、長さ制限
        return combined.normalizeSpace().toUpperCase().left(20);
    }

    private static VirtualAccountResult buildResult(Map<String, Object> data, Decimal amount) {
        VirtualAccountResult r = new VirtualAccountResult();
        r.bankCode      = BANK_CODE;
        r.bankName      = BANK_NAME;
        r.branchCode    = (String) data.get('branchCode');
        r.branchName    = (String) data.get('branchName');
        r.accountNumber = (String) data.get('accountNumber');
        r.accountName   = (String) data.get('depositName');
        r.expiresAt     = (String) data.get('expirationDate');
        r.transferId    = (String) data.get('virtualAccountId');
        r.amount        = amount;
        return r;
    }
}
