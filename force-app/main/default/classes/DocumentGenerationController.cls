/**
 * 帳票生成コントローラー（Visualforce PDFレンダリング用）
 * PortalReceiptPage / PortalInvoicePage / DonationReceiptPage の
 * Visualforceページから参照します。
 */
public with sharing class DocumentGenerationController {

    public Payment__c  payment  { get; private set; }
    public Donation__c donation { get; private set; }
    public Member__c   member   { get; private set; }
    public PortalConfiguration__c config { get; private set; }

    // 領収書
    public DocumentGenerationController() {
        config = PortalConfiguration__c.getOrgDefaults();
        String recordId = ApexPages.currentPage().getParameters().get('id');
        String docType  = ApexPages.currentPage().getParameters().get('type');

        if (recordId == null) return;

        if (docType == 'receipt' || docType == null) {
            loadPaymentData(recordId);
        } else if (docType == 'donation') {
            loadDonationData(recordId);
        }
    }

    private void loadPaymentData(String paymentId) {
        payment = [
            SELECT Id, Name, ReceiptNumber__c, Amount__c, PaymentDate__c,
                   PaymentType__c, Description__c, PaymentMethod__c,
                   ReceiptIssuedDate__c,
                   Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.Organization__c, Member__r.Department__c,
                   Member__r.Email__c
            FROM Payment__c
            WHERE Id = :paymentId
            WITH SECURITY_ENFORCED
        ];
        member = new Member__c(
            LastName__c    = payment.Member__r.LastName__c,
            FirstName__c   = payment.Member__r.FirstName__c,
            Organization__c = payment.Member__r.Organization__c,
            Department__c  = payment.Member__r.Department__c,
            Email__c       = payment.Member__r.Email__c
        );
    }

    private void loadDonationData(String donationId) {
        donation = [
            SELECT Id, Name, ReceiptNumber__c, Amount__c, DonationDate__c,
                   Purpose__c, DonorName__c, DonorEmail__c, IsAnonymous__c,
                   TaxDeductionCertRequired__c
            FROM Donation__c
            WHERE Id = :donationId
            WITH SECURITY_ENFORCED
        ];
    }

    // 帳票種別判定
    public Boolean getIsPaymentReceipt() {
        return payment != null;
    }
    public Boolean getIsDonationReceipt() {
        return donation != null;
    }

    // 金額を円形式でフォーマット
    public String getFormattedPaymentAmount() {
        if (payment == null || payment.Amount__c == null) return '¥0';
        return '¥' + formatCurrency(payment.Amount__c);
    }
    public String getFormattedDonationAmount() {
        if (donation == null || donation.Amount__c == null) return '¥0';
        return '¥' + formatCurrency(donation.Amount__c);
    }

    private String formatCurrency(Decimal amount) {
        String s = String.valueOf(amount.longValue());
        String result = '';
        Integer len = s.length();
        for (Integer i = 0; i < len; i++) {
            if (i > 0 && Math.mod(len - i, 3) == 0) result += ',';
            result += s.substring(i, i + 1);
        }
        return result;
    }

    // 発行日（今日）
    public String getIssuedDateStr() {
        return Date.today().format();
    }

    // 組織名
    public String getOrganizationName() {
        return config != null && String.isNotBlank(config.OrganizationName__c)
            ? config.OrganizationName__c : '発行組織名';
    }
}
