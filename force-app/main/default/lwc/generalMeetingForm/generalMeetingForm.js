import { LightningElement, api, track } from 'lwc';
import getUpcomingMeetings  from '@salesforce/apex/GeneralMeetingController.getUpcomingMeetings';
import getMeetingDetail     from '@salesforce/apex/GeneralMeetingController.getMeetingDetail';
import getMemberResponse    from '@salesforce/apex/GeneralMeetingController.getMemberResponse';
import submitAttendanceResponse from '@salesforce/apex/GeneralMeetingController.submitAttendanceResponse';
import createMeeting        from '@salesforce/apex/GeneralMeetingController.createMeeting';
import updateMeetingStatus  from '@salesforce/apex/GeneralMeetingController.updateMeetingStatus';
import sendReminders        from '@salesforce/apex/GeneralMeetingController.sendReminders';
import getResponsesForMeeting from '@salesforce/apex/GeneralMeetingController.getResponsesForMeeting';

export default class GeneralMeetingForm extends LightningElement {
    @api memberId;
    @api isAdmin = false;

    @track meetings = [];
    @track selectedMeeting = null;
    @track responses = [];
    @track isLoading = false;
    @track showCreateModal = false;

    meetingState = {};

    currentYear = new Date().getFullYear();

    attendanceOptions = [
        { label: '出席', value: '出席' },
        { label: '欠席（委任状あり）', value: '欠席（委任状あり）' },
        { label: '欠席（権利行使書提出）', value: '欠席（権利行使書提出）' },
        { label: '欠席', value: '欠席' }
    ];

    votingOptions = [
        { label: '賛成', value: '賛成' },
        { label: '反対', value: '反対' },
        { label: '棄権', value: '棄権' }
    ];

