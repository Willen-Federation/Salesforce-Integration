import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitInquiry from '@salesforce/apex/SupportInquiryController.submitInquiry';
import getInquiriesByMember from '@salesforce/apex/SupportInquiryController.getInquiriesByMember';

const CATEGORY_OPTIONS = [
    { label: '会員登録・手続き',   value: '会員登録・手続き' },
    { label: '支払い・請求',       value: '支払い・請求' },
    { label: 'システム・ログイン', value: 'システム・ログイン' },
    { label: '活動・イベント',     value: '活動・イベント' },
    { label: '個人情報変更',       value: '個人情報変更' },
    { label: 'その他',             value: 'その他' },
];
const COLUMNS = [
    { label: '番号',       fieldName: 'Name' },
    { label: 'カテゴリ',  fieldName: 'Category__c' },
    { label: '件名',       fieldName: 'Subject__c' },
    { label: '受付日',     fieldName: 'CreatedDate', type: 'date' },
    { label: 'ステータス', fieldName: 'InquiryStatus__c' },
    { label: '回答日',     fieldName: 'ResponseDate__c', type: 'date' },
    { label: '操作', type: 'button', typeAttributes: { label: '詳細', name: 'view', variant: 'neutral' } },
];

export default class SupportInquiryForm extends LightningElement {
    @api memberId;
    @api defaultName  = '';
    @api defaultEmail = '';

    @track contactName  = '';
    @track contactEmail = '';
    @track category     = 'その他';
    @track subject      = '';
    @track body         = '';
    @track inquiries    = [];
    @track isSubmitting = false;
    @track isSubmitted  = false;
    @track hasError     = false;
    @track errorMessage = '';
    @track submittedName = '';

    categoryOptions = CATEGORY_OPTIONS;
    columns         = COLUMNS;

    connectedCallback() {
        this.contactName  = this.defaultName;
        this.contactEmail = this.defaultEmail;
        if (this.memberId) this.loadInquiries();
    }

    handleName(e)     { this.contactName  = e.target.value; }
    handleEmail(e)    { this.contactEmail = e.target.value; }
    handleCategory(e) { this.category     = e.detail.value; }
    handleSubject(e)  { this.subject      = e.target.value; }
    handleBody(e)     { this.body         = e.target.value; }

    get hasHistory() { return this.inquiries.length > 0; }

    async loadInquiries() {
        try {
            this.inquiries = await getInquiriesByMember({ memberId: this.memberId });
        } catch (e) { console.error(e); }
    }

    async handleSubmit() {
        this.hasError = false;
        if (!this.contactName || !this.contactEmail || !this.subject || !this.body) {
            this.hasError = true; this.errorMessage = 'すべての必須項目を入力してください。'; return;
        }
        if (!this.contactEmail.includes('@')) {
            this.hasError = true; this.errorMessage = '有効なメールアドレスを入力してください。'; return;
        }
        this.isSubmitting = true;
        try {
            const inquiryData = {
                contactName:  this.contactName,
                contactEmail: this.contactEmail,
                category:     this.category,
                subject:      this.subject,
                body:         this.body,
                memberId:     this.memberId ?? null,
            };
            await submitInquiry({ inquiryData });
            this.isSubmitted = true;
            this.dispatchEvent(new ShowToastEvent({ title: '送信完了', message: 'お問い合わせを受け付けました。', variant: 'success' }));
            if (this.memberId) await this.loadInquiries();
        } catch (e) {
            this.hasError = true;
            this.errorMessage = e?.body?.message ?? 'エラーが発生しました。';
        } finally {
            this.isSubmitting = false;
        }
    }

    handleViewDetail(event) {
        const row = event.detail.row;
        this.dispatchEvent(new CustomEvent('viewinquiry', { detail: { inquiryId: row.Id } }));
    }
}
