import { LightningElement, track } from 'lwc';
import getPlaceholderHelp    from '@salesforce/apex/IndividualNotificationService.getPlaceholderHelp';
import createAndSend         from '@salesforce/apex/IndividualNotificationService.createAndSend';
import saveDraft             from '@salesforce/apex/IndividualNotificationService.saveDraft';
import scheduleNotification  from '@salesforce/apex/IndividualNotificationService.scheduleNotification';
import sendTestEmail         from '@salesforce/apex/IndividualNotificationService.sendTestEmail';
import getRecentNotifications from '@salesforce/apex/IndividualNotificationService.getRecentNotifications';
import getOrgUnits           from '@salesforce/apex/OrgChartController.getOrgUnits';

export default class IndividualNotificationComposer extends LightningElement {
    @track recipientType       = '全会員';
    @track recipientMemberIds  = '';
    @track recipientOrgUnit    = '';
    @track recipientMemberType = '';
    @track selectedChannels    = ['個人登録メール'];
    @track subject             = '';
    @track bodyTemplate        = '';
    @track relatedObjectType   = 'Member';
    @track relatedRecordId     = '';
    @track sendMode            = '今すぐ送信';
    @track scheduledSendTime   = '';
    @track selectedPlaceholder = '';
    @track placeholderOptions  = [];
    @track orgUnitOptions      = [];
    @track recentNotifications = [];
    @track isBusy              = false;
    @track errorMessage        = '';
    @track successMessage      = '';
    @track memberCount         = 0;
    @track showTestPanel       = false;
    @track testEmailAddress    = '';
    @track isTestSending       = false;
    @track testSentSuccess     = false;
    @track mergedPreview       = '';

    recipientTypeOptions = [
        { label: '全会員',     value: '全会員' },
        { label: '組織単位',   value: '組織単位' },
        { label: '会員種別',   value: '会員種別' },
        { label: '特定会員',   value: '特定会員' }
    ];

    channelOptions = [
        { label: '個人登録メール', value: '個人登録メール' },
        { label: 'Willenメール',   value: 'Willenメール' },
        { label: 'Slack',          value: 'Slack' },
        { label: 'ポータル通知',   value: 'ポータル通知' }
    ];

    memberTypeOptions = [
        { label: '正会員',   value: '正会員' },
        { label: '準会員',   value: '準会員' },
        { label: '賛助会員', value: '賛助会員' }
    ];

    objectTypeOptions = [
        { label: '会員',   value: 'Member' },
        { label: '支払い', value: 'Payment' },
        { label: '総会',   value: 'Meeting' },
        { label: '活動',   value: 'Activity' }
    ];

    sendModeOptions = [
        { label: '今すぐ送信', value: '今すぐ送信' },
        { label: '予約送信',   value: '予約送信' }
    ];

