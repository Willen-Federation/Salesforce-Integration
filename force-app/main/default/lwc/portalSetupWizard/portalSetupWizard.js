import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPortalConfig from '@salesforce/apex/PortalConfigController.getPortalConfig';
import savePortalConfig from '@salesforce/apex/PortalConfigController.savePortalConfig';
import enableScheduler from '@salesforce/apex/PortalSchedulerController.enableScheduler';
import getSchedulerStatus from '@salesforce/apex/PortalSchedulerController.getSchedulerStatus';

const STEPS = ['welcome', 'basic', 'payment', 'fees', 'auth', 'complete'];

const PROVIDER_OPTIONS = [
    { label: 'GMO あおぞら（銀行振込）', value: 'GMOあおぞら' },
    { label: 'Pay.jp',                  value: 'Pay.jp'     },
    { label: 'Omise',                   value: 'Omise'      },
    { label: 'Stripe',                  value: 'Stripe'     },
    { label: 'Fincode',                 value: 'Fincode'    },
    { label: '口座振替',                value: '口座振替'   },
];

const MODE_OPTIONS = [
    { label: 'テスト（推奨: 本番運用前）', value: 'テスト' },
    { label: '本番',                       value: '本番'   },
];

export default class PortalSetupWizard extends NavigationMixin(LightningElement) {
    @track currentStepIndex = 0;
    @track config = {
        enableSlackNotification: false,
        enableDonation:          true,
        useOkta:                 false,
        defaultPaymentProvider:  'GMOあおぞら',
        gmoAozoraMode:           'テスト',
        payjpMode:               'テスト',
        omiseMode:               'テスト',
        stripeMode:              'テスト',
        fincodeMode:             'テスト',
    };
    @track isLoading      = false;
    @track errorMessage   = '';
    @track successMessage = '';
    @track schedulerEnabled = false;

    pendingChanges = {};

    providerOptions = PROVIDER_OPTIONS;
    modeOptions     = MODE_OPTIONS;

    // ----------------------------------------------------------------
    // Lifecycle
    // ----------------------------------------------------------------

    connectedCallback() {
        this.loadConfig();
        this.loadSchedulerStatus();
    }

    // ----------------------------------------------------------------
    // Data loading
    // ----------------------------------------------------------------

    async loadConfig() {
        try {
            this.isLoading = true;
            const data = await getPortalConfig();
            if (data) {
                this.config = {
                    ...this.config,
                    ...data,
                    useOkta: !!data.oktaDomain,
                };
            }
        } catch (e) {
            // 初回セットアップ時は設定レコードが存在しないことがある（正常）
        } finally {
            this.isLoading = false;
        }
    }

    async loadSchedulerStatus() {
        try {
            const status = await getSchedulerStatus();
            this.schedulerEnabled = status && status.isScheduled && status.state === 'WAITING';
        } catch (e) {
            this.schedulerEnabled = false;
        }
    }

    // ----------------------------------------------------------------
    // Step navigation
    // ----------------------------------------------------------------

    get currentStep() {
        return STEPS[this.currentStepIndex];
    }

    get isFirstStep() {
        return this.currentStepIndex === 0;
    }

    get nextButtonLabel() {
        switch (this.currentStep) {
            case 'fees': return '次へ（設定を保存）';
            default:     return '次へ';
        }
    }

    get schedulerButtonLabel() {
        return this.schedulerEnabled ? '有効化済み' : 'スケジューラーを有効化';
    }

    // Step visibility getters
    get isStepWelcome()  { return this.currentStep === 'welcome';  }
    get isStepBasic()    { return this.currentStep === 'basic';    }
    get isStepPayment()  { return this.currentStep === 'payment';  }
    get isStepFees()     { return this.currentStep === 'fees';     }
    get isStepAuth()     { return this.currentStep === 'auth';     }
    get isStepComplete() { return this.currentStep === 'complete'; }

