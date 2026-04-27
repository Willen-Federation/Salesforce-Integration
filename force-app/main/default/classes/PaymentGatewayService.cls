public with sharing class PaymentGatewayService {

    public class GatewayException extends Exception {}

    public class ChargeResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  transactionId;
        @AuraEnabled public String  provider;
        @AuraEnabled public String  failureMessage;
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

    /**
     * Returns the active payment provider name and its public key.
     * Priority: Pay.jp → Omise → Stripe
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getProviderConfig() {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        Map<String, String> result = new Map<String, String>{
            'provider'  => 'none',
            'publicKey' => ''
        };

        if (String.isNotBlank(config.PayjpPublicKey__c) && String.isNotBlank(config.PayjpSecretKey__c)) {
            result.put('provider',  'Pay.jp');
            result.put('publicKey', config.PayjpPublicKey__c);
        } else if (String.isNotBlank(config.OmisePublicKey__c) && String.isNotBlank(config.OmiseSecretKey__c)) {
            result.put('provider',  'Omise');
            result.put('publicKey', config.OmisePublicKey__c);
        } else if (String.isNotBlank(config.StripePublicKey__c) && String.isNotBlank(config.StripeSecretKey__c)) {
            result.put('provider',  'Stripe');
            result.put('publicKey', config.StripePublicKey__c);
        }

        return result;
    }
}