    historyColumns = [
        { label: '件名',         fieldName: 'Subject__c' },
        { label: '受信者タイプ', fieldName: 'RecipientType__c' },
        { label: 'チャンネル',   fieldName: 'DeliveryChannels__c' },
        { label: 'ステータス',   fieldName: 'NotificationStatus__c' },
        { label: '送信数',       fieldName: 'SentCount__c', type: 'number' },
        { label: '送信日時',     fieldName: 'SentAt__c', type: 'date',
          typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' } }
    ];

    connectedCallback() {
        this.loadOrgUnits();
        this.loadPlaceholders('Member');
        this.loadRecentNotifications();
    }

    loadOrgUnits() {
        getOrgUnits()
            .then(data => {
                this.orgUnitOptions = data.map(u => ({ label: u.Name, value: u.Id }));
            })
            .catch(() => {});
    }

    loadPlaceholders(objectType) {
        getPlaceholderHelp({ objectType })
            .then(data => {
                this.placeholderOptions = data.map(p => ({ label: p.label + ' → ' + p.placeholder, value: p.placeholder }));
                this.selectedPlaceholder = this.placeholderOptions.length ? this.placeholderOptions[0].value : '';
            })
            .catch(() => { this.placeholderOptions = []; });
    }

    loadRecentNotifications() {
        getRecentNotifications({ limitCount: 10 })
            .then(data => { this.recentNotifications = data; })
            .catch(() => {});
    }

    get showMemberSearch()    { return this.recipientType === '特定会員'; }
    get showOrgUnitPicker()   { return this.recipientType === '組織単位'; }
    get showMemberTypePicker(){ return this.recipientType === '会員種別'; }
    get isAllMembers()        { return this.recipientType === '全会員'; }
    get showRelatedRecordId() { return this.relatedObjectType !== 'Member'; }
    get showScheduleTime()    { return this.sendMode === '予約送信'; }
    get isScheduleMode()      { return this.sendMode === '予約送信'; }
    get noPlaceholders()      { return !this.placeholderOptions.length; }
    get showPaymentPlaceholders() { return this.relatedObjectType === 'Payment'; }
    get showMeetingPlaceholders() { return this.relatedObjectType === 'Meeting'; }

    handleRecipientTypeChange(event) {
        this.recipientType = event.detail.value;
    }

    handleChannelChange(event) {
        this.selectedChannels = event.detail.value;
    }

    handleObjectTypeChange(event) {
        this.relatedObjectType = event.detail.value;
        this.relatedRecordId   = '';
        this.loadPlaceholders(this.relatedObjectType);
    }

    handlePlaceholderSelect(event) {
        this.selectedPlaceholder = event.detail.value;
    }

    handleInsertPlaceholder() {
        if (!this.selectedPlaceholder) return;
        const textarea = this.template.querySelector('lightning-textarea');
        const current  = this.bodyTemplate || '';
        this.bodyTemplate = current + this.selectedPlaceholder;
    }

    handleBodyChange(event) {
        this.bodyTemplate = event.target.value;
    }

    handleSendModeChange(event) {
        this.sendMode = event.detail.value;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    _buildPayload() {
        return {
            subject:             this.subject,
            bodyTemplate:        this.bodyTemplate,
            deliveryChannels:    this.selectedChannels.join(';'),
            recipientType:       this.recipientType,
            recipientMember:     this.recipientMemberIds,
            recipientOrgUnit:    this.recipientOrgUnit,
            recipientMemberType: this.recipientMemberType,
            relatedObjectType:   this.relatedObjectType,
            relatedRecordId:     this.relatedRecordId
        };
    }

    _validate() {
        if (!this.subject)              { this.errorMessage = '件名を入力してください。'; return false; }
        if (!this.bodyTemplate)         { this.errorMessage = '本文を入力してください。'; return false; }
        if (!this.selectedChannels.length) { this.errorMessage = '配信チャンネルを1つ以上選択してください。'; return false; }
        return true;
    }

    handleSendNow() {
        if (!this._validate()) return;
        this.isBusy = true;
        this.errorMessage = '';
        createAndSend({ notifData: this._buildPayload() })
            .then(() => {
                this.successMessage = '通知を送信しました。';
                this._reset();
                this.loadRecentNotifications();
            })
            .catch(err => { this.errorMessage = err.body?.message || '送信に失敗しました。'; })
            .finally(() => { this.isBusy = false; });
    }

    handleSaveDraft() {
        if (!this.subject) { this.errorMessage = '件名を入力してください。'; return; }
        this.isBusy = true;
        this.errorMessage = '';
        saveDraft({ notifData: this._buildPayload() })
            .then(() => {
                this.successMessage = '下書きを保存しました。';
                this.loadRecentNotifications();
            })
            .catch(err => { this.errorMessage = err.body?.message || '保存に失敗しました。'; })
            .finally(() => { this.isBusy = false; });
    }

    handleScheduleSend() {
        if (!this._validate()) return;
        if (!this.scheduledSendTime) { this.errorMessage = '予約送信日時を入力してください。'; return; }
        this.isBusy = true;
        this.errorMessage = '';
        saveDraft({ notifData: this._buildPayload() })
            .then(id => scheduleNotification({ notifId: id, scheduledTime: this.scheduledSendTime }))
            .then(() => {
                this.successMessage = '予約送信を設定しました。';
                this._reset();
                this.loadRecentNotifications();
            })
            .catch(err => { this.errorMessage = err.body?.message || '予約設定に失敗しました。'; })
            .finally(() => { this.isBusy = false; });
    }

    handleToggleTestPanel() {
        this.showTestPanel    = !this.showTestPanel;
        this.testSentSuccess  = false;
        this.mergedPreview    = '';
    }

    handleSendTestEmail() {
        if (!this.bodyTemplate) { this.errorMessage = '先に本文を入力してください。'; return; }
        this.isTestSending   = true;
        this.testSentSuccess = false;
        this.mergedPreview   = '';
        this.errorMessage    = '';
        sendTestEmail({
            subject:           this.subject,
            bodyTemplate:      this.bodyTemplate,
            relatedObjectType: this.relatedObjectType,
            relatedRecordId:   this.relatedRecordId,
            testEmail:         this.testEmailAddress
        })
            .then(mergedBody => {
                this.mergedPreview   = mergedBody;
                this.testSentSuccess = true;
            })
            .catch(err => { this.errorMessage = err.body?.message || 'テスト送信に失敗しました。'; })
            .finally(() => { this.isTestSending = false; });
    }

    _reset() {
        this.subject           = '';
        this.bodyTemplate      = '';
        this.scheduledSendTime = '';
        this.recipientMemberIds = '';
        this.mergedPreview     = '';
        this.testSentSuccess   = false;
    }
}
