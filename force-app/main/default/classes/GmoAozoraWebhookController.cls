/**
 * GMOあおぞらネット銀行 入金通知（Webhook）受信エンドポイント。
 * Salesforce Site または Experience Cloud のゲスト URL として公開すること。
 * URL: /services/apexrest/gmo-aozora/webhook
 */
@RestResource(urlMapping='/gmo-aozora/webhook/*')
global without sharing class GmoAozoraWebhookController {

    @HttpPost
    global static void handleDepositNotification() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String rawBody = req.requestBody.toString();

            // ── 署名検証 ──────────────────────────────────────────
            if (!verifyHmacSignature(rawBody, req.headers.get('X-Gmo-Signature'))) {
                res.statusCode   = 401;
                res.responseBody = Blob.valueOf('{"error":"invalid_signature"}');
                return;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(rawBody);

            // ── 入金通知の種別確認（振込入金のみ処理）───────────────
            String notificationType = (String) payload.get('notificationType');
            if (notificationType != null && notificationType != 'DEPOSIT') {
                res.statusCode   = 200;
                res.responseBody = Blob.valueOf('{"status":"skipped","reason":"not_deposit"}');
                return;
            }

            // ── ペイロード解析 ────────────────────────────────────
            String  virtualAccountNumber = (String) payload.get('accountNumber');
            String  transferId           = (String) payload.get('virtualAccountId');
            Decimal depositAmount        = toDecimal(payload.get('depositAmount'));
            String  depositDateStr       = (String) payload.get('depositDate');

            if (String.isBlank(virtualAccountNumber) || depositAmount == null) {
                res.statusCode   = 400;
                res.responseBody = Blob.valueOf('{"error":"missing_required_fields"}');
                return;
            }

            // ── 対応する Payment__c を特定 ────────────────────────
            List<Payment__c> payments = [
                SELECT Id, Amount__c, Member__c, PaymentStatus__c, GmoTransferId__c
                FROM Payment__c
                WHERE VirtualAccountNumber__c = :virtualAccountNumber
                  AND PaymentStatus__c = '未払い'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (payments.isEmpty()) {
                res.statusCode   = 200;
                res.responseBody = Blob.valueOf('{"status":"no_match","accountNumber":"' + virtualAccountNumber + '"}');
                return;
            }

            Payment__c payment = payments[0];

            // ── 不足入金チェック ──────────────────────────────────
            if (depositAmount < payment.Amount__c) {
                handleShortPayment(payment, depositAmount);
                res.statusCode   = 200;
                res.responseBody = Blob.valueOf('{"status":"short_payment","received":' + depositAmount + '}');
                return;
            }

            // ── 正常入金: 支払済みに更新 ─────────────────────────
            update new Payment__c(
                Id                   = payment.Id,
                PaymentStatus__c     = '支払済み',
                PaymentDate__c       = Date.today(),
                DepositConfirmedAt__c = Datetime.now(),
                DepositAmount__c     = depositAmount,
                GmoTransferId__c     = String.isNotBlank(transferId) ? transferId : payment.GmoTransferId__c
            );

            // 確認メール送信（非同期で DML 後に実行）
            sendConfirmationAsync(payment.Id);

            res.statusCode   = 200;
            res.responseBody = Blob.valueOf('{"status":"processed","paymentId":"' + payment.Id + '"}');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'GmoAozoraWebhook error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf('{"error":"internal_error"}');
        }
    }

    // ── HMAC-SHA256 署名検証 ──────────────────────────────────────
    private static Boolean verifyHmacSignature(String body, String signature) {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        String webhookSecret = cfg.GmoAozoraWebhookSecret__c;

        // シークレット未設定 = 開発環境として検証スキップ
        if (String.isBlank(webhookSecret)) return true;
        if (String.isBlank(signature))     return false;

        Blob   hmac     = Crypto.generateMac('HmacSHA256', Blob.valueOf(body), Blob.valueOf(webhookSecret));
        String expected = EncodingUtil.convertToHex(hmac);

        // タイミング攻撃対策: 定長比較
        return MessageDigest.isEqual(expected.toLowerCase(), signature.toLowerCase());
    }

    // ── 不足入金処理: 管理者アラートを送信 ───────────────────────
    private static void handleShortPayment(Payment__c payment, Decimal received) {
        String subject = '【要確認】不足入金が発生しました';
        String body    = '支払レコード: ' + payment.Id + '\n'
                       + '請求金額: ' + payment.Amount__c + ' 円\n'
                       + '入金確認額: ' + received + ' 円\n'
                       + '差額: ' + (payment.Amount__c - received) + ' 円\n\n'
                       + '手動で対応してください。';
        EmailNotificationService.sendAdminAlert(subject, body);
    }

    // ── 確認メール送信を @Future で DML 後に実行 ──────────────────
    @Future
    private static void sendConfirmationAsync(Id paymentId) {
        EmailNotificationService.sendPaymentConfirmation(paymentId);
    }

    // ── Object → Decimal 安全変換 ────────────────────────────────
    private static Decimal toDecimal(Object val) {
        if (val == null) return null;
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return null;
        }
    }
}
