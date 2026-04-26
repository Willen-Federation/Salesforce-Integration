import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createChangeRequest from '@salesforce/apex/ChangeRequestController.createChangeRequest';
import getChangeRequestsByMember from '@salesforce/apex/WorkflowApprovalService.getChangeRequestsByMember';

const TYPE_OPTIONS = [
    { label: '会員情報変更',          value: '会員情報変更' },
    { label: '退会申請',              value: '退会申請' },
    { label: '休会申請',              value: '休会申請' },
    { label: '会員種別変更',          value: '会員種別変更' },
    { label: '組織変更',              value: '組織変更' },
    { label: 'メールアドレス変更',    value: 'メールアドレス変更' },
    { label: 'パスワードリセット申請', value: 'パスワードリセット申請' },
    { label: 'その他',                value: 'その他' },
];
const PRIORITY_OPTIONS = [
    { label: '高', value: '高' },
    { label: '中', value: '中' },
    { label: '低', value: '低' },
];
const COLUMNS = [
    { label: '申請番号',   fieldName: 'Name' },
    { label: '申請種別',   fieldName: 'RequestType__c' },
    { label: '優先度',     fieldName: 'Priority__c' },
    { label: '申請日',     fieldName: 'RequestDate__c', type: 'date' },
    { label: 'ステータス', fieldName: 'ApprovalStatus__c' },
    { label: '承認日',     fieldName: 'ApprovalDate__c', type: 'date' },
];

export default class ChangeRequestForm extends LightningElement {
    @api memberId;
    @track requestType         = 'その他';
    @track priority            = '中';
    @track description         = '';
    @track implementationDate  = '';
    @track requests            = [];
    @track isSubmitting        = false;
    @track isSubmitted         = false;
    @track hasError            = false;
    @track errorMessage        = '';
    @track submittedName       = '';

    typeOptions     = TYPE_OPTIONS;
    priorityOptions = PRIORITY_OPTIONS;
    columns         = COLUMNS;

    connectedCallback() { this.loadRequests(); }

    handleTypeChange(e)     { this.requestType        = e.detail.value; }
    handlePriorityChange(e) { this.priority           = e.detail.value; }
    handleDateChange(e)     { this.implementationDate = e.target.value; }
    handleDescChange(e)     { this.description        = e.target.value; }

    async loadRequests() {
        try {
            this.requests = await getChangeRequestsByMember({ memberId: this.memberId });
        } catch (e) { console.error(e); }
    }

    async handleSubmit() {
        this.hasError = false;
        if (!this.description?.trim()) {
            this.hasError = true; this.errorMessage = '申請内容を入力してください。'; return;
        }
        this.isSubmitting = true;
        try {
            this.submittedName = await createChangeRequest({
                memberId:           this.memberId,
                requestType:        this.requestType,
                priority:           this.priority,
                description:        this.description,
                implementationDate: this.implementationDate || null,
            });
            this.isSubmitted = true;
            this.dispatchEvent(new ShowToastEvent({ title: '申請完了', message: '変更申請を受け付けました。', variant: 'success' }));
            await this.loadRequests();
        } catch (e) {
            this.hasError = true;
            this.errorMessage = e?.body?.message ?? 'エラーが発生しました。';
        } finally {
            this.isSubmitting = false;
        }
    }
}
