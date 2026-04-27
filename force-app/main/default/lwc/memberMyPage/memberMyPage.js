import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyProfile         from '@salesforce/apex/PortalMemberController.getMyProfile';
import getMyPayments        from '@salesforce/apex/PortalMemberController.getMyPayments';
import getMyRecurringPlans  from '@salesforce/apex/PortalMemberController.getMyRecurringPlans';

const REVIEW_BADGE = {
    '審査待ち': 'slds-badge slds-theme_warning',
    '承認済':   'slds-badge slds-theme_success',
    '却下':     'slds-badge slds-theme_error',
    '不要':     '',
};

export default class MemberMyPage extends LightningElement {
    @track profile        = null;
    @track payments       = [];
    @track recurringPlans = [];
    @track isLoading      = true;
    @track errorMessage   = '';

    // timelineOpen 状態: paymentId → boolean
    _timelineStates = {};

    connectedCallback() {
        this.loadAll();
    }

    async loadAll() {
        this.isLoading    = true;
        this.errorMessage = '';
        try {
            const [profile, payments, plans] = await Promise.all([
                getMyProfile(),
                getMyPayments(),
                getMyRecurringPlans(),
            ]);
            this.profile = profile;
            this.payments = payments.map(p => this._decoratePayment(p));
            this.recurringPlans = plans.map(p => this._decoratePlan(p));
        } catch (e) {
            this.errorMessage = e?.body?.message || 'データの読み込みに失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    _decoratePayment(p) {
        const formatDate = (d) => d ? new Date(d).toLocaleDateString('ja-JP') : '―';
        const formatYen  = (v) => v != null ? Number(v).toLocaleString('ja-JP') : '0';
        const open = !!this._timelineStates[p.Id];
        return {
            ...p,
            _formattedAmount:      formatYen(p.Amount__c),
            _formattedDueDate:     formatDate(p.DueDate__c),
            _formattedPaymentDate: formatDate(p.PaymentDate__c),
            _reviewBadge:          REVIEW_BADGE[p.ReviewStatus__c] || 'slds-badge',
            _showTimeline:         true,
            _timelineOpen:         open,
            _timelineLabel:        open ? 'ステータス履歴を閉じる' : 'ステータス履歴を見る',
        };
    }

    _decoratePlan(plan) {
        const formatDate = (d) => d ? new Date(d).toLocaleDateString('ja-JP') : '―';
        return {
            ...plan,
            _formattedAmount:  Number(plan.BaseAmount__c || 0).toLocaleString('ja-JP'),
            _formattedNextDue: formatDate(plan.NextDueDate__c),
            _statusLabel:      plan.IsActive__c ? '有効' : '停止中',
            _statusClass:      plan.IsActive__c ? 'slds-badge slds-theme_success' : 'slds-badge',
        };
    }

    // ----------------------------------------------------------------
    // Getter
    // ----------------------------------------------------------------

    get unpaidPayments() { return this.payments.filter(p => p.PaymentStatus__c === '未払い'); }
    get paidPayments()   { return this.payments.filter(p => p.PaymentStatus__c === '支払済み'); }
    get hasUnpaid()      { return this.unpaidPayments.length > 0; }
    get hasPaid()        { return this.paidPayments.length > 0; }
    get hasRecurringPlans() { return this.recurringPlans.length > 0; }

    get memberStatusClass() {
        if (!this.profile) return 'slds-badge';
        const status = this.profile.memberStatus;
        if (status === '正会員' || status === '準会員') return 'slds-badge slds-theme_success';
        if (status === '申請中') return 'slds-badge slds-theme_warning';
        return 'slds-badge';
    }

    // ----------------------------------------------------------------
    // イベントハンドラ
    // ----------------------------------------------------------------

    handleToggleTimeline(event) {
        const id = event.target.dataset.id;
        this._timelineStates[id] = !this._timelineStates[id];
        this.payments = this.payments.map(p => p.Id === id ? this._decoratePayment(p) : p);
    }

    handlePayClick(event) {
        const id = event.target.dataset.id;
        this.dispatchEvent(new CustomEvent('pay', { detail: { paymentId: id }, bubbles: true, composed: true }));
    }

    handleReceiptClick(event) {
        const id = event.target.dataset.id;
        window.open(`/apex/PortalReceiptPage?id=${id}`, '_blank');
    }
}
