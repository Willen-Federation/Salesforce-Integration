import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMemberByEmail from '@salesforce/apex/MemberRegistrationController.getMemberByEmail';
import getPaymentsByMember from '@salesforce/apex/PaymentController.getPaymentsByMember';
import getChangeRequestsByMember from '@salesforce/apex/WorkflowApprovalService.getChangeRequestsByMember';
import getInquiriesByMember from '@salesforce/apex/SupportInquiryController.getInquiriesByMember';
import { CurrentPageReference } from 'lightning/navigation';

export default class MemberPortalDashboard extends NavigationMixin(LightningElement) {
    @api greeting = '会員ポータルへようこそ';

    @track member;
    @track isLoading = true;
    @track unpaidCount = 0;
    @track pendingRequestCount = 0;
    @track openInquiryCount = 0;
    @track notifications = [];

    get memberName() {
        return this.member ? `${this.member.LastName__c} ${this.member.FirstName__c}` : '';
    }
    get memberStatus() {
        return this.member?.MemberStatus__c ?? '';
    }
    get hasNotifications() {
        return this.notifications.length > 0;
    }

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        try {
            this.isLoading = true;
            // Experience Cloud では現在のユーザーメールで会員を特定
            const userEmail = this.getUserEmail();
            if (!userEmail) return;

            this.member = await getMemberByEmail({ email: userEmail });
            if (!this.member) return;

            const [payments, requests, inquiries] = await Promise.all([
                getPaymentsByMember({ memberId: this.member.Id }),
                getChangeRequestsByMember({ memberId: this.member.Id }),
                getInquiriesByMember({ memberId: this.member.Id })
            ]);

            this.unpaidCount = payments.filter(p => p.PaymentStatus__c === '未払い').length;
            this.pendingRequestCount = requests.filter(r => r.ApprovalStatus__c === '申請中').length;
            this.openInquiryCount = inquiries.filter(i =>
                !['完了', 'キャンセル'].includes(i.InquiryStatus__c)
            ).length;
        } catch (e) {
            console.error('Dashboard load error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    getUserEmail() {
        // Experience Cloud ゲストユーザー以外はセッションから取得
        return window._sfCurrentUserEmail || null;
    }

    handlePayment() {
        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: 'payment__c' } });
    }
    handleDonation() {
        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: 'donation__c' } });
    }
    handleActivity() {
        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: 'activity__c' } });
    }
    handleChangeRequest() {
        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: 'change_request__c' } });
    }
    handleSupport() {
        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: 'support__c' } });
    }
    handleOrgChart() {
        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: 'org_chart__c' } });
    }
}
