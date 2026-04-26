import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitDonation from '@salesforce/apex/DonationController.submitDonation';

const PURPOSE_OPTIONS = [
    { label: '一般活動費', value: '一般活動費' },
    { label: '研究助成',   value: '研究助成' },
    { label: '教育支援',   value: '教育支援' },
    { label: '施設整備',   value: '施設整備' },
    { label: 'その他指定寄付', value: 'その他指定寄付' },
];
const PAYMENT_OPTIONS = [
    { label: 'クレジットカード', value: 'クレジットカード' },
    { label: '銀行振込',        value: '銀行振込' },
    { label: '口座振替',        value: '口座振替' },
];
const PRESETS = [
    { label: '¥1,000',  value: 1000  },
    { label: '¥3,000',  value: 3000  },
    { label: '¥5,000',  value: 5000  },
    { label: '¥10,000', value: 10000 },
    { label: '¥30,000', value: 30000 },
];

export default class DonationForm extends LightningElement {
    @api memberId;
    @track amount        = 1000;
    @track purpose       = '一般活動費';
    @track paymentMethod = 'クレジットカード';
    @track isAnonymous   = false;
    @track donorName     = '';
    @track donorEmail    = '';
    @track taxCertRequired = false;
    @track message       = '';
    @track isSubmitting  = false;
    @track isSubmitted   = false;
    @track hasError      = false;
    @track errorMessage  = '';
    @track submittedDonationName = '';

    purposeOptions      = PURPOSE_OPTIONS;
    paymentMethodOptions = PAYMENT_OPTIONS;
    presetAmounts       = PRESETS;

    handleAmountChange(e)     { this.amount        = e.target.value; }
    handlePreset(e)           { this.amount        = Number(e.target.dataset.amount); }
    handlePurposeChange(e)    { this.purpose       = e.detail.value; }
    handleMethodChange(e)     { this.paymentMethod = e.detail.value; }
    handleAnonymousChange(e)  { this.isAnonymous   = e.target.checked; }
    handleDonorNameChange(e)  { this.donorName     = e.target.value; }
    handleDonorEmailChange(e) { this.donorEmail    = e.target.value; }
    handleTaxCertChange(e)    { this.taxCertRequired = e.target.checked; }
    handleMessageChange(e)    { this.message       = e.target.value; }

    async handleSubmit() {
        this.hasError = false;
        if (!this.amount || this.amount < 1000) {
            this.showError('寄付金額は1,000円以上で入力してください。'); return;
        }
        if (!this.isAnonymous && !this.donorEmail) {
            this.showError('メールアドレスを入力してください。'); return;
        }
        this.isSubmitting = true;
        try {
            const donationData = {
                amount:               this.amount,
                purpose:              this.purpose,
                paymentMethod:        this.paymentMethod,
                isAnonymous:          this.isAnonymous,
                donorName:            this.donorName,
                donorEmail:           this.donorEmail,
                taxDeductionCertRequired: this.taxCertRequired,
                message:              this.message,
                memberId:             this.memberId ?? null,
            };
            await submitDonation({ donationData });
            this.isSubmitted = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'ありがとうございます', message: 'ご寄付を受け付けました。', variant: 'success'
            }));
        } catch (e) {
            this.showError(e?.body?.message ?? '申請中にエラーが発生しました。');
        } finally {
            this.isSubmitting = false;
        }
    }

    showError(msg) { this.hasError = true; this.errorMessage = msg; }
}
