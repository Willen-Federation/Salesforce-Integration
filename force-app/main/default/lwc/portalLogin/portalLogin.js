import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoginConfig      from '@salesforce/apex/OktaLoginController.getLoginConfig';
import getCurrentUser      from '@salesforce/apex/OktaLoginController.getCurrentUser';
import generateAndSendPortalToken from '@salesforce/apex/PortalMemberController.generateAndSendPortalToken';
import searchMembers       from '@salesforce/apex/PaymentController.searchMembers';

export default class PortalLogin extends NavigationMixin(LightningElement) {
    @track isLoading       = true;
    @track isLoggedIn      = false;
    @track currentUser     = {};
    @track oidcLoginUrl    = '';
    @track orgName         = '';
    @track isOktaConfigured = false;

    @track emailInput      = '';
    @track loginError      = '';
    @track isSendingLink   = false;
    @track showEmailSent   = false;

    connectedCallback() {
        this._init();
    }

    async _init() {
        try {
            const [config, user] = await Promise.all([getLoginConfig(), getCurrentUser()]);
            this.oidcLoginUrl    = config.oidcLoginUrl;
            this.orgName         = config.organizationName || '会員ポータル';
            this.isOktaConfigured = config.isOktaConfigured === true;
            this.isLoggedIn      = user.isLoggedIn === true;
            if (this.isLoggedIn) this.currentUser = user;
        } catch (e) {
            // 未認証コンテキストではエラーになるため無視
            this.isLoggedIn = false;
        } finally {
            this.isLoading = false;
        }
    }

    handleEmailInput(event) {
        this.emailInput = event.target.value;
        this.loginError = '';
    }

    handleEmailKeyDown(event) {
        if (event.key === 'Enter') this.handleSendLink();
    }

    async handleSendLink() {
        this.loginError = '';
        if (!this.emailInput || !/^[^@]+@[^@]+\.[^@]+$/.test(this.emailInput)) {
            this.loginError = '有効なメールアドレスを入力してください。';
            return;
        }

        this.isSendingLink = true;
        try {
            // メールアドレスから会員を検索してトークン送信
            const results = await searchMembers({ keyword: this.emailInput });
            const member  = results?.find(m => m.Email__c === this.emailInput);

            if (!member) {
                this.loginError = 'このメールアドレスは登録されていません。';
                return;
            }

            await generateAndSendPortalToken({ memberId: member.Id });
            this.showEmailSent = true;
        } catch (e) {
            this.loginError = e?.body?.message || 'リンクの送信に失敗しました。しばらく後に再試行してください。';
        } finally {
            this.isSendingLink = false;
        }
    }

    handleResetEmail() {
        this.emailInput    = '';
        this.showEmailSent = false;
        this.loginError    = '';
    }

    handleGoToMyPage() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'mypage__c' }
        });
    }

    handleLogout() {
        window.location.href = '/secur/logout.jsp';
    }
}
