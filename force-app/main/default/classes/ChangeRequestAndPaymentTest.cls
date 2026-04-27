@isTest
private class ChangeRequestAndPaymentTest {

    @TestSetup
    static void setup() {
        Member__c m = new Member__c(
            LastName__c = '申請', FirstName__c = 'テスト',
            Email__c = 'request@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員',
            OktaUserId__c = 'okta-req-001'
        );
        insert m;

        ChangeRequest__c cr = new ChangeRequest__c(
            RequesterMember__c = m.Id,
            RequestType__c     = 'その他',
            Priority__c        = '中',
            Description__c     = 'テスト申請内容',
            RequestDate__c     = Date.today(),
            ApprovalStatus__c  = '申請中'
        );
        insert cr;
    }

    // ChangeRequestController
    @isTest
    static void testCreateChangeRequest() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        String crName = ChangeRequestController.createChangeRequest(
            m.Id, '会員情報変更', '高', '住所が変わりました。', String.valueOf(Date.today().addDays(10))
        );
        Test.stopTest();
        System.assertNotEquals(null, crName);
    }

    @isTest
    static void testCreateChangeRequestNoDate() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        String crName = ChangeRequestController.createChangeRequest(
            m.Id, '休会申請', '中', '休会希望です。', null
        );
        Test.stopTest();
        System.assertNotEquals(null, crName);
    }

    // WorkflowApprovalService
    @isTest
    static void testGetPendingApprovals() {
        Test.startTest();
        List<ChangeRequest__c> results = WorkflowApprovalService.getPendingApprovals();
        Test.stopTest();
        System.assertNotEquals(0, results.size());
    }

    @isTest
    static void testGetChangeRequestsByMember() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        List<ChangeRequest__c> results = WorkflowApprovalService.getChangeRequestsByMember(m.Id);
        Test.stopTest();
        System.assertEquals(1, results.size());
    }

    // DocumentGenerationController
    @isTest
    static void testDocumentGenReceiptPage() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Payment__c p = new Payment__c(
            Member__c = m.Id, PaymentType__c = '年会費', Amount__c = 10000,
            DueDate__c = Date.today(), PaymentStatus__c = '支払済み',
            PaymentDate__c = Date.today(), PaymentMethod__c = 'クレジットカード（Visa/Mastercard）',
            FiscalYear__c = Date.today().year(), ReceiptIssued__c = true,
            ReceiptIssuedDate__c = Date.today()
        );
        insert p;
        Test.startTest();
        PageReference page = Page.PortalReceiptPage;
        page.getParameters().put('id', p.Id);
        page.getParameters().put('type', 'receipt');
        Test.setCurrentPage(page);
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertEquals(true,  ctrl.getIsPaymentReceipt(), '支払い領収書モード');
        System.assertEquals(false, ctrl.getIsDonationReceipt(), '寄付でないこと');
        System.assertNotEquals(null, ctrl.getFormattedPaymentAmount());
        System.assertNotEquals(null, ctrl.getIssuedDateStr());
        Test.stopTest();
    }

    @isTest
    static void testDocumentGenDonationPage() {
        Donation__c d = new Donation__c(
            DonorName__c = '寄付 テスト', DonorEmail__c = 'donor@example.com',
            Amount__c = 5000, Purpose__c = '一般活動費',
            DonationDate__c = Date.today(), DonationStatus__c = '入金確認済み',
            IsAnonymous__c = false, TaxDeductionCertRequired__c = true
        );
        insert d;
        Test.startTest();
        PageReference page = Page.DonationReceiptPage;
        page.getParameters().put('id', d.Id);
        page.getParameters().put('type', 'donation');
        Test.setCurrentPage(page);
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertEquals(false, ctrl.getIsPaymentReceipt());
        System.assertEquals(true,  ctrl.getIsDonationReceipt());
        System.assertNotEquals(null, ctrl.getFormattedDonationAmount());
        Test.stopTest();
    }

    @isTest
    static void testDocumentGenNoId() {
        Test.startTest();
        PageReference page = Page.PortalReceiptPage;
        Test.setCurrentPage(page);
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertEquals(null, ctrl.payment);
        Test.stopTest();
    }
}
