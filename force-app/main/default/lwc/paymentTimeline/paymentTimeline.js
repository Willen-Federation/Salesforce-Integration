import { LightningElement, api, track } from 'lwc';
import getHistory from '@salesforce/apex/PaymentStatusHistoryService.getHistory';

const STATUS_CONFIG = {
    '未払い':  { icon: 'utility:clock',         cls: 'slds-badge' },
    '支払済み': { icon: 'utility:check',          cls: 'slds-badge slds-theme_success' },
    'キャンセル':{ icon: 'utility:close',         cls: 'slds-badge slds-theme_error' },
    '返金済み': { icon: 'utility:undo',           cls: 'slds-badge slds-theme_warning' },
    '延滞':    { icon: 'utility:warning',         cls: 'slds-badge slds-theme_error' },
    '審査待ち': { icon: 'utility:user',            cls: 'slds-badge slds-theme_warning' },
    '承認済':  { icon: 'utility:approval',        cls: 'slds-badge slds-theme_success' },
    '却下':    { icon: 'utility:ban',             cls: 'slds-badge slds-theme_error' },
};

export default class PaymentTimeline extends LightningElement {
    @api paymentId;
    @track historyItems = [];
    @track isLoading = false;

    connectedCallback() {
        this.load();
    }

    async load() {
        if (!this.paymentId) return;
        this.isLoading = true;
        try {
            const data = await getHistory({ paymentId: this.paymentId });
            this.historyItems = data.map(h => {
                const cfg = STATUS_CONFIG[h.NewStatus__c] || { icon: 'utility:record', cls: 'slds-badge' };
                return {
                    ...h,
                    _icon:          cfg.icon,
                    _badgeClass:    cfg.cls,
                    _iconClass:     'slds-icon-utility-' + cfg.icon.replace('utility:', ''),
                    _formattedDate: h.ChangedAt__c
                        ? new Date(h.ChangedAt__c).toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })
                        : '',
                };
            });
        } catch (e) {
            this.historyItems = [];
        } finally {
            this.isLoading = false;
        }
    }

    get hasHistory() { return this.historyItems.length > 0; }
}
