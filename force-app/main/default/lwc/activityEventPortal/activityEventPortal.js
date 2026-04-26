import { LightningElement, api, track } from 'lwc';
import getPublicEvents from '@salesforce/apex/ActivityController.getPublicEvents';
import getUpcomingEvents from '@salesforce/apex/ActivityController.getUpcomingEvents';
import registerForEvent from '@salesforce/apex/ActivityController.registerForEvent';
import createEvent from '@salesforce/apex/ActivityController.createEvent';

export default class ActivityEventPortal extends LightningElement {
    @api memberId;
    @api isAdmin = false;
    @api showInternalEvents = false;

    @track events = [];
    @track selectedEvent = null;
    @track isLoading = false;
    @track showCreateModal = false;
    @track registrationDone = false;
    @track isSubmitting = false;
    @track errorMessage = '';

    regName = '';
    regEmail = '';
    regOrg = '';
    regRemarks = '';

    connectedCallback() {
        this.loadEvents();
    }

    loadEvents() {
        this.isLoading = true;
        const fetchFn = this.showInternalEvents ? getUpcomingEvents : getPublicEvents;
        fetchFn()
            .then(data => {
                this.events = data.map(e => ({
                    ...e,
                    formattedStartDate: e.EventStartDatetime__c
                        ? new Date(e.EventStartDatetime__c).toLocaleString('ja-JP')
                        : e.ActivityDate__c,
                    feeDisplay: e.RegistrationFee__c ? `¥${e.RegistrationFee__c.toLocaleString()}` : '無料'
                }));
                this.isLoading = false;
            })
            .catch(() => {
                this.isLoading = false;
            });
    }

    handleViewEvent(event) {
        const id = event.currentTarget.dataset.id;
        const found = this.events.find(e => e.Id === id);
        if (found) {
            this.selectedEvent = {
                ...found,
                formattedEndDate: found.EventEndDatetime__c
                    ? new Date(found.EventEndDatetime__c).toLocaleString('ja-JP') : '—'
            };
            this.registrationDone = false;
            this.errorMessage = '';
        }
    }

    handleBack() {
        this.selectedEvent = null;
        this.registrationDone = false;
        this.errorMessage = '';
    }

    handleRegChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleRegister() {
        if (!this.regName || !this.regEmail) {
            this.errorMessage = 'お名前とメールアドレスは必須です。';
            return;
        }
        this.isSubmitting = true;
        this.errorMessage = '';

        registerForEvent({
            registrationData: {
                activityId:           this.selectedEvent.Id,
                participantName:      this.regName,
                participantEmail:     this.regEmail,
                participantOrganization: this.regOrg,
                remarks:              this.regRemarks,
                memberId:             this.memberId || null
            }
        })
            .then(() => {
                this.registrationDone = true;
                this.isSubmitting = false;
                this.loadEvents();
            })
            .catch(error => {
                this.errorMessage = error.body?.message || '申込に失敗しました。';
                this.isSubmitting = false;
            });
    }

    handleCreateEvent() {
        this.showCreateModal = true;
    }

    handleCloseModal() {
        this.showCreateModal = false;
    }

    handleSubmitEvent() {
        const fields = this.template.querySelectorAll('[data-field]');
        const eventData = { activityType: 'その他', activityDate: new Date().toISOString().split('T')[0] };
        fields.forEach(f => {
            const key = f.dataset.field;
            eventData[key] = f.type === 'checkbox' ? f.checked : f.value;
        });
        if (this.memberId) eventData.memberId = this.memberId;

        createEvent({ eventData })
            .then(() => {
                this.showCreateModal = false;
                this.loadEvents();
            })
            .catch(error => {
                this.errorMessage = error.body?.message || 'イベントの作成に失敗しました。';
            });
    }
}
