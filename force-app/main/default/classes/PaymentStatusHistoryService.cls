/**
 * Payment__c のステータス変更を PaymentStatusHistory__c に記録するサービス。
 */
public with sharing class PaymentStatusHistoryService {

    public static void record(Id paymentId, String oldStatus, String newStatus,
                               String actor, String notes) {
        try {
            insert new PaymentStatusHistory__c(
                Payment__c   = paymentId,
                OldStatus__c = oldStatus,
                NewStatus__c = newStatus,
                ChangedAt__c = System.now(),
                ChangedBy__c = UserInfo.getName(),
                Actor__c     = actor,
                Notes__c     = notes
            );
        } catch (Exception e) {
            System.debug('PaymentStatusHistoryService.record failed: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PaymentStatusHistory__c> getHistory(Id paymentId) {
        return [
            SELECT Id, OldStatus__c, NewStatus__c, ChangedAt__c,
                   ChangedBy__c, Actor__c, Notes__c
            FROM PaymentStatusHistory__c
            WHERE Payment__c = :paymentId
            WITH SECURITY_ENFORCED
            ORDER BY ChangedAt__c ASC
        ];
    }
}
