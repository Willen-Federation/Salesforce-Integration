@isTest
private class PaymentControllerTest {

    @TestSetup
    static void setup() {
        Member__c member = new Member__c(
            LastName__c     = '支払',
            FirstName__c    = 'テスト',
            Email__c        = 'payment@example.com',
            MemberStatus__c = '正会員',
            MemberType__c   = '個人会員'
        );
        insert member;

        Payment__c p = new Payment__c(
            Member__c        = member.Id,
            PaymentType__c   = '年会費',
            Amount__c        = 10000,
            DueDate__c       = Date.today().addDays(30),
            PaymentStatus__c = '未払い',
            FiscalYear__c    = Date.today().year()
        );
        insert p;
    }

    @isTest
    static void testGetPaymentsByMember() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        List<Payment__c> payments = PaymentController.getPaymentsByMember(m.Id);
        Test.stopTest();
        System.assertEquals(1, payments.size(), '1件の支払いが取得されること');
    }

    @isTest
    static void testGetOverduePayments() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Payment__c overdue = new Payment__c(
            Member__c        = m.Id,
            PaymentType__c   = '年会費',
            Amount__c        = 5000,
            DueDate__c       = Date.today().addDays(-10),
            PaymentStatus__c = '未払い',
            FiscalYear__c    = Date.today().year()
        );
        insert overdue;
        Test.startTest();
        List<Payment__c> results = PaymentController.getOverduePayments();
        Test.stopTest();
        System.assertNotEquals(0, results.size(), '延滞支払いが取得されること');
    }

    @isTest
    static void testCreatePayment() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        Id pid = PaymentController.createPayment(
            m.Id, '個別利用料', 3000, Date.today().addDays(14), '銀行振込', 'テスト利用料'
        );
        Test.stopTest();
        System.assertNotEquals(null, pid);
        Payment__c p = [SELECT PaymentStatus__c FROM Payment__c WHERE Id = :pid];
        System.assertEquals('未払い', p.PaymentStatus__c);
    }

    @isTest
    static void testRecordPayment() {
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        Test.startTest();
        PaymentController.recordPayment(p.Id, 'TX-TEST-001', 'クレジットカード');
        Test.stopTest();
        Payment__c updated = [SELECT PaymentStatus__c, TransactionId__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals('支払済み', updated.PaymentStatus__c);
        System.assertEquals('TX-TEST-001', updated.TransactionId__c);
    }

    @isTest
    static void testIssueReceipt() {
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        update new Payment__c(Id = p.Id, PaymentStatus__c = '支払済み', PaymentDate__c = Date.today());
        Test.startTest();
        Id result = PaymentController.issueReceipt(p.Id);
        Test.stopTest();
        System.assertEquals(p.Id, result);
        Payment__c updated = [SELECT ReceiptIssued__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals(true, updated.ReceiptIssued__c);
    }

    @isTest
    static void testIssueReceiptAlreadyIssued() {
        Payment__c p = [SELECT Id FROM Payment__c LIMIT 1];
        update new Payment__c(Id = p.Id, PaymentStatus__c = '支払済み',
                               PaymentDate__c = Date.today(), ReceiptIssued__c = true);
        Test.startTest();
        try {
            PaymentController.issueReceipt(p.Id);
            System.assert(false, '例外が発生するべき');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('既に'), '既発行エラーメッセージ');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAnnualFeePayments() {
        Test.startTest();
        PaymentController.createAnnualFeePayments(Date.today().year() + 1);
        Test.stopTest();
        List<Payment__c> annual = [
            SELECT Id FROM Payment__c
            WHERE FiscalYear__c = :(Date.today().year() + 1) AND PaymentType__c = '年会費'
        ];
        System.assertNotEquals(0, annual.size(), '年会費が作成されること');
    }
}
