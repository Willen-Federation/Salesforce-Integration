import { LightningElement, track } from 'lwc';
import getPortalConfig from '@salesforce/apex/PortalConfigController.getPortalConfig';
import savePortalConfig from '@salesforce/apex/PortalConfigController.savePortalConfig';

export default class PortalConfigAdmin extends LightningElement {
    @track config = {};
    @track isLoading = false;
    @track saveSuccess = false;
    @track errorMessage = '';

    pendingChanges = {};

    modeOptions = [
        { label: 'テスト', value: 'テスト' },
        { label: '本番', value: '本番' }
    ];

    providerOptions = [
        { label: 'GMOあおぞら（銀行振込）', value: 'GMOあおぞら' },
        { label: 'Pay.jp',                 value: 'Pay.jp' },
        { label: 'Omise',                  value: 'Omise' },
        { label: 'Stripe',                 value: 'Stripe' },
        { label: 'Fincode',                value: 'Fincode' },
        { label: '口座振替',               value: '口座振替' },
    ];

    connectedCallback() {
        this.loadConfig();
    }

    loadConfig() {
        this.isLoading = true;
        getPortalConfig()
            .then(data => {
                this.config = { ...data };
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error.body?.message || '設定の読み込みに失敗しました。';
                this.isLoading = false;
            });
    }

    handleChange(event) {
        const key = event.target.dataset.key;
        this.pendingChanges[key] = event.target.value;
    }

    handleCheckChange(event) {
        const key = event.target.dataset.key;
        this.pendingChanges[key] = event.target.checked;
    }

    handleSave() {
        this.isLoading = true;
        this.saveSuccess = false;
        this.errorMessage = '';

        savePortalConfig({ settings: this.pendingChanges })
            .then(() => {
                this.saveSuccess = true;
                this.pendingChanges = {};
                this.isLoading = false;
                this.loadConfig();
                setTimeout(() => { this.saveSuccess = false; }, 4000);
            })
            .catch(error => {
                this.errorMessage = error.body?.message || '保存に失敗しました。';
                this.isLoading = false;
            });
    }
}
