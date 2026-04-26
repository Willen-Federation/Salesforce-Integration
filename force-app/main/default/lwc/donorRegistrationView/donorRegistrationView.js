import { LightningElement, track } from 'lwc';
import getDonationSummary from '@salesforce/apex/DonationController.getDonationSummary';

export default class DonorRegistrationView extends LightningElement {
    @track donations = [];
    @track isLoading = false;
    @track selectedDonor = null;
    @track filterFrom = '';
    @track filterTo = '';
    @track filterStatus = '支払済み';

    sortedBy = 'DonationDate__c';
    sortedDirection = 'desc';

    statusOptions = [
        { label: 'すべて', value: '' },
        { label: '支払済み', value: '支払済み' },
        { label: '未払い', value: '未払い' },
        { label: 'キャンセル', value: 'キャンセル' }
    ];

    columns = [
        { label: '寄付番号', fieldName: 'Name', type: 'text', sortable: true },
        { label: '寄付者名', fieldName: 'DonorName__c', type: 'text', sortable: true },
        { label: 'メール', fieldName: 'DonorEmail__c', type: 'email' },
        { label: '金額', fieldName: 'Amount__c', type: 'currency', sortable: true, typeAttributes: { currencyCode: 'JPY' } },
        { label: 'ステータス', fieldName: 'PaymentStatus__c', type: 'text', sortable: true },
        { label: '匿名', fieldName: 'isAnonymousLabel', type: 'text' },
        { label: '税控除証明書', fieldName: 'taxCertLabel', type: 'text' },
        { label: '寄付日', fieldName: 'DonationDate__c', type: 'date', sortable: true },
        { label: '詳細', type: 'button', typeAttributes: { label: '確認', name: 'view', variant: 'base' } }
    ];

    get hasDonations() {
        return this.donations && this.donations.length > 0;
    }

    get totalCount() {
        return this.donations.length;
    }

    get formattedTotal() {
        const total = this.donations.reduce((sum, d) => sum + (d.Amount__c || 0), 0);
        return total.toLocaleString('ja-JP');
    }

    get taxCertCount() {
        return this.donations.filter(d => d.TaxDeductionCertRequired__c).length;
    }

    connectedCallback() {
        this.handleSearch();
    }

    handleFilterFrom(event) { this.filterFrom = event.target.value; }
    handleFilterTo(event)   { this.filterTo   = event.target.value; }
    handleFilterStatus(event) { this.filterStatus = event.detail.value; }

    handleSearch() {
        this.isLoading = true;
        getDonationSummary()
            .then(data => {
                let results = data.map(d => ({
                    ...d,
                    isAnonymousLabel: d.IsAnonymous__c ? '匿名' : '—',
                    taxCertLabel:     d.TaxDeductionCertRequired__c ? '要' : '不要',
                    DonorName__c:     d.IsAnonymous__c ? '（匿名）' : d.DonorName__c
                }));

                if (this.filterStatus) {
                    results = results.filter(d => d.PaymentStatus__c === this.filterStatus);
                }
                if (this.filterFrom) {
                    results = results.filter(d => d.DonationDate__c >= this.filterFrom);
                }
                if (this.filterTo) {
                    results = results.filter(d => d.DonationDate__c <= this.filterTo);
                }

                this.donations = results;
                this.isLoading = false;
            })
            .catch(() => {
                this.isLoading = false;
            });
    }

    handleSort(event) {
        this.sortedBy        = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        const dir = this.sortedDirection === 'asc' ? 1 : -1;
        this.donations = [...this.donations].sort((a, b) => {
            const av = a[this.sortedBy] || '';
            const bv = b[this.sortedBy] || '';
            return av > bv ? dir : av < bv ? -dir : 0;
        });
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'view') {
            this.selectedDonor = event.detail.row;
        }
    }

    handleCloseDetail() {
        this.selectedDonor = null;
    }
}
