/**
 * GMOあおぞらネット銀行 入金通知（Webhook）受信エンドポイント。
 * Salesforce Site または Experience Cloud のゲスト URL として公開すること。
 * URL: /services/apexrest/gmo-aozora/webhook
 *
 * Webhook仕様:
 *   Header: x-eventType = "va-deposit-transaction"
 *   Header: x-webhook-signature = Base64(HMAC-SHA256(body, clientSecret))
 *   Payload: { account: {...}, vaTransaction: { vaAccountNumber, depositAmount(String), vaId, ... } }
 */
@RestResource(urlMapping='/gmo-aozora/webhook/*')
global without sharing class GmoAozoraWebhookController {

    @HttpPost
    global static void handleDepositNotification() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String rawBody   = req.requestBody.toString();
            String eventType = req.headers.get('x-eventType');
            String signature = req.headers.get('x-webhook-signature');

            // ── 署名検証（Base64エンコードされたHMAC-SHA256）──────────
            if (!verifyHmacSignature(rawBody, signature)) {
                res.statusCode   = 401;
                res.responseBody = Blob.valueOf('{"error":"invalid_signature"}');
                return;
            }

            // ── 振込入金口座への入金イベントのみ処理 ─────────────────
            if (eventType != 'va-deposit-transaction') {
                res.statusCode   = 200;
                res.responseBody = Blob.valueOf('{"status":"ignored"}');
                return;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
            Map<String, Object> vaTx    = (Map<String, Object>) payload.get('vaTransaction');

            if (vaTx == null) {
                res.statusCode   = 400;
                res.responseBody = Blob.valueOf('{"error":"missing_vaTransaction"}');
                return;
            }

            // ── ペイロード解析（vaTransactionオブジェクトから取得）────
            String  vaAccountNumber  = (String) vaTx.get('vaAccountNumber');
            String  depositAmountStr = (String) vaTx.get('depositAmount');
            String  vaId             = (String) vaTx.get('vaId');
            String  transactionDate  = (String) vaTx.get('transactionDate');

            if (String.isBlank(vaAccountNumber)) {
                res.statusCode   = 400;
                res.responseBody = Blob.valueOf('{"error":"missing_vaAccountNumber"}');
                return;
            }

            Decimal depositAmount = String.isNotBlank(depositAmountStr)
                ? Decimal.valueOf(depositAmountStr) : 0;

            // ── 対応する Payment__c を特定 ────────────────────────────
            List<Payment__c> payments = [
                SELECT Id, Amount__c, Member__c, PaymentStatus__c, GmoTransferId__c
                FROM Payment__c
                WHERE VirtualAccountNumber__c = :vaAccountNumber
                  AND PaymentStatus__c = '未払い'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (payments.isEmpty()) {
                res.statusCode   = 200;
                res.responseBody = Blob.valueOf('{"status":"no_match","vaAccountNumber":"' + vaAccountNumber + '"}');
                return;
            }

            Payment__c payment = payments[0];

            // ── 不足入金チェック ──────────────────────────────────────
            if (depositAmount < payment.Amount__c) {
                handleShortPayment(payment, depositAmount);
                res.statusCode   = 200;
                res.responseBody = Blob.valueOf('{"status":"short_payment","received":' + depositAmount + '}');
                return;
            }

            // ── 正常入金: 支払済みに更新 ──────────────────────────────
            Date paymentDate = null;
            if (String.isNotBlank(transactionDate)) {
                try { paymentDate = Date.valueOf(transactionDate); } catch (Exception ex) {}
            }

            update new Payment__c(
                Id                    = payment.Id,
                PaymentStatus__c      = '支払済み',
                PaymentDate__c        = paymentDate != null ? paymentDate : Date.today(),
                DepositConfirmedAt__c = Datetime.now(),
                DepositAmount__c      = depositAmount,
                GmoTransferId__c      = String.isNotBlank(vaId) ? vaId : payment.GmoTransferId__c
            );

            sendConfirmationAsync(payment.Id);

            res.statusCode   = 200;
            res.responseBody = Blob.valueOf('{"status":"processed","paymentId":"' + payment.Id + '"}');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'GmoAozoraWebhook error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf('{"error":"internal_error"}');
        }
    }

    // ── HMAC-SHA256 署名検証 ──────────────────────────────────────────
    // 正しいエンコード: Base64(HMAC-SHA256(body, webhookSecret))
    private static Boolean verifyHmacSignature(String body, String signature) {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        String secret = cfg?.GmoAozoraWebhookSecret__c;

        if (String.isBlank(secret)) return true;
        if (String.isBlank(signature)) return false;

        Blob   hmac     = Crypto.generateMac('HmacSHA256', Blob.valueOf(body), Blob.valueOf(secret));
        String expected = EncodingUtil.base64Encode(hmac);
        return expected == signature;
    }

    // ── 不足入金処理: 管理者アラートを送信 ───────────────────────────
    private static void handleShortPayment(Payment__c payment, Decimal received) {
        String subject = '【要確認】不足入金が発生しました';
        String body    = '支払レコード: ' + payment.Id + '\n'
                       + '請求金額: ' + payment.Amount__c + ' 円\n'
                       + '入金確認額: ' + received + ' 円\n'
                       + '差額: ' + (payment.Amount__c - received) + ' 円\n\n'
                       + '手動で対応してください。';
        EmailNotificationService.sendAdminAlert(subject, body);
    }

    // ── 確認メール送信を @Future で DML 後に実行 ──────────────────────
    @Future
    private static void sendConfirmationAsync(Id paymentId) {
        EmailNotificationService.sendPaymentConfirmation(paymentId);
    }
}
