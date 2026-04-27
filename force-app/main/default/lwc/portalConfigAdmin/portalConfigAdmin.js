import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPortalConfig      from '@salesforce/apex/PortalConfigController.getPortalConfig';
import savePortalConfig     from '@salesforce/apex/PortalConfigController.savePortalConfig';
import getSchedulerStatus   from '@salesforce/apex/PortalSchedulerController.getSchedulerStatus';
import enableScheduler      from '@salesforce/apex/PortalSchedulerController.enableScheduler';
import disableScheduler     from '@salesforce/apex/PortalSchedulerController.disableScheduler';

export default class PortalConfigAdmin extends LightningElement {
    @track config          = {};
    @track isLoading       = false;
    @track saveSuccess     = false;
    @track errorMessage    = '';
    @track schedulerStatus = { isScheduled: false };
    @track schedulerLoading = false;

    pendingChanges = {};

    modeOptions = [
        { label: 'テスト', value: 'テスト' },
        { label: '本番',   value: '本番'   }
    ];

    connectedCallback() {
        this.loadConfig();
        this.loadSchedulerStatus();
    }

    async loadSchedulerStatus() {
        this.schedulerLoading = true;
        try {
            this.schedulerStatus = await getSchedulerStatus();
        } catch (e) {
            this.schedulerStatus = { isScheduled: false };
        } finally {
            this.schedulerLoading = false;
        }
    }

    async handleEnableScheduler() {
        this.schedulerLoading = true;
        try {
            await enableScheduler();
            this.dispatchEvent(new ShowToastEvent({
                title: '有効化完了',
                message: '定期支払いスケジューラーを有効化しました。毎日 01:00 に自動実行されます。',
                variant: 'success'
            }));
            await this.loadSchedulerStatus();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'エラー',
                message: e?.body?.message || '有効化に失敗しました。',
                variant: 'error'
            }));
            this.schedulerLoading = false;
        }
    }

    async handleDisableScheduler() {
        this.schedulerLoading = true;
        try {
            await disableScheduler();
            this.dispatchEvent(new ShowToastEvent({
                title: '無効化完了',
                message: '定期支払いスケジューラーを停止しました。',
                variant: 'success'
            }));
            await this.loadSchedulerStatus();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'エラー',
                message: e?.body?.message || '無効化に失敗しました。',
                variant: 'error'
            }));
            this.schedulerLoading = false;
        }
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
