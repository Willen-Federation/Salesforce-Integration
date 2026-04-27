import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllRecurringPlans  from '@salesforce/apex/RecurringPaymentScheduler.getAllRecurringPlans';
import createRecurringPlan  from '@salesforce/apex/RecurringPaymentScheduler.createRecurringPlan';
import toggleRecurringPlan  from '@salesforce/apex/RecurringPaymentScheduler.toggleRecurringPlan';
import deleteRecurringPlan  from '@salesforce/apex/RecurringPaymentScheduler.deleteRecurringPlan';
import generateDuePayments  from '@salesforce/apex/RecurringPaymentScheduler.generateDuePayments';
import searchMembers        from '@salesforce/apex/PaymentController.searchMembers';
import getSchedulerStatus   from '@salesforce/apex/PortalSchedulerController.getSchedulerStatus';

const PAYMENT_TYPE_OPTIONS = [
    { label: '年会費',         value: '年会費' },
    { label: '個別利用料',     value: '個別利用料' },
    { label: 'イベント参加費', value: 'イベント参加費' },
    { label: 'その他',         value: 'その他' },
];

const FREQUENCY_OPTIONS = [
    { label: '月次（毎月）',         value: '月次' },
    { label: '四半期（3ヶ月ごと）',  value: '四半期' },
    { label: '半期（6ヶ月ごと）',    value: '半期' },
    { label: '年次（毎年）',         value: '年次' },
];

const EMPTY_FORM = {
    planName:          '',
    paymentType:       '年会費',
    baseAmount:        null,
    frequency:         '年次',
    startDate:         '',
    endDate:           '',
    daysBeforeDue:     7,
    allowedMethodKeys: '',
    description:       '',
};

export default class RecurringPaymentAdmin extends LightningElement {
    @track plans            = [];
    @track isLoading        = false;
    @track errorMessage     = '';
    @track successMessage   = '';
    @track schedulerEnabled = true; // デフォルト true で表示をブロックしない

    @track showModal      = false;
    @track isSaving       = false;
    @track modalError     = '';
    @track form           = { ...EMPTY_FORM };

    @track memberSearchInput  = '';
    @track memberResults      = [];
    @track showMemberDropdown = false;
    @track selectedMember     = null;

    paymentTypeOptions = PAYMENT_TYPE_OPTIONS;
    frequencyOptions   = FREQUENCY_OPTIONS;
    _searchTimer       = null;

    connectedCallback() {
        this.loadPlans();
        this.checkScheduler();
    }

    async checkScheduler() {
        try {
            const status = await getSchedulerStatus();
            this.schedulerEnabled = status.isScheduled === true;
        } catch (e) {
            this.schedulerEnabled = true; // エラー時は警告を非表示
        }
    }

    async loadPlans() {
        this.isLoading = true;
        try {
            const data = await getAllRecurringPlans();
            this.plans = data.map(p => ({
                ...p,
                _memberName:     (p.Member__r?.LastName__c || '') + ' ' + (p.Member__r?.FirstName__c || ''),
                _formattedAmount: Number(p.BaseAmount__c || 0).toLocaleString('ja-JP'),
                _formattedNextDue: p.NextDueDate__c
                    ? new Date(p.NextDueDate__c).toLocaleDateString('ja-JP') : '―',
            }));
        } catch (e) {
            this.errorMessage = e?.body?.message || '読み込みに失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    get hasPlans() { return this.plans.length > 0; }

    handleNew() {
        this.form = { ...EMPTY_FORM };
        this.selectedMember = null;
        this.memberSearchInput = '';
        this.modalError = '';
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.modalError = '';
    }

    handleFormChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.detail.value };
    }

    handleMemberSearch(event) {
        this.memberSearchInput = event.target.value;
        clearTimeout(this._searchTimer);
        if (!this.memberSearchInput) { this.showMemberDropdown = false; return; }
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
            }
        }, 300);
    }

    handleMemberSelect(event) {
        this.selectedMember = {
            Id:       event.currentTarget.dataset.id,
            fullName: event.currentTarget.dataset.name,
            Email__c: event.currentTarget.dataset.email,
        };
        this.memberSearchInput = '';
        this.showMemberDropdown = false;
    }

    async handleSave() {
        if (!this.selectedMember) { this.modalError = '対象会員を選択してください。'; return; }
        if (!this.form.planName)   { this.modalError = 'プラン名は必須です。'; return; }
        if (!this.form.baseAmount) { this.modalError = '基本金額は必須です。'; return; }
        if (!this.form.startDate)  { this.modalError = '開始日は必須です。'; return; }

        this.isSaving = true;
        this.modalError = '';
        try {
            await createRecurringPlan({
                planData: {
                    memberId:          this.selectedMember.Id,
                    planName:          this.form.planName,
                    paymentType:       this.form.paymentType,
                    baseAmount:        this.form.baseAmount,
                    frequency:         this.form.frequency,
                    startDate:         this.form.startDate,
                    endDate:           this.form.endDate || null,
                    daysBeforeDue:     this.form.daysBeforeDue,
                    allowedMethodKeys: this.form.allowedMethodKeys || null,
                    description:       this.form.description || null,
                }
            });
            this.showToast('作成完了', '定期支払いプランを作成しました。', 'success');
            this.closeModal();
            await this.loadPlans();
        } catch (e) {
            this.modalError = e?.body?.message || '作成に失敗しました。';
        } finally {
            this.isSaving = false;
        }
    }

    async handleToggle(event) {
        const id      = event.target.dataset.id;
        const active  = event.target.checked;
        try {
            await toggleRecurringPlan({ planId: id, active });
            this.plans = this.plans.map(p => p.Id === id ? { ...p, IsActive__c: active } : p);
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '更新に失敗しました。', 'error');
        }
    }

    async handleDelete(event) {
        const id   = event.target.dataset.id;
        const plan = this.plans.find(p => p.Id === id);
        if (!confirm(`「${plan?.PlanName__c}」を削除しますか？`)) return;
        try {
            await deleteRecurringPlan({ planId: id });
            this.showToast('削除完了', 'プランを削除しました。', 'success');
            await this.loadPlans();
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '削除に失敗しました。', 'error');
        }
    }

    async handleRunNow() {
        this.errorMessage   = '';
        this.successMessage = '';
        this.isLoading = true;
        try {
            const count = await generateDuePayments();
            this.successMessage = count > 0
                ? `${count} 件の請求を生成しました。`
                : '期限が到来したプランはありませんでした。';
            await this.loadPlans();
        } catch (e) {
            this.errorMessage = e?.body?.message || '実行に失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
