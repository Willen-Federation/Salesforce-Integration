/**
 * 定期支払いプランに基づいて Payment__c を自動生成するスケジューラー。
 *
 * 毎日実行することを想定。NextDueDate__c <= TODAY + DaysBeforeDue__c のプランを対象とする。
 *
 * スケジュール登録例（Setup > Apex Jobs > Schedule Apex）:
 *   System.schedule('定期支払い生成', '0 0 1 * * ?', new RecurringPaymentScheduler());
 */
global with sharing class RecurringPaymentScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        generateDuePayments();
    }

    /**
     * LWC / テストから手動実行も可能。
     */
    @AuraEnabled
    public static Integer generateDuePayments() {
        Date today = Date.today();

        List<RecurringPaymentPlan__c> plans = [
            SELECT Id, Member__c, Member__r.Email__c,
                   Member__r.LastName__c, Member__r.FirstName__c,
                   PlanName__c, PaymentType__c, BaseAmount__c,
                   Frequency__c, NextDueDate__c, DaysBeforeDue__c,
                   AllowedPaymentMethods__c, Description__c,
                   TotalGenerated__c, EndDate__c
            FROM RecurringPaymentPlan__c
            WHERE IsActive__c = true
            AND NextDueDate__c != null
            AND (EndDate__c = null OR EndDate__c >= :today)
            WITH SECURITY_ENFORCED
        ];

        List<Payment__c>               toInsert   = new List<Payment__c>();
        List<RecurringPaymentPlan__c>  toUpdate   = new List<RecurringPaymentPlan__c>();
        List<Id>                       planIds    = new List<Id>();

        for (RecurringPaymentPlan__c plan : plans) {
            Integer daysBefore = plan.DaysBeforeDue__c != null
                ? Integer.valueOf(plan.DaysBeforeDue__c) : 7;
            if (plan.NextDueDate__c > today.addDays(daysBefore)) continue;

            PaymentFeeRuleController.FeeCalculationResult feeResult =
                PaymentFeeRuleController.calculateCreationFees(plan.PaymentType__c, plan.BaseAmount__c);

            String desc = String.isNotBlank(plan.Description__c)
                ? plan.Description__c
                : plan.PlanName__c + '（' + plan.NextDueDate__c.year() + '年度）';

            toInsert.add(new Payment__c(
                Member__c                = plan.Member__c,
                PaymentType__c           = plan.PaymentType__c,
                BaseAmount__c            = plan.BaseAmount__c,
                PlatformFee__c           = feeResult.totalFeeAmount,
                FeeBreakdown__c          = feeResult.breakdownJson,
                Amount__c                = plan.BaseAmount__c + feeResult.totalFeeAmount,
                DueDate__c               = plan.NextDueDate__c,
                PaymentStatus__c         = '未払い',
                FiscalYear__c            = plan.NextDueDate__c.year(),
                Description__c           = desc,
                AllowedPaymentMethods__c = plan.AllowedPaymentMethods__c,
                RecurringPlan__c         = plan.Id
            ));

            toUpdate.add(new RecurringPaymentPlan__c(
                Id                  = plan.Id,
                NextDueDate__c      = calcNextDueDate(plan.NextDueDate__c, plan.Frequency__c),
                LastGeneratedDate__c = today,
                TotalGenerated__c   = (plan.TotalGenerated__c ?? 0) + 1
            ));
            planIds.add(plan.Id);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;

            // メール通知（各支払いに対して）
            for (Payment__c p : toInsert) {
                EmailNotificationService.sendRecurringPaymentCreatedNotification(p.Id);
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        return toInsert.size();
    }

    // ----------------------------------------------------------------
    // プラン CRUD（管理者 LWC から呼び出す）
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<RecurringPaymentPlan__c> getRecurringPlans(Id memberId) {
        return [
            SELECT Id, Name, PlanName__c, PaymentType__c, BaseAmount__c,
                   Frequency__c, StartDate__c, EndDate__c, NextDueDate__c,
                   DaysBeforeDue__c, AllowedPaymentMethods__c, IsActive__c,
                   Description__c, LastGeneratedDate__c, TotalGenerated__c
            FROM RecurringPaymentPlan__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY StartDate__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<RecurringPaymentPlan__c> getAllRecurringPlans() {
        return [
            SELECT Id, Name, PlanName__c, Member__c,
                   Member__r.LastName__c, Member__r.FirstName__c, Member__r.Email__c,
                   PaymentType__c, BaseAmount__c, Frequency__c,
                   StartDate__c, EndDate__c, NextDueDate__c, IsActive__c,
                   TotalGenerated__c, LastGeneratedDate__c
            FROM RecurringPaymentPlan__c
            WITH SECURITY_ENFORCED
            ORDER BY IsActive__c DESC, NextDueDate__c ASC NULLS LAST
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Id createRecurringPlan(Map<String, Object> planData) {
        if (!Schema.sObjectType.RecurringPaymentPlan__c.isCreateable()) {
            throw new AuraHandledException('定期支払いプランの作成権限がありません。');
        }

        Date startDate = Date.valueOf((String) planData.get('startDate'));

        RecurringPaymentPlan__c plan = new RecurringPaymentPlan__c(
            Member__c              = (Id)      planData.get('memberId'),
            PlanName__c            = (String)  planData.get('planName'),
            PaymentType__c         = (String)  planData.get('paymentType'),
            BaseAmount__c          = Decimal.valueOf(String.valueOf(planData.get('baseAmount'))),
            Frequency__c           = (String)  planData.get('frequency'),
            StartDate__c           = startDate,
            NextDueDate__c         = startDate,
            DaysBeforeDue__c       = planData.containsKey('daysBeforeDue')
                                        ? Decimal.valueOf(String.valueOf(planData.get('daysBeforeDue'))) : 7,
            AllowedPaymentMethods__c = (String) planData.get('allowedMethodKeys'),
            Description__c         = (String)  planData.get('description'),
            IsActive__c            = true,
            TotalGenerated__c      = 0
        );
        if (planData.containsKey('endDate') && planData.get('endDate') != null
            && String.isNotBlank((String) planData.get('endDate'))) {
            plan.EndDate__c = Date.valueOf((String) planData.get('endDate'));
        }
        insert plan;
        return plan.Id;
    }

    @AuraEnabled
    public static void toggleRecurringPlan(Id planId, Boolean active) {
        update new RecurringPaymentPlan__c(Id = planId, IsActive__c = active);
    }

    @AuraEnabled
    public static void deleteRecurringPlan(Id planId) {
        if (!Schema.sObjectType.RecurringPaymentPlan__c.isDeletable()) {
            throw new AuraHandledException('定期支払いプランの削除権限がありません。');
        }
        delete new RecurringPaymentPlan__c(Id = planId);
    }

    // ----------------------------------------------------------------
    // Private helper
    // ----------------------------------------------------------------

    private static Date calcNextDueDate(Date current, String frequency) {
        if (frequency == '月次')   return current.addMonths(1);
        if (frequency == '四半期') return current.addMonths(3);
        if (frequency == '半期')   return current.addMonths(6);
        return current.addYears(1); // 年次（デフォルト）
    }
}