    responseColumns = [
        { label: '会員名', fieldName: 'RespondentName__c' },
        { label: '出欠', fieldName: 'AttendanceChoice__c' },
        { label: '委任先', fieldName: 'ProxyName__c' },
        { label: 'ステータス', fieldName: 'ResponseStatus__c' },
        { label: '回答日時', fieldName: 'SubmittedAt__c', type: 'date',
          typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' } }
    ];

    connectedCallback() {
        this.loadMeetings();
    }

    loadMeetings() {
        this.isLoading = true;
        getUpcomingMeetings()
            .then(data => {
                const now = new Date();
                this.meetings = data.map(m => ({
                    ...m,
                    formattedDate:     m.MeetingDate__c ? new Date(m.MeetingDate__c).toLocaleString('ja-JP') : '—',
                    formattedDeadline: m.ResponseDeadline__c ? new Date(m.ResponseDeadline__c).toLocaleString('ja-JP') : '—',
                    isOpen:            m.MeetingStatus__c === '出欠受付中' && (!m.ResponseDeadline__c || new Date(m.ResponseDeadline__c) > now),
                    attendanceChoice:  '',
                    proxyName:         '',
                    showProxy:         false,
                    showVoting:        false,
                    isSubmitting:      false,
                    existingResponse:  null,
                    agendaItems:       this.parseAgendaItems(m.Agenda__c)
                }));

                if (!this.isAdmin && this.memberId) {
                    this.loadExistingResponses();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(() => { this.isLoading = false; });
    }

    loadExistingResponses() {
        const promises = this.meetings.map(m =>
            getMemberResponse({ meetingId: m.Id, memberId: this.memberId })
                .then(resp => ({ meetingId: m.Id, response: resp }))
                .catch(() => ({ meetingId: m.Id, response: null }))
        );
        Promise.all(promises).then(results => {
            results.forEach(r => {
                const idx = this.meetings.findIndex(m => m.Id === r.meetingId);
                if (idx >= 0 && r.response) {
                    this.meetings[idx] = { ...this.meetings[idx], existingResponse: r.response };
                }
            });
            this.isLoading = false;
        });
    }

    parseAgendaItems(agenda) {
        if (!agenda) return [];
        return agenda.split('\n')
            .filter(line => line.trim().startsWith('第'))
            .map((line, i) => ({ key: 'agenda_' + i, label: line.trim(), value: '賛成' }));
    }

    handleAttendanceChange(event) {
        const id    = event.currentTarget.dataset.id;
        const value = event.detail.value;
        const idx   = this.meetings.findIndex(m => m.Id === id);
        if (idx < 0) return;
        this.meetings[idx] = {
            ...this.meetings[idx],
            attendanceChoice: value,
            showProxy:  value === '欠席（委任状あり）',
            showVoting: value === '欠席（権利行使書提出）'
        };
    }

    handleProxyNameChange(event) {
        const id  = event.currentTarget.dataset.id;
        const idx = this.meetings.findIndex(m => m.Id === id);
        if (idx >= 0) this.meetings[idx] = { ...this.meetings[idx], proxyName: event.target.value };
    }

    handleVotingChange(event) {
        const mId = event.currentTarget.dataset.meeting;
        const key = event.currentTarget.dataset.key;
        const idx = this.meetings.findIndex(m => m.Id === mId);
        if (idx < 0) return;
        const items = this.meetings[idx].agendaItems.map(item =>
            item.key === key ? { ...item, value: event.detail.value } : item
        );
        this.meetings[idx] = { ...this.meetings[idx], agendaItems: items };
    }

    handleSubmit(event) {
        const id  = event.currentTarget.dataset.id;
        const idx = this.meetings.findIndex(m => m.Id === id);
        if (idx < 0) return;

        const m = this.meetings[idx];
        if (!m.attendanceChoice) { alert('出欠区分を選択してください。'); return; }

        const votingJson = JSON.stringify(
            m.agendaItems.reduce((acc, item) => { acc[item.key] = item.value; return acc; }, {})
        );
        this.meetings[idx] = { ...this.meetings[idx], isSubmitting: true };

        submitAttendanceResponse({
            meetingId:        id,
            memberId:         this.memberId,
            attendanceChoice: m.attendanceChoice,
            proxyName:        m.proxyName,
            votingChoicesJson: votingJson,
            fieldAnswersJson: '{}'
        })
            .then(() => {
                this.meetings[idx] = { ...this.meetings[idx], isSubmitting: false };
                this.loadMeetings();
            })
            .catch(err => {
                alert(err.body?.message || '送信に失敗しました。');
                this.meetings[idx] = { ...this.meetings[idx], isSubmitting: false };
            });
    }

    handleSelectMeeting(event) {
        const id = event.currentTarget.dataset.id;
        this.isLoading = true;
        Promise.all([
            getMeetingDetail({ meetingId: id }),
            getResponsesForMeeting({ meetingId: id })
        ]).then(([meeting, responses]) => {
            this.selectedMeeting = {
                ...meeting,
                formattedDate:     meeting.MeetingDate__c ? new Date(meeting.MeetingDate__c).toLocaleString('ja-JP') : '—',
                formattedDeadline: meeting.ResponseDeadline__c ? new Date(meeting.ResponseDeadline__c).toLocaleString('ja-JP') : '—'
            };
            this.responses  = responses;
            this.isLoading  = false;
        }).catch(() => { this.isLoading = false; });
    }

    handleBack() { this.selectedMeeting = null; this.loadMeetings(); }

    handleUpdateStatus(event) {
        const status = event.currentTarget.dataset.status;
        updateMeetingStatus({ meetingId: this.selectedMeeting.Id, status })
            .then(() => { this.handleSelectMeeting({ currentTarget: { dataset: { id: this.selectedMeeting.Id } } }); });
    }

    handleSendReminder(event) {
        const id = event.currentTarget.dataset.id;
        if (!confirm('未回答の会員全員に催促メールを送信しますか？')) return;
        sendReminders({ meetingId: id }).then(() => alert('催促メールを送信しました。'));
    }

    handleSendReminderForSelected() {
        if (!confirm('未回答の会員全員に催促メールを送信しますか？')) return;
        sendReminders({ meetingId: this.selectedMeeting.Id }).then(() => alert('催促メールを送信しました。'));
    }

    handleCreateMeeting() { this.showCreateModal = true; }
    handleCloseModal()    { this.showCreateModal = false; }

    handleSubmitCreate() {
        const fields = this.template.querySelectorAll('[data-field]');
        const data = {};
        fields.forEach(f => { data[f.dataset.field] = f.value; });
        if (!data.name || !data.fiscalYear || !data.meetingDate) {
            alert('必須項目を入力してください。'); return;
        }
        createMeeting({ meetingData: data })
            .then(() => { this.showCreateModal = false; this.loadMeetings(); });
    }
}
