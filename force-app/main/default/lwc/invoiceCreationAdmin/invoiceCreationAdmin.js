import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchMembers             from '@salesforce/apex/PaymentController.searchMembers';
import getActivePaymentMethods   from '@salesforce/apex/PaymentController.getActivePaymentMethods';
import getPlatformFeeConfig      from '@salesforce/apex/PaymentController.getPlatformFeeConfig';
import createPaymentWithNotification from '@salesforce/apex/PaymentController.createPaymentWithNotification';

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

    // 手数料設定
    _platformFeeEnabled = false;
    _platformFeeRate    = 0;
    _platformFeeLabel   = 'プラットフォーム利用手数料';

    paymentTypeOptions   = PAYMENT_TYPE_OPTIONS;
    notificationOptions  = NOTIFICATION_OPTIONS;

    _searchTimer = null;

    connectedCallback() {
        this.loadPaymentMethods();
        this.loadPlatformFeeConfig();
    }

    async loadPlatformFeeConfig() {
        try {
            const cfg = await getPlatformFeeConfig();
            this._platformFeeEnabled = cfg.enabled;
            this._platformFeeRate    = cfg.rate || 0;
            this._platformFeeLabel   = cfg.label || 'プラットフォーム利用手数料';
        } catch (e) {
            // 手数料なしで続行
        }
    }

    async loadPaymentMethods() {
        try {
            const methods = await getActivePaymentMethods();
            this.paymentMethodList = methods.map(m => ({
                ...m,
                checked:        false,
                feeDescription: this._buildFeeDesc(m),
            }));
        } catch (e) {
            this.showToast('警告', '決済手段の読み込みに失敗しました。', 'warning');
        }
    }

    _buildFeeDesc(method) {
        if (method.feeType === 'percent' && method.feeValue > 0) {
            return `手数料 ${method.feeValue}%`;
        } else if (method.feeType === 'fixed' && method.feeValue > 0) {
            return `手数料 ¥${method.feeValue.toLocaleString('ja-JP')}`;
        }
        return '手数料なし';
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
    }

    handleAmountChange(event) {
        const v = parseFloat(event.target.value);
        this.form = { ...this.form, baseAmount: isNaN(v) ? null : v };
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

    get platformFeeLabel() { return this._platformFeeLabel; }

    get platformFeeAmount() {
        if (!this._platformFeeEnabled || !this.form.baseAmount || this._platformFeeRate <= 0) return 0;
        return Math.round(this.form.baseAmount * this._platformFeeRate / 100);
    }

    get hasPlatformFee() { return this.platformFeeAmount > 0; }

    get selectedMethodFee() {
        // 複数手段選択時は最大手数料を表示（参考値）
        const base = this.form.baseAmount || 0;
        let maxFee = 0;
        for (const m of this.paymentMethodList) {
            if (!m.checked) continue;
            let fee = 0;
            if (m.feeType === 'percent') {
                fee = Math.round(base * m.feeValue / 100);
            } else if (m.feeType === 'fixed') {
                fee = m.feeValue;
            }
            if (fee > maxFee) maxFee = fee;
        }
        return maxFee;
    }

    get hasMethodFee() { return this.selectedMethodFee > 0; }

    get totalAmount() {
        return (this.form.baseAmount || 0) + this.platformFeeAmount + this.selectedMethodFee;
    }

    _formatYen(val) {
        return val != null
            ? '¥' + Number(val).toLocaleString('ja-JP')
            : '¥ ---';
    }

    get formattedBaseAmount()  { return this._formatYen(this.form.baseAmount); }
    get formattedPlatformFee() { return this._formatYen(this.platformFeeAmount); }
    get formattedMethodFee()   { return this._formatYen(this.selectedMethodFee); }
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
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
