import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchMembers                 from '@salesforce/apex/PaymentController.searchMembers';
import getActivePaymentMethods       from '@salesforce/apex/PaymentController.getActivePaymentMethods';
import createPaymentWithNotification from '@salesforce/apex/PaymentController.createPaymentWithNotification';
import calculateCreationFees         from '@salesforce/apex/PaymentFeeRuleController.calculateCreationFees';

const PAYMENT_TYPE_OPTIONS = [
    { label: '年会費',           value: '年会費' },
    { label: '個別利用料',       value: '個別利用料' },
    { label: 'イベント参加費',   value: 'イベント参加費' },
    { label: 'その他',           value: 'その他' },
];

const NOTIFICATION_OPTIONS = [
    { label: 'メールのみ',        value: 'email' },
    { label: 'Slackのみ',         value: 'slack' },
    { label: 'メール＋Slack',     value: 'both' },
    { label: '通知しない',        value: 'none' },
];

export default class InvoiceCreationAdmin extends LightningElement {
    @track form = {
        paymentType:          '年会費',
        baseAmount:           null,
        dueDate:              '',
        description:          '',
        notificationChannels: 'email',
    };

    @track memberSearchInput = '';
    @track memberResults     = [];
    @track showMemberDropdown = false;
    @track selectedMember    = null;

    @track paymentMethodList = [];
    @track isLoading         = false;
    @track successMessage    = '';
    @track errorMessage      = '';

    // 手数料計算結果（calculateCreationFees の結果）
    @track _feeResult = null;

    paymentTypeOptions   = PAYMENT_TYPE_OPTIONS;
    notificationOptions  = NOTIFICATION_OPTIONS;

    _searchTimer    = null;
    _feeCalcTimer   = null;

    connectedCallback() {
        this.loadPaymentMethods();
    }

    async loadPaymentMethods() {
        try {
            const methods = await getActivePaymentMethods();
            this.paymentMethodList = methods.map(m => ({
                ...m,
                checked: false,
            }));
        } catch (e) {
            this.showToast('警告', '決済手段の読み込みに失敗しました。', 'warning');
        }
    }

    async _recalculateFees() {
        const base = this.form.baseAmount;
        const type = this.form.paymentType;
        if (!base || base <= 0) {
            this._feeResult = null;
            return;
        }
        try {
            this._feeResult = await calculateCreationFees({ paymentCategory: type, baseAmount: base });
        } catch (e) {
            this._feeResult = null;
        }
    }

    // ----------------------------------------------------------------
    // 会員検索
    // ----------------------------------------------------------------

    handleMemberSearch(event) {
        this.memberSearchInput = event.target.value;
        clearTimeout(this._searchTimer);
        if (this.memberSearchInput.length < 1) {
            this.showMemberDropdown = false;
            this.memberResults = [];
            return;
        }
        this._searchTimer = setTimeout(async () => {
            try {
                const results = await searchMembers({ keyword: this.memberSearchInput });
                this.memberResults = results.map(m => ({
                    ...m,
                    fullName: (m.LastName__c || '') + ' ' + (m.FirstName__c || '')
                }));
                this.showMemberDropdown = true;
            } catch (e) {
                this.memberResults = [];
                this.showMemberDropdown = true;
            }
        }, 300);
    }

    handleMemberSelect(event) {
        const id    = event.currentTarget.dataset.id;
        const name  = event.currentTarget.dataset.name;
        const email = event.currentTarget.dataset.email;
        this.selectedMember = { Id: id, fullName: name, Email__c: email };
        this.memberSearchInput = '';
        this.showMemberDropdown = false;
    }

    clearMember() {
        this.selectedMember = null;
        this.memberSearchInput = '';
    }

    get hasMemberResults() { return this.memberResults.length > 0; }

    // ----------------------------------------------------------------
    // フォーム入力
    // ----------------------------------------------------------------

    handleFormChange(event) {
        const field = event.target.dataset.field || event.target.name;
        this.form = { ...this.form, [field]: event.detail.value };
        if (field === 'paymentType') {
            this._recalculateFees();
        }
    }

    handleAmountChange(event) {
        const v = parseFloat(event.target.value);
        this.form = { ...this.form, baseAmount: isNaN(v) ? null : v };
        clearTimeout(this._feeCalcTimer);
        this._feeCalcTimer = setTimeout(() => this._recalculateFees(), 400);
    }

    handleMethodToggle(event) {
        const key     = event.target.dataset.key;
        const checked = event.target.checked;
        this.paymentMethodList = this.paymentMethodList.map(m =>
            m.methodKey === key ? { ...m, checked } : m
        );
    }

    get hasPaymentMethods() { return this.paymentMethodList.length > 0; }

    // ----------------------------------------------------------------
    // 金額計算
    // ----------------------------------------------------------------

    get platformFeeAmount() {
        return this._feeResult?.totalFeeAmount ?? 0;
    }

    get hasPlatformFee() { return this.platformFeeAmount > 0; }

    get platformFeeBreakdown() {
        return this._feeResult?.breakdown ?? [];
    }

    get totalAmount() {
        return (this.form.baseAmount || 0) + this.platformFeeAmount;
    }

    _formatYen(val) {
        return val != null
            ? '¥' + Number(val).toLocaleString('ja-JP')
            : '¥ ---';
    }

    get formattedBaseAmount()  { return this._formatYen(this.form.baseAmount); }
    get formattedPlatformFee() { return this._formatYen(this.platformFeeAmount); }
    get formattedTotalAmount() { return this._formatYen(this.totalAmount); }

    // ----------------------------------------------------------------
    // 送信
    // ----------------------------------------------------------------

    get isSubmitDisabled() {
        return this.isLoading
            || !this.selectedMember
            || !this.form.baseAmount
            || !this.form.dueDate
            || !this.form.paymentType;
    }

    async handleSubmit() {
        this.errorMessage = '';

        if (!this.selectedMember) {
            this.errorMessage = '対象会員を選択してください。';
            return;
        }

        const checkedMethods = this.paymentMethodList
            .filter(m => m.checked)
            .map(m => m.methodKey)
            .join(';');

        this.isLoading = true;
        try {
            const paymentId = await createPaymentWithNotification({
                memberId:          this.selectedMember.Id,
                paymentType:       this.form.paymentType,
                baseAmount:        this.form.baseAmount,
                dueDate:           this.form.dueDate,
                description:       this.form.description || '',
                allowedMethodKeys: checkedMethods || null,
                channels:          this.form.notificationChannels,
            });

            this.successMessage = `請求を発行しました（${this.selectedMember.fullName} 様 / ${this.formattedTotalAmount}）。` +
                (this.form.notificationChannels !== 'none' ? ' 通知を送信しました。' : '');
        } catch (e) {
            this.errorMessage = e?.body?.message || '請求の発行に失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.successMessage = '';
        this.errorMessage   = '';
        this.selectedMember = null;
        this.form = {
            paymentType:          '年会費',
            baseAmount:           null,
            dueDate:              '',
            description:          '',
            notificationChannels: 'email',
        };
        this.paymentMethodList = this.paymentMethodList.map(m => ({ ...m, checked: false }));
        this._feeResult = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