    // Payment provider display getters
    get isGmoSelected()         { return this.config.defaultPaymentProvider === 'GMOあおぞら'; }
    get isPayjpSelected()       { return this.config.defaultPaymentProvider === 'Pay.jp';     }
    get isOmiseSelected()       { return this.config.defaultPaymentProvider === 'Omise';      }
    get isStripeSelected()      { return this.config.defaultPaymentProvider === 'Stripe';     }
    get isFincodeSelected()     { return this.config.defaultPaymentProvider === 'Fincode';    }
    get isDirectDebitSelected() { return this.config.defaultPaymentProvider === '口座振替';   }

    // ----------------------------------------------------------------
    // Event handlers: input changes
    // ----------------------------------------------------------------

    handleChange(event) {
        const key   = event.target.dataset.key;
        const value = event.target.value;
        this.config         = { ...this.config, [key]: value };
        this.pendingChanges[key] = value;
        this.clearMessages();
    }

    handleCheckChange(event) {
        const key     = event.target.dataset.key;
        const checked = event.target.checked;
        this.config         = { ...this.config, [key]: checked };
        this.pendingChanges[key] = checked;
        this.clearMessages();
    }

    handleProviderChange(event) {
        const value = event.detail.value;
        this.config         = { ...this.config, defaultPaymentProvider: value };
        this.pendingChanges.defaultPaymentProvider = value;
        this.clearMessages();
    }

    handleUseOktaChange(event) {
        // useOkta は UI 専用フラグ（保存対象外）
        this.config = { ...this.config, useOkta: event.target.checked };
        this.clearMessages();
    }

    // ----------------------------------------------------------------
    // Event handlers: navigation
    // ----------------------------------------------------------------

    async handleNext() {
        this.clearMessages();
        if (!this.validateCurrentStep()) return;

        // フォームデータを持つステップで保存
        const savingSteps = ['basic', 'payment', 'fees', 'auth'];
        if (savingSteps.includes(this.currentStep)) {
            await this.saveCurrentStep();
            if (this.errorMessage) return;
        }

        this.currentStepIndex++;
    }

    handlePrevious() {
        if (this.currentStepIndex > 0) {
            this.clearMessages();
            this.currentStepIndex--;
        }
    }

    handleSkipStep() {
        this.clearMessages();
        this.pendingChanges = {};
        this.currentStepIndex++;
    }

    // ----------------------------------------------------------------
    // Event handlers: completion actions
    // ----------------------------------------------------------------

    async handleEnableScheduler() {
        try {
            this.isLoading = true;
            await enableScheduler();
            this.schedulerEnabled = true;
            this.successMessage   = '定期支払いスケジューラーを有効化しました（毎日 01:00 実行）。';
        } catch (e) {
            this.errorMessage = 'スケジューラーの有効化に失敗しました: ' + this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenPortalConfig() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__portalConfigAdmin' },
        });
    }

    // ----------------------------------------------------------------
    // Private: save
    // ----------------------------------------------------------------

    async saveCurrentStep() {
        // useOkta は UI 専用フラグなので除外する
        // eslint-disable-next-line no-unused-vars
        const { useOkta, ...settingsToSave } = this.pendingChanges;

        if (Object.keys(settingsToSave).length === 0) return;

        try {
            this.isLoading = true;
            await savePortalConfig({ settings: settingsToSave });
            this.pendingChanges   = {};
            this.successMessage   = '設定を保存しました。';
        } catch (e) {
            this.errorMessage = '設定の保存中にエラーが発生しました: ' + this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ----------------------------------------------------------------
    // Private: validation
    // ----------------------------------------------------------------

    validateCurrentStep() {
        const inputs = [
            ...this.template.querySelectorAll('lightning-input'),
            ...this.template.querySelectorAll('lightning-combobox'),
        ];
        return inputs.reduce((valid, el) => {
            return el.reportValidity ? el.reportValidity() && valid : valid;
        }, true);
    }

    // ----------------------------------------------------------------
    // Private: helpers
    // ----------------------------------------------------------------

    clearMessages() {
        this.errorMessage   = '';
        this.successMessage = '';
    }

    extractMessage(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message)                    return error.message;
        return '不明なエラーが発生しました';
    }
}
