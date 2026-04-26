import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentsByMember from '@salesforce/apex/PaymentController.getPaymentsByMember';
import recordPayment from '@salesforce/apex/PaymentController.recordPayment';
import issueReceipt from '@salesforce/apex/PaymentController.issueReceipt';

const PAYMENT_METHOD_OPTIONS = [
    { label: 'クレジットカード', value: 'クレジットカード' },
    { label: '銀行振込',         value: '銀行振込' },
    { label: '口座振替',         value: '口座振替' },
    { label: '請求書払い',       value: '請求書払い' },
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
    @track payments = [];
    @track selectedPayment;
    @track showModal = false;
    @track paymentMethod = 'クレジットカード';
    @track isProcessing = false;

    columns = UNPAID_COLUMNS;
    paidColumns = PAID_COLUMNS;
    paymentMethodOptions = PAYMENT_METHOD_OPTIONS;

    connectedCallback() {
        this.loadPayments();
    }

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

    get unpaidPayments() {
        return this.payments.filter(p => p.PaymentStatus__c === '未払い');
    }
    get paidPayments() {
        return this.payments.filter(p => p.PaymentStatus__c === '支払済み');
    }
    get hasUnpaidPayments() { return this.unpaidPayments.length > 0; }
    get hasPaidPayments()   { return this.paidPayments.length > 0; }

    get formattedAmount() {
        if (!this.selectedPayment) return '';
        return new Intl.NumberFormat('ja-JP', { style: 'currency', currency: 'JPY' })
            .format(this.selectedPayment.Amount__c);
    }

    handleRowAction(event) {
        this.selectedPayment = event.detail.row;
        this.showModal = true;
    }

    handleMethodChange(event) {
        this.paymentMethod = event.detail.value;
    }

    closeModal() {
        this.showModal = false;
        this.selectedPayment = null;
    }

    async handleConfirmPayment() {
        if (!this.paymentMethod) {
            this.showToast('入力エラー', '支払方法を選択してください。', 'error');
            return;
        }
        this.isProcessing = true;
        try {
            const txId = 'TX-' + Date.now();
            await recordPayment({
                paymentId: this.selectedPayment.Id,
                transactionId: txId,
                paymentMethod: this.paymentMethod
            });
            this.showToast('支払い完了', 'お支払いが確認されました。', 'success');
            this.closeModal();
            await this.loadPayments();
        } catch (e) {
            this.showToast('エラー', e?.body?.message, 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async handleReceiptAction(event) {
        const row = event.detail.row;
        try {
            await issueReceipt({ paymentId: row.Id });
            this.showToast('領収書発行', '領収書を発行しました。メールでもお送りしています。', 'success');
            window.open(`/apex/PortalReceiptPage?id=${row.Id}`, '_blank');
            await this.loadPayments();
        } catch (e) {
            this.showToast('エラー', e?.body?.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
