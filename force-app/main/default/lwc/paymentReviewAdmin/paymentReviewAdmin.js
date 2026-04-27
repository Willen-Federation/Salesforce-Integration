import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingReviews from '@salesforce/apex/PaymentReviewService.getPendingReviews';
import getReviewHistory  from '@salesforce/apex/PaymentReviewService.getReviewHistory';
import approvePayment    from '@salesforce/apex/PaymentReviewService.approvePayment';
import rejectPayment     from '@salesforce/apex/PaymentReviewService.rejectPayment';

export default class PaymentReviewAdmin extends LightningElement {
    @track pendingReviews = [];
    @track reviewHistory  = [];
    @track isLoading      = false;

    // paymentId → コメント入力
    _comments = {};

    connectedCallback() {
        this.loadAll();
    }

    async loadAll() {
        this.isLoading = true;
        try {
            const [pending, history] = await Promise.all([
                getPendingReviews(),
                getReviewHistory(),
            ]);
            this.pendingReviews = pending.map(p => this._decorate(p));
            this.reviewHistory  = history.map(p => this._decorate(p));
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '読み込みに失敗しました。', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    _decorate(p) {
        const formatDate = (d) => d ? new Date(d).toLocaleDateString('ja-JP') : '―';
        return {
            ...p,
            _formattedAmount:      Number(p.Amount__c || 0).toLocaleString('ja-JP'),
            _formattedPaymentDate: formatDate(p.PaymentDate__c),
            _comment:              this._comments[p.Id] || '',
            _resultBadge: p.ReviewStatus__c === '承認済'
                ? 'slds-badge slds-theme_success'
                : 'slds-badge slds-theme_error',
        };
    }

    get hasPending()    { return this.pendingReviews.length > 0; }
    get hasHistory()    { return this.reviewHistory.length > 0; }
    get pendingTabLabel() {
        return this.pendingReviews.length > 0
            ? `審査待ち（${this.pendingReviews.length}）`
            : '審査待ち';
    }

    handleCommentChange(event) {
        const id = event.target.dataset.id;
        this._comments[id] = event.target.value;
        this.pendingReviews = this.pendingReviews.map(p =>
            p.Id === id ? { ...p, _comment: event.target.value } : p
        );
    }

    async handleApprove(event) {
        const id      = event.target.dataset.id;
        const comment = this._comments[id] || '';
        try {
            await approvePayment({ paymentId: id, comment });
            this.showToast('承認完了', '支払いを承認しました。会員に通知メールを送信しました。', 'success');
            await this.loadAll();
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '承認に失敗しました。', 'error');
        }
    }

    async handleReject(event) {
        const id      = event.target.dataset.id;
        const comment = this._comments[id] || '';
        if (!comment) {
            this.showToast('入力エラー', '却下の場合は審査コメントを入力してください。', 'warning');
            return;
        }
        try {
            await rejectPayment({ paymentId: id, comment });
            this.showToast('却下完了', '支払いを却下しました。会員に通知メールを送信しました。', 'success');
            await this.loadAll();
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '却下に失敗しました。', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
