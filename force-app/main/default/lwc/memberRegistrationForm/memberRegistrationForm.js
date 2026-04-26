import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import registerMember from '@salesforce/apex/MemberRegistrationController.registerMember';

const MEMBER_TYPE_OPTIONS = [
    { label: '個人会員', value: '個人会員' },
    { label: '法人会員', value: '法人会員' },
    { label: '学生会員', value: '学生会員' },
];

export default class MemberRegistrationForm extends LightningElement {
    @track currentStep = 1;
    @track isSubmitted = false;
    @track isSubmitting = false;
    @track hasError = false;
    @track errorMessage = '';
    @track agreedToTerms = false;

    @track formData = {
        lastName: '', firstName: '', email: '', phone: '',
        memberType: '個人会員', organization: '', department: '', position: ''
    };

    get memberTypeOptions() { return MEMBER_TYPE_OPTIONS; }
    get progressValue() { return (this.currentStep / 3) * 100; }
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.formData = { ...this.formData, [field]: event.target.value };
    }

    handleTermsChange(event) {
        this.agreedToTerms = event.target.checked;
    }

    handleNext() {
        if (!this.validateCurrentStep()) return;
        this.currentStep++;
    }

    handleBack() {
        if (this.currentStep > 1) this.currentStep--;
        this.hasError = false;
    }

    validateCurrentStep() {
        this.hasError = false;
        if (this.currentStep === 1) {
            if (!this.formData.lastName || !this.formData.firstName) {
                this.showError('氏名は必須です。');
                return false;
            }
            if (!this.formData.email || !this.formData.email.includes('@')) {
                this.showError('有効なメールアドレスを入力してください。');
                return false;
            }
            if (!this.formData.memberType) {
                this.showError('会員種別を選択してください。');
                return false;
            }
        }
        return true;
    }

    async handleSubmit() {
        if (!this.agreedToTerms) {
            this.showError('個人情報の取り扱いへの同意が必要です。');
            return;
        }
        this.isSubmitting = true;
        this.hasError = false;
        try {
            await registerMember({ memberData: this.formData });
            this.isSubmitted = true;
            this.dispatchEvent(new ShowToastEvent({
                title: '申請完了', message: '会員登録申請を受け付けました。', variant: 'success'
            }));
        } catch (e) {
            this.showError(e?.body?.message ?? '申請中にエラーが発生しました。しばらくしてから再度お試しください。');
        } finally {
            this.isSubmitting = false;
        }
    }

    showError(msg) {
        this.hasError = true;
        this.errorMessage = msg;
    }
}
