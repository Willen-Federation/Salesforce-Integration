/**
 * Payment__c 作成時に GMOあおぞら振込入金口座を自動発行するトリガーハンドラ。
 * DefaultPaymentProvider__c が 'GMOあおぞら' かつ RefreshToken が設定されている場合のみ動作。
 */
public with sharing class PaymentVaTriggerHandler {

    public static void handleAfterInsert(List<Payment__c> newPayments) {
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        if (cfg?.DefaultPaymentProvider__c != 'GMOあおぞら') return;
        if (String.isBlank(cfg?.GmoAozoraRefreshToken__c))   return;

        List<Id> toIssue = new List<Id>();
        for (Payment__c p : newPayments) {
            if (p.PaymentStatus__c == '未払い' && String.isBlank(p.VirtualAccountNumber__c)) {
                toIssue.add(p.Id);
            }
        }
        if (!toIssue.isEmpty()) {
            issueVirtualAccountsAsync(toIssue);
        }
    }

    @future(callout=true)
    private static void issueVirtualAccountsAsync(List<Id> paymentIds) {
        for (Id paymentId : paymentIds) {
            try {
                GmoAozoraService.createVirtualAccount(paymentId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'Auto VA issue failed for ' + paymentId + ': ' + e.getMessage());
            }
        }
    }
}
