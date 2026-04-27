import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentsByMember     from '@salesforce/apex/PaymentController.getPaymentsByMember';
import recordPayment           from '@salesforce/apex/PaymentController.recordPayment';
import issueReceipt            from '@salesforce/apex/PaymentController.issueReceipt';
import getActivePaymentMethods from '@salesforce/apex/PaymentController.getActivePaymentMethods';
import processPayment          from '@salesforce/apex/PaymentGatewayService.processPayment';
import getProviderConfig       from '@salesforce/apex/PaymentGatewayService.getProviderConfig';
import getDirectDebitFormUrl   from '@salesforce/apex/PaymentGatewayService.getDirectDebitFormUrl';
import calculateMethodFees     from '@salesforce/apex/PaymentFeeRuleController.calculateMethodFees';

// 利用可能手段が指定されていない場合の汎用選択肢
const FALLBACK_METHOD_OPTIONS = [
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

// ゲートウェイが必要なカード決済のキー
const CARD_METHOD_KEYS = new Set(['payjp_card', 'omise_card', 'stripe_card']);
// ゲートウェイが必要な非カード手段のキー（コンビニ・Pay-easyなど）
const ALT_GATEWAY_KEYS = new Set(['omise_convenience_store', 'omise_pay_easy', 'stripe_konbini']);

export default class PaymentForm extends LightningElement {
    @api memberId;

    @track payments          = [];
    @track selectedPayment   = null;
    @track showModal         = false;
    @track isProcessing      = false;
    @track isLoadingProvider = true;
    @track gatewayError      = '';

    // 選択中の支払い手段（methodKey または fallback value）
    @track selectedMethodKey = '';

    // 汎用セレクター用（AllowedPaymentMethods__c が未設定の場合）
    @track paymentMethod = 'credit_card';

    // 決済手段マスターデータ（methodKey → メタデータ）
    _allMethods = [];
    // 決済手段別手数料計算結果
    _methodFeeResult = null;

    columns      = UNPAID_COLUMNS;
    paidColumns  = PAID_COLUMNS;
    paymentMethodOptions = FALLBACK_METHOD_OPTIONS;

    _providerName = '';
    _publicKey    = '';
    _messageHandler = null;

    connectedCallback() {
        this.loadPayments();
        this.loadProviderConfig();
        this.loadAllMethods();
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

    async loadAllMethods() {
        try {
            this._allMethods = await getActivePaymentMethods();
        } catch (e) {
            this._allMethods = [];
        }
    }

    async _loadMethodFees() {
        const methodKey = this._currentMethodKey;
        const baseAmount = this.selectedPayment?.BaseAmount__c || this.selectedPayment?.Amount__c;
        if (!methodKey || !baseAmount) {
            this._methodFeeResult = null;
            return;
        }
        try {
            this._methodFeeResult = await calculateMethodFees({ methodKey, baseAmount });
        } catch (e) {
            this._methodFeeResult = null;
        }
    }

    // ----------------------------------------------------------------
    // Getter
    // ----------------------------------------------------------------

    get unpaidPayments()    { return this.payments.filter(p => p.PaymentStatus__c === '未払い'); }
    get paidPayments()      { return this.payments.filter(p => p.PaymentStatus__c === '支払済み'); }
    get hasUnpaidPayments() { return this.unpaidPayments.length > 0; }
    get hasPaidPayments()   { return this.paidPayments.length > 0; }

    // 金額内訳 getter
    get hasBaseAmount() {
        return this.selectedPayment?.BaseAmount__c != null && this.selectedPayment.BaseAmount__c > 0;
    }
    get hasPlatformFee() {
        return this.selectedPayment?.PlatformFee__c != null && this.selectedPayment.PlatformFee__c > 0;
    }
    get platformFeeDescription() { return 'プラットフォーム利用手数料'; }

    get methodFeeAmount() {
        return this._methodFeeResult?.totalFeeAmount ?? 0;
    }
    get methodFeeBreakdown() {
        return this._methodFeeResult?.breakdown ?? [];
    }
    get hasMethodFee() { return this.methodFeeAmount > 0; }

    get totalPayAmount() {
        if (!this.selectedPayment) return 0;
        return (this.selectedPayment.Amount__c || 0) + this.methodFeeAmount;
    }

    _formatYen(v) {
        return '¥' + Number(v).toLocaleString('ja-JP');
    }
    get formattedBaseAmount()  { return this._formatYen(this.selectedPayment?.BaseAmount__c || 0); }
    get formattedPlatformFee() { return this._formatYen(this.selectedPayment?.PlatformFee__c || 0); }
    get formattedMethodFee()   { return this._formatYen(this.methodFeeAmount); }
    get formattedTotal()       { return this._formatYen(this.totalPayAmount); }

    // 請求に利用可能手段が指定されているか
    get hasAllowedMethods() {
        return this.selectedPayment?.AllowedPaymentMethods__c != null
            && this.selectedPayment.AllowedPaymentMethods__c.trim() !== '';
    }

    // 利用可能手段のラジオボタン用リスト
    get allowedMethodOptions() {
        if (!this.hasAllowedMethods) return [];
        const allowedKeys = this.selectedPayment.AllowedPaymentMethods__c.split(';')
            .map(k => k.trim()).filter(Boolean);
        return allowedKeys.map(key => {
            const meta = this._allMethods.find(m => m.methodKey === key)
                || { methodKey: key, displayName: key };
            return {
                ...meta,
                radioId: 'method_' + key,
                checked: this.selectedMethodKey === key,
            };
        });
    }

    // 現在選択中の手段が何かを判定
    get _currentMethodKey() {
        return this.hasAllowedMethods ? this.selectedMethodKey : this.paymentMethod;
    }

    get showCardFrame() {
        return CARD_METHOD_KEYS.has(this._currentMethodKey)
            || ALT_GATEWAY_KEYS.has(this._currentMethodKey);
    }
    get showAlternativeGateway() { return false; }
    get isBankTransfer()  { return this._currentMethodKey === 'bank_transfer'; }
    get isDirectDebit()   { return this._currentMethodKey === 'direct_debit'; }
    get isInvoice()       { return this._currentMethodKey === 'invoice'; }

    get cardFrameUrl() {
        if (!this.selectedPayment || !this._providerName || this._providerName === 'none') return null;
        const origin   = encodeURIComponent(window.location.origin);
        const methodKey = encodeURIComponent(this._currentMethodKey || 'credit_card');
        const desc     = encodeURIComponent(
            this.selectedPayment.PaymentType__c + ' - ' + this.selectedPayment.Name
        );
        const totalAmount = this.totalPayAmount;
        return (
            `/apex/PaymentCardForm` +
            `?provider=${encodeURIComponent(this._providerName)}` +
            `&publicKey=${encodeURIComponent(this._publicKey)}` +
            `&methodKey=${methodKey}` +
            `&amount=${totalAmount}` +
            `&description=${desc}` +
            `&paymentId=${this.selectedPayment.Id}` +
            `&origin=${origin}`
        );
    }

    // ----------------------------------------------------------------
    // イベントハンドラ
    // ----------------------------------------------------------------

    handleRowAction(event) {
        this.selectedPayment   = event.detail.row;
        this.gatewayError      = '';
        this.isLoadingProvider = true;
        this._methodFeeResult  = null;

        if (this.selectedPayment?.AllowedPaymentMethods__c) {
            const first = this.selectedPayment.AllowedPaymentMethods__c.split(';')[0].trim();
            this.selectedMethodKey = first;
        } else {
            this.paymentMethod     = 'credit_card';
            this.selectedMethodKey = 'credit_card';
        }

        this.showModal = true;
        this._loadMethodFees();
        if (this.showCardFrame) {
            this._setupMessageListener();
        }
    }

    handleMethodRadioChange(event) {
        this.selectedMethodKey = event.target.value;
        this.gatewayError = '';
        this._loadMethodFees();
        if (this.showCardFrame) {
            this.isLoadingProvider = true;
            this._setupMessageListener();
        } else {
            this._removeMessageListener();
        }
    }

    handleMethodChange(event) {
        this.paymentMethod     = event.detail.value;
        this.selectedMethodKey = event.detail.value;
        this.gatewayError = '';
        this._loadMethodFees();
        if (this.showCardFrame) {
            this.isLoadingProvider = true;
            this._setupMessageListener();
        } else {
            this._removeMessageListener();
        }
    }

    handleIframeLoad() {
        this.isLoadingProvider = false;
    }

    closeModal() {
        this.showModal        = false;
        this.selectedPayment  = null;
        this.gatewayError     = '';
        this.isProcessing     = false;
        this._methodFeeResult = null;
        this._removeMessageListener();
    }

    async handleNonCardPayment() {
        const methodKey = this._currentMethodKey;
        const meta      = this._allMethods.find(m => m.methodKey === methodKey);
        const methodLabel = meta?.displayName
            || FALLBACK_METHOD_OPTIONS.find(o => o.value === methodKey)?.label
            || methodKey;

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

    async handleAlternativeGateway() {
        // コンビニ・Pay-easy などゲートウェイ経由の非カード手段
        // 実際の処理はプロバイダーAPIで行うが、ここでは申請のみ記録
        await this.handleNonCardPayment();
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
        if (event.origin !== window.location.origin) return;
        const data = event.data;
        if (!data) return;

        if (data.type === 'PAYJP_OMISE_STRIPE_TOKEN') {
            const { token, paymentId, provider } = data;
            if (!token || !paymentId) {
                this.gatewayError = 'カードトークンの取得に失敗しました。';
                return;
            }
            await this._processCardPayment(paymentId, provider, token);

        } else if (data.type === 'ALT_GATEWAY_PROCEED') {
            // コンビニ・Pay-easy・Konbini などの非カードゲートウェイ手段
            const { paymentId, methodKey } = data;
            const meta = this._allMethods.find(m => m.methodKey === methodKey);
            const methodLabel = meta?.displayName || methodKey;
            await this.handleNonCardPaymentDirect(paymentId, methodLabel);
        }
    }

    async handleNonCardPaymentDirect(paymentId, methodLabel) {
        this.isProcessing = true;
        try {
            await recordPayment({
                paymentId,
                transactionId: 'ALT-' + Date.now(),
                paymentMethod: methodLabel
            });
            this.showToast('申請完了', `${methodLabel}での支払い申請が完了しました。`, 'success');
            this.closeModal();
            await this.loadPayments();
        } catch (e) {
            this.gatewayError = e?.body?.message || '処理中にエラーが発生しました。';
        } finally {
            this.isProcessing = false;
        }
    }

    async _processCardPayment(paymentId, provider, token) {
        this.isProcessing = true;
        this.gatewayError = '';
        try {
            const result = await processPayment({
                paymentId,
                provider,
                token,
                amount:      this.totalPayAmount,
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
