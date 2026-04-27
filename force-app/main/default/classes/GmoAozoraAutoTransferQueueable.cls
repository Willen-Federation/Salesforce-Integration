/**
 * 入金確認後の自動振込をキュー実行する Queueable。
 * GmoAozoraWebhookController が deposit 確定後に enqueue する。
 */
public class GmoAozoraAutoTransferQueueable implements Queueable, Database.AllowsCallouts {

    private final Id    paymentId;
    private final Decimal depositAmount;

    public GmoAozoraAutoTransferQueueable(Id paymentId, Decimal depositAmount) {
        this.paymentId     = paymentId;
        this.depositAmount = depositAmount;
    }

    public void execute(QueueableContext ctx) {
        GmoAozoraTransferService.executeAutoTransfer(paymentId, depositAmount);
    }
}
