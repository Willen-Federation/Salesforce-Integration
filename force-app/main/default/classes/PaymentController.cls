public with sharing class PaymentController {

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPaymentsByMember(Id memberId) {
        return [
            SELECT Id, Name, PaymentType__c, Amount__c, PaymentStatus__c,
                   DueDate__c, PaymentDate__c, PaymentMethod__c, TransactionId__c,
                   FiscalYear__c, Description__c, ReceiptIssued__c,
                   ReceiptIssuedDate__c, ReceiptNumber__c
            FROM Payment__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY DueDate__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getOverduePayments() {
        return [
            SELECT Id, Name, Member__c, Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.Email__c, PaymentType__c, Amount__c, PaymentStatus__c, DueDate__c
            FROM Payment__c
            WHERE PaymentStatus__c = '未払い'
            AND DueDate__c < TODAY
            WITH SECURITY_ENFORCED
            ORDER BY DueDate__c ASC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Id createPayment(Id memberId, String paymentType, Decimal amount,
                                    Date dueDate, String paymentMethod, String description) {
        Payment__c payment = new Payment__c(
            Member__c       = memberId,
            PaymentType__c  = paymentType,
            Amount__c       = amount,
            DueDate__c      = dueDate,
            PaymentMethod__c = paymentMethod,
            Description__c  = description,
            PaymentStatus__c = '未払い',
            FiscalYear__c   = dueDate.year()
        );

        if (!Schema.sObjectType.Payment__c.isCreateable()) {
            throw new AuraHandledException('支払いレコードの作成権限がありません。');
        }
        insert payment;

        EmailNotificationService.sendPaymentCreatedNotification(payment.Id);
        return payment.Id;
    }

    @AuraEnabled
    public static void recordPayment(Id paymentId, String transactionId, String paymentMethod) {
        Payment__c payment = new Payment__c(
            Id               = paymentId,
            PaymentStatus__c = '支払済み',
            PaymentDate__c   = Date.today(),
            TransactionId__c = transactionId,
            PaymentMethod__c = paymentMethod
        );
        update payment;

        EmailNotificationService.sendPaymentConfirmation(paymentId);
    }

    @AuraEnabled
    public static Id issueReceipt(Id paymentId) {
        Payment__c payment = [
            SELECT Id, ReceiptIssued__c, Member__c, Amount__c, PaymentDate__c, Description__c
            FROM Payment__c
            WHERE Id = :paymentId
            WITH SECURITY_ENFORCED
        ];

        if (payment.ReceiptIssued__c) {
            throw new AuraHandledException('この支払いには既に領収書が発行されています。');
        }

        payment.ReceiptIssued__c     = true;
        payment.ReceiptIssuedDate__c = Date.today();
        update payment;

        EmailNotificationService.sendReceiptNotification(paymentId);
        return paymentId;
    }

    @AuraEnabled
    public static void createAnnualFeePayments(Integer fiscalYear) {
        List<Member__c> activeMembers = [
            SELECT Id, MemberType__c, AnnualFee__c
            FROM Member__c
            WHERE MemberStatus__c IN ('正会員', '準会員')
            WITH SECURITY_ENFORCED
        ];

        List<Payment__c> payments = new List<Payment__c>();
        Date dueDate = Date.newInstance(fiscalYear, 3, 31);

        for (Member__c m : activeMembers) {
            Decimal fee = m.AnnualFee__c != null ? m.AnnualFee__c : getDefaultFee(m.MemberType__c);
            payments.add(new Payment__c(
                Member__c        = m.Id,
                PaymentType__c   = '年会費',
                Amount__c        = fee,
                DueDate__c       = dueDate,
                PaymentStatus__c = '未払い',
                FiscalYear__c    = fiscalYear,
                Description__c   = fiscalYear + '年度 年会費'
            ));
        }

        if (!payments.isEmpty()) {
            insert payments;
        }
    }

    private static Decimal getDefaultFee(String memberType) {
        Map<String, Decimal> feeMap = new Map<String, Decimal>{
            '個人会員' => 10000,
            '法人会員' => 50000,
            '学生会員' => 3000,
            '名誉会員' => 0
        };
        return feeMap.containsKey(memberType) ? feeMap.get(memberType) : 10000;
    }
}
