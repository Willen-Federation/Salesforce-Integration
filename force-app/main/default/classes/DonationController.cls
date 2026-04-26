public with sharing class DonationController {

    @AuraEnabled(cacheable=true)
    public static List<Donation__c> getDonationsByMember(Id memberId) {
        return [
            SELECT Id, Name, Amount__c, Purpose__c, DonationStatus__c,
                   DonationDate__c, PaymentMethod__c, IsAnonymous__c,
                   TaxDeductionCertRequired__c, ReceiptNumber__c, Message__c
            FROM Donation__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY DonationDate__c DESC
        ];
    }

    @AuraEnabled
    public static Id submitDonation(Map<String, Object> donationData) {
        Donation__c donation = new Donation__c();
        donation.Amount__c        = Decimal.valueOf(String.valueOf(donationData.get('amount')));
        donation.Purpose__c       = (String) donationData.get('purpose');
        donation.PaymentMethod__c = (String) donationData.get('paymentMethod');
        donation.DonationDate__c  = Date.today();
        donation.DonationStatus__c = '受付済み';
        donation.Message__c       = (String) donationData.get('message');

        Boolean isAnonymous = (Boolean) donationData.get('isAnonymous');
        donation.IsAnonymous__c = isAnonymous != null ? isAnonymous : false;

        if (!donation.IsAnonymous__c) {
            donation.DonorName__c  = (String) donationData.get('donorName');
            donation.DonorEmail__c = (String) donationData.get('donorEmail');
        }

        if (donationData.containsKey('memberId') && donationData.get('memberId') != null) {
            donation.Member__c = (Id) donationData.get('memberId');
        }

        donation.TaxDeductionCertRequired__c = donationData.containsKey('taxDeductionCertRequired')
            ? (Boolean) donationData.get('taxDeductionCertRequired') : false;

        if (!Schema.sObjectType.Donation__c.isCreateable()) {
            throw new AuraHandledException('寄付レコードの作成権限がありません。');
        }
        insert donation;

        EmailNotificationService.sendDonationConfirmation(donation.Id);
        return donation.Id;
    }

    @AuraEnabled
    public static void confirmDonationPayment(Id donationId) {
        Donation__c donation = new Donation__c(
            Id = donationId,
            DonationStatus__c = '入金確認済み'
        );
        update donation;
    }

    @AuraEnabled
    public static void issueDonationReceipt(Id donationId) {
        Donation__c donation = new Donation__c(
            Id = donationId,
            DonationStatus__c = '領収書発行済み'
        );
        update donation;
        EmailNotificationService.sendDonationConfirmation(donationId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getDonationSummary(Integer fiscalYear) {
        AggregateResult[] results = [
            SELECT Purpose__c, SUM(Amount__c) total, COUNT(Id) cnt
            FROM Donation__c
            WHERE DonationStatus__c IN ('入金確認済み', '領収書発行済み')
            AND CALENDAR_YEAR(DonationDate__c) = :fiscalYear
            WITH SECURITY_ENFORCED
            GROUP BY Purpose__c
        ];

        Map<String, Decimal> summary = new Map<String, Decimal>();
        Decimal total = 0;
        for (AggregateResult ar : results) {
            String purpose = (String) ar.get('Purpose__c');
            Decimal amount = (Decimal) ar.get('total');
            summary.put(purpose, amount);
            total += amount;
        }
        summary.put('_total', total);
        return summary;
    }
}
