public with sharing class PaymentGatewayService {

    public class GatewayException extends Exception {}

    public class ChargeResult {
        public Boolean success;
        public String  transactionId;
        public String  provider;
        public String  failureMessage;
    }

    @AuraEnabled
    public static ChargeResult processPayment(Id paymentId, String provider, String token, Decimal amount, String description) {
        ChargeResult result = new ChargeResult();
        result.provider = provider;

        try {
            if (provider == 'Pay.jp') {
                PayjpCalloutService.ChargeResult r = PayjpCalloutService.createCharge(token, amount, description);
                result.success       = r.paid;
                result.transactionId = r.chargeId;
            } else if (provider == 'Omise') {
                result = chargeOmise(token, amount, description);
            } else if (provider == 'Stripe') {
                result = chargeStripe(token, amount, description);
            } else if (provider == 'Fincode') {
                result = chargeFincode(token, amount, description);
            } else if (provider == 'GMOあおぞら') {
                GmoAozoraService.VirtualAccountResult vaResult = GmoAozoraService.createVirtualAccount(paymentId);
                result.success       = true;
                result.transactionId = vaResult.transferId;
                result.provider      = 'GMOあおぞら';
                return result;
            } else {
                throw new GatewayException('未対応の決済プロバイダーです: ' + provider);
            }

            if (result.success) {
                Payment__c payment = new Payment__c(
                    Id                 = paymentId,
                    PaymentStatus__c   = '支払済み',
                    PaymentDate__c     = Date.today(),
                    TransactionId__c   = result.transactionId,
                    PaymentProvider__c = provider,
                    PaymentMethod__c   = 'クレジットカード（Visa/Mastercard）'
                );
                update payment;
                EmailNotificationService.sendPaymentConfirmation(paymentId);
            }
        } catch (Exception e) {
            result.success        = false;
            result.failureMessage = e.getMessage();
        }
        return result;
    }

    private static ChargeResult chargeOmise(String token, Decimal amount, String description) {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        String secretKey = config.OmiseSecretKey__c;
        if (String.isBlank(secretKey)) {
            throw new GatewayException('Omise シークレットキーが設定されていません。');
        }

        String credentials = EncodingUtil.base64Encode(Blob.valueOf(secretKey + ':'));
        String body = 'amount=' + Integer.valueOf(amount * 100)
                    + '&currency=jpy'
                    + '&card=' + token
                    + '&description=' + EncodingUtil.urlEncode(description, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OmiseAPI/charges');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Basic ' + credentials);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        HttpResponse res = new Http().send(req);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        ChargeResult result = new ChargeResult();
        result.provider = 'Omise';
        if (res.getStatusCode() == 200) {
            result.success       = true;
            result.transactionId = (String) responseMap.get('id');
        } else {
            result.success        = false;
            result.failureMessage = (String) responseMap.get('message');
            throw new GatewayException('Omise エラー: ' + result.failureMessage);
        }
        return result;
    }

    private static ChargeResult chargeStripe(String token, Decimal amount, String description) {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        String secretKey = config.StripeSecretKey__c;
        if (String.isBlank(secretKey)) {
            throw new GatewayException('Stripe シークレットキーが設定されていません。');
        }

        String body = 'amount=' + Integer.valueOf(amount)
                    + '&currency=jpy'
                    + '&source=' + token
                    + '&description=' + EncodingUtil.urlEncode(description, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:StripeAPI/charges');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + secretKey);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        HttpResponse res = new Http().send(req);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        ChargeResult result = new ChargeResult();
        result.provider = 'Stripe';
        if (res.getStatusCode() == 200) {
            result.success       = true;
            result.transactionId = (String) responseMap.get('id');
        } else {
            Map<String, Object> errMap = (Map<String, Object>) responseMap.get('error');
            result.success        = false;
            result.failureMessage = errMap != null ? (String) errMap.get('message') : 'Stripe error';
            throw new GatewayException('Stripe エラー: ' + result.failureMessage);
        }
        return result;
    }

    private static ChargeResult chargeFincode(String token, Decimal amount, String description) {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        String secretKey = config.FincodeSecretKey__c;
        String shopId    = config.FincodeShopId__c;
        if (String.isBlank(secretKey) || String.isBlank(shopId)) {
            throw new GatewayException('Fincode シークレットキー・ショップIDが設定されていません。');
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'pay_type'    => 'Card',
            'amount'      => String.valueOf(Integer.valueOf(amount)),
            'tax'         => '0',
            'card_id'     => token,
            'description' => description
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:FincodeAPI/payments');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + secretKey);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Tenant-Shop-Id', shopId);
        req.setBody(JSON.serialize(requestBody));

        HttpResponse res = new Http().send(req);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        ChargeResult result = new ChargeResult();
        result.provider = 'Fincode';
        if (res.getStatusCode() == 200) {
            result.success       = true;
            result.transactionId = (String) responseMap.get('id');
        } else {
            result.success        = false;
            result.failureMessage = (String) responseMap.get('message');
            throw new GatewayException('Fincode エラー: ' + result.failureMessage);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static String getDirectDebitFormUrl() {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        return config.DirectDebitFormUrl__c;
    }
}
