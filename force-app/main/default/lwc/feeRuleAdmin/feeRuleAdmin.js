import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllRules  from '@salesforce/apex/PaymentFeeRuleController.getAllRules';
import saveRule    from '@salesforce/apex/PaymentFeeRuleController.saveRule';
import deleteRule  from '@salesforce/apex/PaymentFeeRuleController.deleteRule';
import toggleRule  from '@salesforce/apex/PaymentFeeRuleController.toggleRule';

const RULE_TYPE_OPTIONS = [
    { label: '全支払い共通',  value: '全支払い共通' },
    { label: 'カテゴリ別',    value: 'カテゴリ別' },
    { label: '決済手段別',    value: '決済手段別' },
];

const FEE_TYPE_OPTIONS = [
    { label: '料率（%）',   value: '料率（%）' },
    { label: '固定額（円）', value: '固定額（円）' },
];

const EMPTY_FORM = {
    id:              null,
    ruleName:        '',
    ruleType:        '全支払い共通',
    targetMethodKey: '',
    targetCategory:  '',
    feeType:         '料率（%）',
    feeValue:        0,
    feeLabel:        '',
    sortOrder:       null,
    isEnabled:       true,
};

export default class FeeRuleAdmin extends LightningElement {
    @track rules        = [];
    @track isLoading    = false;
    @track errorMessage = '';

    @track showModal    = false;
    @track isSaving     = false;
    @track modalError   = '';
    @track modalForm    = { ...EMPTY_FORM };

    ruleTypeOptions = RULE_TYPE_OPTIONS;
    feeTypeOptions  = FEE_TYPE_OPTIONS;

    connectedCallback() {
        this.loadRules();
    }

    async loadRules() {
        this.isLoading    = true;
        this.errorMessage = '';
        try {
            const data = await getAllRules();
            this.rules = data.map(r => ({
                ...r,
                _targetDisplay: this._buildTargetDisplay(r),
                _feeDisplay:    this._buildFeeDisplay(r),
            }));
        } catch (e) {
            this.errorMessage = e?.body?.message || 'ルールの読み込みに失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    _buildTargetDisplay(r) {
        if (r.RuleType__c === '決済手段別') return r.TargetMethodKey__c || '―';
        if (r.RuleType__c === 'カテゴリ別')  return r.TargetCategory__c  || '―';
        return '（全て）';
    }

    _buildFeeDisplay(r) {
        if (!r.FeeValue__c && r.FeeValue__c !== 0) return '―';
        if (r.FeeType__c === '料率（%）') return `${r.FeeValue__c}%`;
        return `¥${Number(r.FeeValue__c).toLocaleString('ja-JP')}`;
    }

    get hasRules() { return this.rules.length > 0; }

    get modalTitle() {
        return this.modalForm.id ? 'ルール編集' : '新規ルール追加';
    }

    get isMethodType()   { return this.modalForm.ruleType === '決済手段別'; }
    get isCategoryType() { return this.modalForm.ruleType === 'カテゴリ別'; }

    get feeValueLabel() {
        return this.modalForm.feeType === '料率（%）' ? '手数料率（%）' : '固定手数料額（円）';
    }

    // ----------------------------------------------------------------
    // ハンドラ
    // ----------------------------------------------------------------

    handleNewRule() {
        this.modalForm  = { ...EMPTY_FORM };
        this.modalError = '';
        this.showModal  = true;
    }

    handleEdit(event) {
        const id   = event.target.dataset.id;
        const rule = this.rules.find(r => r.Id === id);
        if (!rule) return;
        this.modalForm = {
            id:              rule.Id,
            ruleName:        rule.RuleName__c        || '',
            ruleType:        rule.RuleType__c        || '全支払い共通',
            targetMethodKey: rule.TargetMethodKey__c || '',
            targetCategory:  rule.TargetCategory__c  || '',
            feeType:         rule.FeeType__c         || '料率（%）',
            feeValue:        rule.FeeValue__c        ?? 0,
            feeLabel:        rule.FeeLabel__c        || '',
            sortOrder:       rule.SortOrder__c       ?? null,
            isEnabled:       rule.IsEnabled__c,
        };
        this.modalError = '';
        this.showModal  = true;
    }

    async handleDelete(event) {
        const id   = event.target.dataset.id;
        const rule = this.rules.find(r => r.Id === id);
        if (!rule) return;
        if (!confirm(`「${rule.RuleName__c}」を削除しますか？`)) return;
        try {
            await deleteRule({ ruleId: id });
            this.showToast('削除完了', 'ルールを削除しました。', 'success');
            await this.loadRules();
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '削除に失敗しました。', 'error');
        }
    }

    async handleToggle(event) {
        const id      = event.target.dataset.id;
        const enabled = event.target.checked;
        try {
            await toggleRule({ ruleId: id, enabled });
            this.rules = this.rules.map(r =>
                r.Id === id ? { ...r, IsEnabled__c: enabled } : r
            );
        } catch (e) {
            this.showToast('エラー', e?.body?.message || '更新に失敗しました。', 'error');
            await this.loadRules();
        }
    }

    handleModalChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value;
        this.modalForm = { ...this.modalForm, [field]: value };
    }

    handleModalToggleChange(event) {
        this.modalForm = { ...this.modalForm, isEnabled: event.target.checked };
    }

    closeModal() {
        this.showModal  = false;
        this.modalError = '';
    }

    async handleSave() {
        if (!this.modalForm.ruleName?.trim()) {
            this.modalError = 'ルール名は必須です。';
            return;
        }
        if (this.modalForm.feeValue === null || this.modalForm.feeValue === '') {
            this.modalError = '手数料値は必須です。';
            return;
        }

        const ruleData = {
            ruleName:        this.modalForm.ruleName,
            ruleType:        this.modalForm.ruleType,
            targetMethodKey: this.modalForm.targetMethodKey || null,
            targetCategory:  this.modalForm.targetCategory  || null,
            feeType:         this.modalForm.feeType,
            feeValue:        this.modalForm.feeValue,
            feeLabel:        this.modalForm.feeLabel  || null,
            sortOrder:       this.modalForm.sortOrder != null ? this.modalForm.sortOrder : null,
            isEnabled:       this.modalForm.isEnabled,
        };
        if (this.modalForm.id) {
            ruleData.id = this.modalForm.id;
        }

        this.isSaving   = true;
        this.modalError = '';
        try {
            await saveRule({ ruleData });
            this.showToast('保存完了', 'ルールを保存しました。', 'success');
            this.closeModal();
            await this.loadRules();
        } catch (e) {
            this.modalError = e?.body?.message || '保存に失敗しました。';
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
