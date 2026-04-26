import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createActivity from '@salesforce/apex/ActivityController.createActivity';
import getActivitiesByMember from '@salesforce/apex/ActivityController.getActivitiesByMember';

const TYPE_OPTIONS = [
    { label: '会議出席',    value: '会議出席' },
    { label: 'セミナー参加', value: 'セミナー参加' },
    { label: '委員会活動',  value: '委員会活動' },
    { label: 'ボランティア', value: 'ボランティア' },
    { label: '研究発表',   value: '研究発表' },
    { label: 'その他',     value: 'その他' },
];
const COLUMNS = [
    { label: '活動番号',   fieldName: 'Name' },
    { label: 'タイトル',   fieldName: 'ActivityTitle__c' },
    { label: '種別',       fieldName: 'ActivityType__c' },
    { label: '活動日',     fieldName: 'ActivityDate__c', type: 'date' },
    { label: '時間',       fieldName: 'Hours__c', type: 'number' },
    { label: 'ステータス', fieldName: 'ActivityStatus__c' },
];

export default class ActivityRegistration extends LightningElement {
    @api memberId;
    @track title        = '';
    @track activityType = 'その他';
    @track activityDate = '';
    @track location     = '';
    @track hours        = null;
    @track description  = '';
    @track activities   = [];
    @track isSubmitting = false;
    @track isSubmitted  = false;
    @track hasError     = false;
    @track errorMessage = '';
    @track submittedName = '';

    typeOptions = TYPE_OPTIONS;
    columns     = COLUMNS;

    connectedCallback() { this.loadActivities(); }

    handle(e)      { this[e.target.dataset.f] = e.target.value; }
    handleCombo(e) { this[e.target.dataset.f] = e.detail.value; }

    async loadActivities() {
        try {
            this.activities = await getActivitiesByMember({ memberId: this.memberId });
        } catch (e) { console.error(e); }
    }

    async handleSubmit() {
        this.hasError = false;
        if (!this.title || !this.activityDate) {
            this.hasError = true; this.errorMessage = 'タイトルと活動日は必須です。'; return;
        }
        this.isSubmitting = true;
        try {
            const activityData = {
                memberId:     this.memberId,
                title:        this.title,
                activityType: this.activityType,
                activityDate: this.activityDate,
                location:     this.location,
                hours:        this.hours ? Number(this.hours) : null,
                description:  this.description,
            };
            this.submittedName = await createActivity({ activityData });
            this.isSubmitted = true;
            this.dispatchEvent(new ShowToastEvent({ title: '登録完了', message: '活動を登録しました。', variant: 'success' }));
            await this.loadActivities();
        } catch (e) {
            this.hasError = true;
            this.errorMessage = e?.body?.message ?? 'エラーが発生しました。';
        } finally {
            this.isSubmitting = false;
        }
    }
}
