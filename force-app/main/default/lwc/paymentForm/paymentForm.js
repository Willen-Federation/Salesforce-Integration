import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentsByMember from '@salesforce/apex/PaymentController.getPaymentsByMember';
import recordPayment       from '@salesforce/apex/PaymentController.recordPayment';
import issueReceipt        from '@salesforce/apex/PaymentController.issueReceipt';
import processPayment      from '@salesforce/apex/PaymentGatewayService.processPayment';
import getProviderConfig   from '@salesforce/apex/PaymentGatewayService.getProviderConfig';
import getDirectDebitFormUrl from '@salesforce/apex/PaymentGatewayService.getDirectDebitFormUrl';

const PAYMENT_METHOD_OPTIONS = [
    { label: 'クレジットカード', value: 'credit_card' },
    { label: '銀行振込',         value: 'bank_transfer' },
    { label: '口座振替',         value: 'direct_debit' },
    { label: '請求書払い',       value: 'invoice' },
];

const UNPAID_COLUMNS = [
    { label: '支払い番号', fieldName: 'Name' },
    { label: '種別',       fieldName: 'PaymentType__c' },
    { label: '金額',       fieldName: 'Amount__c', type: 'currency', typeAttributes: { currencyCode: 'JPY' } },
    { label: '支払期限',   fieldName: 'DueDate__c', type: 'date' },
    { label: '操作', type: 'button', typeAttributes: { label: '支払う', name: 'pay', variant: 'brand' } },
];

const PAID_COLUMNS = [
    { label: '支払い番号', fieldName: 'Name' },
    { label: '種別',       fieldName: 'PaymentType__c' },
    { label: '金額',       fieldName: 'Amount__c', type: 'currency', typeAttributes: { currencyCode: 'JPY' } },
    { label: '支払日',     fieldName: 'PaymentDate__c', type: 'date' },
    { label: '領収書',     fieldName: 'ReceiptIssued__c', type: 'boolean' },
    { label: '操作', type: 'button', typeAttributes: {
        label: { fieldName: '_receiptLabel' }, name: 'receipt', variant: 'neutral'
    }},
];

export default class PaymentForm extends LightningElement {
    @api memberId;

    @track payments        = [];
    @track selectedPayment = null;
    @track showModal       = false;
    @track paymentMethod   = 'credit_card';
    @track isProcessing    = false;
    @track isLoadingProvider = true;
    @track gatewayError    = '';

    columns      = UNPAID_COLUMNS;
    paidColumns  = PAID_COLUMNS;
    paymentMethodOptions = PAYMENT_METHOD_OPTIONS;

    // プロバイダー設定（getProviderConfig() から取得）
    _providerName = '';
    _publicKey    = '';
    _iframeWindow = null;
    _messageHandler = null;

    connectedCallback() {
        this.loadPayments();
        this.loadProviderConfig();
    }

    disconnectedCallback() {
        this._removeMessageListener();
    }

    // ----------------------------------------------------------------
    // データ読み込み
    // ----------------------------------------------------------------

    async loadPayments() {
        try {
            const data = await getPaymentsByMember({ memberId: this.memberId });
            this.payments = data.map(p => ({
                ...p,
                _receiptLabel: p.ReceiptIssued__c ? '領収書再発行' : '領収書発行'
            }));
        } catch (e) {
            this.showToast('エラー', e?.body?.message, 'error');
        }
    }

    async loadProviderConfig() {
        try {
            const cfg = await getProviderConfig();
            this._providerName = cfg.provider || 'none';
            this._publicKey    = cfg.publicKey || '';
        } catch (e) {
            this._providerName = 'none';
        }
    }

    // ----------------------------------------------------------------
    // Getter
    // ----------------------------------------------------------------

    get unpaidPayments()    { return this.payments.filter(p => p.PaymentStatus__c === '未払い'); }
    get paidPayments()      { return this.payments.filter(p => p.PaymentStatus__c === '支払済み'); }
    get hasUnpaidPayments() { return this.unpaidPayments.length > 0; }
    get hasPaidPayments()   { return this.paidPayments.length > 0; }

    get formattedAmount() {
        if (!this.selectedPayment) return '';
        return new Intl.NumberFormat('ja-JP', { style: 'currency', currency: 'JPY' })
            .format(this.selectedPayment.Amount__c);
    }

    get showCardFrame()  { return this.paymentMethod === 'credit_card'; }
    get isBankTransfer() { return this.paymentMethod === 'bank_transfer'; }
    get isDirectDebit()  { return this.paymentMethod === 'direct_debit'; }
    get isInvoice()      { return this.paymentMethod === 'invoice'; }

