import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getRaConfigs   from '@salesforce/apex/GmoAozoraRaConfigController.getRaConfigs';
import saveRaConfig   from '@salesforce/apex/GmoAozoraRaConfigController.saveRaConfig';
import deleteRaConfig from '@salesforce/apex/GmoAozoraRaConfigController.deleteRaConfig';

const CATEGORY_OPTIONS = [
    { label: '年会費',       value: '年会費' },
    { label: '個別利用料',   value: '個別利用料' },
    { label: 'イベント参加費', value: 'イベント参加費' },
    { label: 'その他',       value: 'その他' },
];

const EMPTY_RECORD = { id: null, name: '', paymentCategory: '', raId: '', description: '', isActive: true };

export default class GmoRaConfigAdmin extends LightningElement {
    @track configs = [];
    @track isLoading = false;
    @track saveSuccess = false;
    @track errorMessage = '';
    @track showModal = false;
    @track editRecord = { ...EMPTY_RECORD };

    categoryOptions = CATEGORY_OPTIONS;
    _wiredResult;

    @wire(getRaConfigs)
    wiredConfigs(result) {
        this._wiredResult = result;
        if (result.data) {
            this.configs = result.data.map(r => ({ ...r }));
        } else if (result.error) {
            this.errorMessage = result.error?.body?.message || '設定の読み込みに失敗しました。';
        }
    }

    get hasConfigs() { return this.configs.length > 0; }
    get modalTitle() { return this.editRecord.id ? '入金先設定を編集' : '入金先設定を新規追加'; }

    handleNew() {
        this.editRecord = { ...EMPTY_RECORD };
        this.showModal = true;
    }

    handleEdit(event) {
        const id = event.target.dataset.id;
        const cfg = this.configs.find(c => c.Id === id);
        if (!cfg) return;
        this.editRecord = {
            id:              cfg.Id,
            name:            cfg.Name,
            paymentCategory: cfg.PaymentCategory__c,
            raId:            cfg.RaId__c,
            description:     cfg.Description__c ?? '',
            isActive:        cfg.IsActive__c,
        };
        this.showModal = true;
    }

    async handleDelete(event) {
        const id = event.target.dataset.id;
        if (!confirm('この設定を削除しますか？')) return;
        this.isLoading = true;
        try {
            await deleteRaConfig({ configId: id });
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.errorMessage = e?.body?.message || '削除に失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.editRecord = { ...this.editRecord, [field]: event.target.value };
    }

    handleCheckField(event) {
        const field = event.target.dataset.field;
        this.editRecord = { ...this.editRecord, [field]: event.target.checked };
    }

    async handleSave() {
        const inputs = this.template.querySelectorAll('lightning-input[required], lightning-combobox[required]');
        let valid = true;
        inputs.forEach(i => { i.reportValidity(); if (!i.checkValidity()) valid = false; });
        if (!valid) return;

        this.isLoading = true;
        this.errorMessage = '';
        try {
            await saveRaConfig({ record: this.editRecord });
            this.saveSuccess = true;
            this.showModal = false;
            await refreshApex(this._wiredResult);
            setTimeout(() => { this.saveSuccess = false; }, 3000);
        } catch (e) {
            this.errorMessage = e?.body?.message || '保存に失敗しました。';
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.showModal = false;
    }
}
