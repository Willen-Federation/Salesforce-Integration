public with sharing class PayjpCalloutService {

    private static final String PAYJP_ENDPOINT = 'callout:PayjpAPI';

    public class PayjpException extends Exception {}

    public class ChargeResult {
        public String chargeId;
        public String status;
        public String cardBrand;
        public Boolean paid;
        public String failureMessage;
    }

    @Future(callout=true)
    public static void createChargeAsync(Id paymentId, String token, Decimal amount, String description) {
        try {
            ChargeResult result = createCharge(token, amount, description);
            if (result.paid) {
                Payment__c payment = new Payment__c(
                    Id               = paymentId,
                    PaymentStatus__c = '支払済み',
                    PaymentDate__c   = Date.today(),
                    TransactionId__c = result.chargeId,
                    PaymentProvider__c = 'Pay.jp',
                    CardBrand__c     = result.cardBrand,
                    PaymentMethod__c = 'クレジットカード（Visa/Mastercard）'
                );
                update payment;
                EmailNotificationService.sendPaymentConfirmation(paymentId);
            }
        } catch (Exception e) {
            System.debug('Pay.jp charge failed: ' + e.getMessage());
        }
    }

    public static ChargeResult createCharge(String token, Decimal amount, String description) {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        String secretKey = config.PayjpSecretKey__c;
        if (String.isBlank(secretKey)) {
            throw new PayjpException('Pay.jp シークレットキーが設定されていません。');
        }

        String credentials = EncodingUtil.base64Encode(Blob.valueOf(secretKey + ':'));
        String body = 'amount=' + Integer.valueOf(amount)
                    + '&currency=jpy'
                    + '&card=' + token
                    + '&description=' + EncodingUtil.urlEncode(description, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(PAYJP_ENDPOINT + '/charges');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Basic ' + credentials);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        HttpResponse res = new Http().send(req);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        ChargeResult result = new ChargeResult();
        if (res.getStatusCode() == 200) {
            result.chargeId  = (String) responseMap.get('id');
            result.status    = (String) responseMap.get('status');
            result.paid      = (Boolean) responseMap.get('paid');
            Map<String, Object> cardMap = (Map<String, Object>) responseMap.get('card');
            if (cardMap != null) {
                result.cardBrand = (String) cardMap.get('brand');
            }
        } else {
            Map<String, Object> errorMap = (Map<String, Object>) responseMap.get('error');
            result.paid           = false;
            result.failureMessage = errorMap != null ? (String) errorMap.get('message') : 'Unknown error';
            throw new PayjpException('Pay.jp エラー: ' + result.failureMessage);
        }
        return result;
    }

    public static String getPublicKey() {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        return config.PayjpPublicKey__c;
    }

    @AuraEnabled(cacheable=true)
    public static String getPayjpPublicKey() {
        return getPublicKey();
    }
}
