public with sharing class PaymentController {

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPaymentsByMember(Id memberId) {
        return [
            SELECT Id, Name, PaymentType__c, Amount__c, BaseAmount__c, PlatformFee__c,
                   PaymentMethodFee__c, AllowedPaymentMethods__c, SelectedMethodKey__c,
                   PaymentStatus__c, DueDate__c, PaymentDate__c, PaymentMethod__c,
                   TransactionId__c, FiscalYear__c, Description__c,
                   ReceiptIssued__c, ReceiptIssuedDate__c, ReceiptNumber__c
            FROM Payment__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY DueDate__c DESC
        ];
    }

    /**
     * 有効な決済手段の一覧を返す。
     * PortalConfiguration__c で設定されているプロバイダーの手段のみ有効とする。
     * 返り値はプロバイダー/手段キー/表示名/手数料種別/手数料値を含む Map のリスト。
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getActivePaymentMethods() {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();

        Set<String> enabledProviders = new Set<String>();
        if (String.isNotBlank(config.PayjpPublicKey__c) && String.isNotBlank(config.PayjpSecretKey__c)) {
            enabledProviders.add('Pay.jp');
        }
        if (String.isNotBlank(config.OmisePublicKey__c) && String.isNotBlank(config.OmiseSecretKey__c)) {
            enabledProviders.add('Omise');
        }
        if (String.isNotBlank(config.StripePublicKey__c) && String.isNotBlank(config.StripeSecretKey__c)) {
            enabledProviders.add('Stripe');
        }

        List<PaymentMethodConfig__mdt> allMethods = [
            SELECT MasterLabel, MethodKey__c, ProviderName__c, DisplayName__c,
                   IsEnabled__c, RequiresGateway__c, SortOrder__c
            FROM PaymentMethodConfig__mdt
            WHERE IsEnabled__c = true
            ORDER BY SortOrder__c ASC NULLS LAST
        ];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (PaymentMethodConfig__mdt m : allMethods) {
            if (m.RequiresGateway__c == true && !enabledProviders.contains(m.ProviderName__c)) {
                continue;
            }
            result.add(new Map<String, Object>{
                'methodKey'       => m.MethodKey__c,
                'providerName'    => m.ProviderName__c,
                'displayName'     => m.DisplayName__c,
                'requiresGateway' => m.RequiresGateway__c
            });
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getOverduePayments() {
        return [
            SELECT Id, Name, Member__c, Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.Email__c, PaymentType__c, Amount__c, BaseAmount__c,
                   PlatformFee__c, PaymentStatus__c, DueDate__c
            FROM Payment__c
            WHERE PaymentStatus__c = '未払い'
            AND DueDate__c < TODAY
            WITH SECURITY_ENFORCED
            ORDER BY DueDate__c ASC
            LIMIT 200
        ];
    }

    /**
     * 請求を作成する。PaymentFeeRuleController で全支払い共通＋カテゴリ別ルールを自動適用し
     * PlatformFee__c と FeeBreakdown__c に保存する。
     */
    @AuraEnabled
    public static Id createPayment(Id memberId, String paymentType, Decimal baseAmount,
                                    Date dueDate, String paymentMethod, String description) {
        PaymentFeeRuleController.FeeCalculationResult feeResult =
            PaymentFeeRuleController.calculateCreationFees(paymentType, baseAmount);
        Decimal platformFee      = feeResult.totalFeeAmount;
        String  feeBreakdownJson = feeResult.breakdownJson;

        Payment__c payment = new Payment__c(
            Member__c        = memberId,
            PaymentType__c   = paymentType,
            BaseAmount__c    = baseAmount,
            PlatformFee__c   = platformFee,
            FeeBreakdown__c  = feeBreakdownJson,
            Amount__c        = baseAmount + platformFee,
            DueDate__c       = dueDate,
            PaymentMethod__c = paymentMethod,
            Description__c   = description,
            PaymentStatus__c = '未払い',
            FiscalYear__c    = dueDate.year()
        );

        if (!Schema.sObjectType.Payment__c.isCreateable()) {
            throw new AuraHandledException('支払いレコードの作成権限がありません。');
        }
        insert payment;

        EmailNotificationService.sendPaymentCreatedNotification(payment.Id);

        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        if (config.EnableSlackNotification__c == true && String.isNotBlank(config.SupportSlackChannelId__c)) {
            notifySlackPaymentCreated(payment.Id);
        }

        return payment.Id;
    }

    /**
     * 請求作成 + 即時通知（管理者用請求発行フォームから呼び出す）。
     * allowedMethodKeys: セミコロン区切りの決済手段キー（例: "payjp_card;omise_convenience_store;bank_transfer"）
     * channels: 'email', 'slack', 'both' のいずれか
     */
    @AuraEnabled
    public static Id createPaymentWithNotification(Id memberId, String paymentType, Decimal baseAmount,
                                                    Date dueDate, String description,
                                                    String allowedMethodKeys, String channels) {
        PaymentFeeRuleController.FeeCalculationResult feeResult =
            PaymentFeeRuleController.calculateCreationFees(paymentType, baseAmount);
        Decimal platformFee      = feeResult.totalFeeAmount;
        String  feeBreakdownJson = feeResult.breakdownJson;

        Payment__c payment = new Payment__c(
            Member__c                = memberId,
            PaymentType__c           = paymentType,
            BaseAmount__c            = baseAmount,
            PlatformFee__c           = platformFee,
            FeeBreakdown__c          = feeBreakdownJson,
            Amount__c                = baseAmount + platformFee,
            DueDate__c               = dueDate,
            Description__c           = description,
            PaymentStatus__c         = '未払い',
            FiscalYear__c            = dueDate.year(),
            AllowedPaymentMethods__c = allowedMethodKeys
        );

        if (!Schema.sObjectType.Payment__c.isCreateable()) {
            throw new AuraHandledException('支払いレコードの作成権限がありません。');
        }
        insert payment;

        EmailNotificationService.sendPaymentCreatedNotification(payment.Id);

        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        String ch = (channels != null) ? channels.toLowerCase() : 'email';
        if ((ch == 'slack' || ch == 'both') && String.isNotBlank(config.SupportSlackChannelId__c)) {
            notifySlackPaymentCreated(payment.Id);
        }
        return payment.Id;
    }

    @AuraEnabled
    public static void recordPayment(Id paymentId, String transactionId, String paymentMethod) {
        Payment__c prev = [
            SELECT Id, PaymentStatus__c, ReviewRequired__c, Amount__c,
                   PaymentType__c, Member__r.LastName__c, Member__r.FirstName__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        String oldStatus = prev.PaymentStatus__c;

        update new Payment__c(
            Id               = paymentId,
            PaymentStatus__c = '支払済み',
            PaymentDate__c   = Date.today(),
            TransactionId__c = transactionId,
            PaymentMethod__c = paymentMethod
        );

        // ステータス履歴に記録
        PaymentStatusHistoryService.record(paymentId, oldStatus, '支払済み', '会員', '決済完了');

        // 即時メール通知
        EmailNotificationService.sendPaymentConfirmation(paymentId);

        // 即時Slack通知
        PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
        if (cfg.EnableSlackNotification__c == true && String.isNotBlank(cfg.SupportSlackChannelId__c)) {
            notifySlackPaymentCompleted(paymentId);
        }

        // 審査が必要な場合は審査ワークフローを開始
        if (prev.ReviewRequired__c == true) {
            PaymentReviewService.initiateReview(paymentId, null);
        }
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
            Decimal base = m.AnnualFee__c != null ? m.AnnualFee__c : getDefaultFee(m.MemberType__c);
            PaymentFeeRuleController.FeeCalculationResult feeResult =
                PaymentFeeRuleController.calculateCreationFees('年会費', base);
            Decimal fee = feeResult.totalFeeAmount;
            payments.add(new Payment__c(
                Member__c        = m.Id,
                PaymentType__c   = '年会費',
                BaseAmount__c    = base,
                PlatformFee__c   = fee,
                FeeBreakdown__c  = feeResult.breakdownJson,
                Amount__c        = base + fee,
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

    /**
     * 会員名・メールで検索（管理者用請求発行フォームのオートコンプリート用）。
     */
    @AuraEnabled(cacheable=true)
    public static List<Member__c> searchMembers(String keyword) {
        if (String.isBlank(keyword)) return new List<Member__c>();
        String q = '%' + keyword.trim() + '%';
        return [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c, MemberType__c
            FROM Member__c
            WHERE MemberStatus__c IN ('正会員', '準会員')
            AND (LastName__c LIKE :q OR FirstName__c LIKE :q OR Email__c LIKE :q OR Name LIKE :q)
            WITH SECURITY_ENFORCED
            ORDER BY LastName__c ASC
            LIMIT 20
        ];
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

    // ----------------------------------------------------------------
    // 支払いステータス履歴
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<PaymentStatusHistory__c> getPaymentStatusHistory(Id paymentId) {
        return PaymentStatusHistoryService.getHistory(paymentId);
    }

    // ----------------------------------------------------------------
    // 定期支払いプラン（委譲）
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<RecurringPaymentPlan__c> getRecurringPlans(Id memberId) {
        return RecurringPaymentScheduler.getRecurringPlans(memberId);
    }

    @AuraEnabled
    public static Id createRecurringPlan(Map<String, Object> planData) {
        return RecurringPaymentScheduler.createRecurringPlan(planData);
    }

    @AuraEnabled
    public static void toggleRecurringPlan(Id planId, Boolean active) {
        RecurringPaymentScheduler.toggleRecurringPlan(planId, active);
    }

    @AuraEnabled
    public static void deleteRecurringPlan(Id planId) {
        RecurringPaymentScheduler.deleteRecurringPlan(planId);
    }

    // ----------------------------------------------------------------
    // Private
    // ----------------------------------------------------------------

    @Future(callout=true)
    private static void notifySlackPaymentCreated(Id paymentId) {
        try {
            Payment__c p = [
                SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                       PaymentType__c, Amount__c, DueDate__c
                FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
            ];
            String msg = ':bell: 【請求発行】' + p.Member__r.LastName__c + ' ' + p.Member__r.FirstName__c
                + ' 様に ' + p.PaymentType__c + ' の請求を発行しました。'
                + ' 金額: ¥' + String.valueOf(p.Amount__c.longValue())
                + ' 期限: ' + p.DueDate__c.format();
            PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
            SlackIntegrationService.sendMessage(cfg.SupportSlackChannelId__c, msg);
        } catch (Exception e) {
            System.debug('Slack notify failed: ' + e.getMessage());
        }
    }

    @Future(callout=true)
    private static void notifySlackPaymentCompleted(Id paymentId) {
        try {
            Payment__c p = [
                SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                       PaymentType__c, Amount__c, PaymentDate__c, PaymentMethod__c
                FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
            ];
            String msg = ':white_check_mark: 【入金確認】' + p.Member__r.LastName__c + ' '
                + p.Member__r.FirstName__c
                + ' 様の ' + p.PaymentType__c + '（¥' + p.Amount__c.longValue() + '）の入金を確認しました。'
                + ' 支払方法: ' + p.PaymentMethod__c;
            PortalConfiguration__c cfg = PortalConfiguration__c.getInstance();
            SlackIntegrationService.sendMessage(cfg.SupportSlackChannelId__c, msg);
        } catch (Exception e) {
            System.debug('Slack payment completed notify failed: ' + e.getMessage());
        }
    }
}
