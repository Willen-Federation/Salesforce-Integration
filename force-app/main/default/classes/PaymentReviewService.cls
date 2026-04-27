/**
 * 入金後審査ワークフローを管理するサービス。
 *
 * フロー:
 *   入金完了 → initiateReview() → 審査待ち状態 + 管理者通知
 *   管理者が承認/却下 → approvePayment() / rejectPayment() → 会員通知
 */
public with sharing class PaymentReviewService {

    // ----------------------------------------------------------------
    // 審査開始
    // ----------------------------------------------------------------

    /**
     * 支払い完了後に審査を開始する。
     * ReviewRequired__c = true の支払いが支払済みになったときに呼び出す。
     */
    @AuraEnabled
    public static void initiateReview(Id paymentId, String notes) {
        Payment__c payment = [
            SELECT Id, Name, PaymentStatus__c, ReviewRequired__c, ReviewStatus__c,
                   Member__r.Email__c, Member__r.LastName__c, Member__r.FirstName__c,
                   PaymentType__c, Amount__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        if (payment.ReviewStatus__c == '審査待ち') {
            return; // 既に審査中なら何もしない
        }

        update new Payment__c(
            Id              = paymentId,
            ReviewStatus__c = '審査待ち',
            ReviewNotes__c  = notes
        );

        PaymentStatusHistoryService.record(paymentId, payment.ReviewStatus__c, '審査待ち',
            'システム', '入金確認後、審査プロセスを開始');

        EmailNotificationService.sendReviewRequiredNotification(paymentId);

        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        if (cfg.EnableSlackNotification__c == true && String.isNotBlank(cfg.SupportSlackChannelId__c)) {
            notifySlackReviewRequired(paymentId);
        }
    }

    // ----------------------------------------------------------------
    // 承認 / 却下
    // ----------------------------------------------------------------

    @AuraEnabled
    public static void approvePayment(Id paymentId, String comment) {
        Payment__c payment = [
            SELECT Id, ReviewStatus__c, Member__r.Email__c,
                   Member__r.LastName__c, Member__r.FirstName__c, PaymentType__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        String prev = payment.ReviewStatus__c;
        update new Payment__c(
            Id              = paymentId,
            ReviewStatus__c = '承認済',
            ReviewNotes__c  = comment
        );

        PaymentStatusHistoryService.record(paymentId, prev, '承認済', '管理者', comment);
        EmailNotificationService.sendReviewResultNotification(paymentId, true, comment);
    }

    @AuraEnabled
    public static void rejectPayment(Id paymentId, String comment) {
        Payment__c payment = [
            SELECT Id, ReviewStatus__c, Member__r.Email__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        String prev = payment.ReviewStatus__c;
        update new Payment__c(
            Id              = paymentId,
            ReviewStatus__c = '却下',
            ReviewNotes__c  = comment
        );

        PaymentStatusHistoryService.record(paymentId, prev, '却下', '管理者', comment);
        EmailNotificationService.sendReviewResultNotification(paymentId, false, comment);
    }

    // ----------------------------------------------------------------
    // 審査一覧
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPendingReviews() {
        return [
            SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.Email__c, PaymentType__c, Amount__c, PaymentDate__c,
                   TransactionId__c, ReviewStatus__c, ReviewNotes__c
            FROM Payment__c
            WHERE ReviewRequired__c = true
            AND ReviewStatus__c = '審査待ち'
            WITH SECURITY_ENFORCED
            ORDER BY PaymentDate__c ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getReviewHistory() {
        return [
            SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                   PaymentType__c, Amount__c, PaymentDate__c,
                   ReviewStatus__c, ReviewNotes__c
            FROM Payment__c
            WHERE ReviewRequired__c = true
            AND ReviewStatus__c IN ('承認済', '却下')
            WITH SECURITY_ENFORCED
            ORDER BY PaymentDate__c DESC
            LIMIT 100
        ];
    }

    // ----------------------------------------------------------------
    // Private
    // ----------------------------------------------------------------

    @Future(callout=true)
    private static void notifySlackReviewRequired(Id paymentId) {
        try {
            Payment__c p = [
                SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                       PaymentType__c, Amount__c
                FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
            ];
            String msg = ':mag: 【審査依頼】'
                + p.Member__r.LastName__c + ' ' + p.Member__r.FirstName__c + ' 様の '
                + p.PaymentType__c + '（¥' + p.Amount__c.longValue() + '）の入金が確認されました。'
                + '審査が必要です。管理画面でご確認ください。';
            PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
            SlackIntegrationService.sendMessage(cfg.SupportSlackChannelId__c, msg);
        } catch (Exception e) {
            System.debug('Slack review notify failed: ' + e.getMessage());
        }
    }
}