    /** VF ページの URL をプロバイダー・公開鍵・金額付きで生成 */
    get cardFrameUrl() {
        if (!this.selectedPayment || !this._providerName || this._providerName === 'none') {
            return null;
        }
        const origin = encodeURIComponent(window.location.origin);
        const desc   = encodeURIComponent(
            this.selectedPayment.PaymentType__c + ' - ' + this.selectedPayment.Name
        );
        return (
            `/apex/PaymentCardForm` +
            `?provider=${encodeURIComponent(this._providerName)}` +
            `&publicKey=${encodeURIComponent(this._publicKey)}` +
            `&amount=${this.selectedPayment.Amount__c}` +
            `&description=${desc}` +
            `&paymentId=${this.selectedPayment.Id}` +
            `&origin=${origin}`
        );
    }

    // ----------------------------------------------------------------
    // イベントハンドラ
    // ----------------------------------------------------------------

    handleRowAction(event) {
        this.selectedPayment = event.detail.row;
        this.paymentMethod   = 'credit_card';
        this.gatewayError    = '';
        this.isLoadingProvider = true;
        this.showModal       = true;
        this._setupMessageListener();
    }

    handleMethodChange(event) {
        this.paymentMethod = event.detail.value;
        this.gatewayError  = '';
        if (this.paymentMethod === 'credit_card') {
            this.isLoadingProvider = true;
            this._setupMessageListener();
        } else {
            this._removeMessageListener();
        }
    }

    handleIframeLoad() {
        this.isLoadingProvider = false;
        // iframe への参照を保持
        const iframe = this.template.querySelector('iframe');
        if (iframe) {
            this._iframeWindow = iframe.contentWindow;
        }
    }

    closeModal() {
        this.showModal       = false;
        this.selectedPayment = null;
        this.gatewayError    = '';
        this.isProcessing    = false;
        this._removeMessageListener();
    }

    /** カード以外の支払方法（銀行振込・口座振替・請求書）を確定 */
    async handleNonCardPayment() {
        const methodLabel = PAYMENT_METHOD_OPTIONS.find(o => o.value === this.paymentMethod)?.label || this.paymentMethod;
        this.isProcessing = true;
        try {
            await recordPayment({
                paymentId:     this.selectedPayment.Id,
                transactionId: 'PENDING-' + Date.now(),
                paymentMethod: methodLabel
            });
            this.showToast('申請完了', `${methodLabel}での支払い申請が完了しました。`, 'success');
            this.closeModal();
            await this.loadPayments();
        } catch (e) {
            this.showToast('エラー', e?.body?.message, 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async handleDirectDebitDownload() {
        try {
            const url = await getDirectDebitFormUrl();
            if (url) {
                window.open(url, '_blank');
            } else {
                this.showToast('情報', '口座振替申込書のURLが設定されていません。', 'warning');
            }
        } catch (e) {
            this.showToast('エラー', e?.body?.message, 'error');
        }
    }

    async handleReceiptAction(event) {
        const row = event.detail.row;
        try {
            if (!row.ReceiptIssued__c) {
                await issueReceipt({ paymentId: row.Id });
                this.showToast('領収書発行', '領収書を発行しました。メールでもお送りしています。', 'success');
                await this.loadPayments();
            }
            window.open(`/apex/PortalReceiptPage?id=${row.Id}`, '_blank');
        } catch (e) {
            this.showToast('エラー', e?.body?.message, 'error');
        }
    }

    // ----------------------------------------------------------------
    // iframe postMessage 連携
    // ----------------------------------------------------------------

    _setupMessageListener() {
        this._removeMessageListener();
        this._messageHandler = this._onIframeMessage.bind(this);
        window.addEventListener('message', this._messageHandler);
    }

    _removeMessageListener() {
        if (this._messageHandler) {
            window.removeEventListener('message', this._messageHandler);
            this._messageHandler = null;
        }
    }

    async _onIframeMessage(event) {
        // 同一オリジンからのメッセージのみ処理
        if (event.origin !== window.location.origin) return;

        const data = event.data;
        if (!data || data.type !== 'PAYJP_OMISE_STRIPE_TOKEN') return;

        const { token, paymentId, provider } = data;
        if (!token || !paymentId) {
            this.gatewayError = 'カードトークンの取得に失敗しました。';
            return;
        }

        await this._processCardPayment(paymentId, provider, token);
    }

    async _processCardPayment(paymentId, provider, token) {
        this.isProcessing = true;
        this.gatewayError = '';
        try {
            const result = await processPayment({
                paymentId:   paymentId,
                provider:    provider,
                token:       token,
                amount:      this.selectedPayment.Amount__c,
                description: this.selectedPayment.PaymentType__c + ' - ' + this.selectedPayment.Name
            });

            if (result.success) {
                this.showToast('支払い完了', 'クレジットカードでのお支払いが完了しました。', 'success');
                this.closeModal();
                await this.loadPayments();
            } else {
                this.gatewayError = result.failureMessage || '決済に失敗しました。カード情報をご確認ください。';
            }
        } catch (e) {
            this.gatewayError = e?.body?.message || '決済処理中にエラーが発生しました。';
        } finally {
            this.isProcessing = false;
        }
    }

    // ----------------------------------------------------------------
    // ユーティリティ
    // ----------------------------------------------------------------

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
