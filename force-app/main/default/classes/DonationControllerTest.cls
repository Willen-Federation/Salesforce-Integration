@isTest
private class DonationControllerTest {

    @TestSetup
    static void setup() {
        Member__c m = new Member__c(
            LastName__c = '寄付', FirstName__c = 'テスト',
            Email__c = 'donor@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員'
        );
        insert m;

        Donation__c d = new Donation__c(
            Member__c        = m.Id,
            DonorName__c     = '寄付 テスト',
            DonorEmail__c    = 'donor@example.com',
            Amount__c        = 5000,
            Purpose__c       = '一般活動費',
            DonationDate__c  = Date.today(),
            DonationStatus__c = '受付済み',
            PaymentMethod__c = 'クレジットカード',
            IsAnonymous__c   = false
        );
        insert d;
    }

    @isTest
    static void testGetDonationsByMember() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        List<Donation__c> results = DonationController.getDonationsByMember(m.Id);
        Test.stopTest();
        System.assertEquals(1, results.size());
    }

    @isTest
    static void testSubmitDonationWithMember() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{
            'amount'        => 10000,
            'purpose'       => '研究助成',
            'paymentMethod' => '銀行振込',
            'isAnonymous'   => false,
            'donorName'     => '寄付 太郎',
            'donorEmail'    => 'donor2@example.com',
            'taxDeductionCertRequired' => true,
            'message'       => 'テストメッセージ',
            'memberId'      => (Object)m.Id
        };
        Test.startTest();
        Id donationId = DonationController.submitDonation(data);
        Test.stopTest();
        System.assertNotEquals(null, donationId);
        Donation__c d = [SELECT Amount__c, TaxDeductionCertRequired__c FROM Donation__c WHERE Id = :donationId];
        System.assertEquals(10000, d.Amount__c);
        System.assertEquals(true, d.TaxDeductionCertRequired__c);
    }

    @isTest
    static void testSubmitDonationAnonymous() {
        Map<String, Object> data = new Map<String, Object>{
            'amount'        => 3000,
            'purpose'       => '教育支援',
            'paymentMethod' => '口座振替',
            'isAnonymous'   => true,
            'taxDeductionCertRequired' => false,
            'message'       => null,
            'memberId'      => null
        };
        Test.startTest();
        Id donationId = DonationController.submitDonation(data);
        Test.stopTest();
        Donation__c d = [SELECT IsAnonymous__c FROM Donation__c WHERE Id = :donationId];
        System.assertEquals(true, d.IsAnonymous__c);
    }

    @isTest
    static void testConfirmDonationPayment() {
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];
        Test.startTest();
        DonationController.confirmDonationPayment(d.Id);
        Test.stopTest();
        Donation__c updated = [SELECT DonationStatus__c FROM Donation__c WHERE Id = :d.Id];
        System.assertEquals('入金確認済み', updated.DonationStatus__c);
    }

    @isTest
    static void testIssueDonationReceipt() {
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];
        update new Donation__c(Id = d.Id, DonationStatus__c = '入金確認済み');
        Test.startTest();
        DonationController.issueDonationReceipt(d.Id);
        Test.stopTest();
        Donation__c updated = [SELECT DonationStatus__c FROM Donation__c WHERE Id = :d.Id];
        System.assertEquals('領収書発行済み', updated.DonationStatus__c);
    }

    @isTest
    static void testGetDonationSummary() {
        Test.startTest();
        Map<String, Decimal> summary = DonationController.getDonationSummary(Date.today().year());
        Test.stopTest();
        System.assertNotEquals(null, summary);
    }
}
