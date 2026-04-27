/**
 * 手数料ルール（PaymentFeeRule__c）の CRUD と動的手数料計算を担当するコントローラー。
 *
 * 適用種別:
 *   全支払い共通  … すべての支払いに自動加算
 *   カテゴリ別    … TargetCategory__c に一致する支払種別のみ加算
 *   決済手段別    … TargetMethodKey__c に一致する決済手段キーのみ加算
 *
 * 計算タイミング:
 *   作成時  … 「全支払い共通」「カテゴリ別」ルールを適用 → PlatformFee__c に保存
 *   支払時  … 「決済手段別」ルールを追加で適用 → PaymentMethodFee__c に保存
 */
public with sharing class PaymentFeeRuleController {

    // ----------------------------------------------------------------
    // 内部モデル
    // ----------------------------------------------------------------

    public class FeeLineItem {
        @AuraEnabled public Id     ruleId;
        @AuraEnabled public String label;
        @AuraEnabled public String feeType;   // '料率（%）' or '固定額（円）'
        @AuraEnabled public Decimal feeValue; // raw value (% or ¥)
        @AuraEnabled public Decimal feeAmount;// calculated ¥ amount
        @AuraEnabled public String ruleType;  // '決済手段別' | 'カテゴリ別' | '全支払い共通'
    }

    public class FeeCalculationResult {
        @AuraEnabled public Decimal totalFeeAmount;
        @AuraEnabled public List<FeeLineItem> breakdown;
        @AuraEnabled public String breakdownJson;
    }

    // ----------------------------------------------------------------
    // CRUD
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<PaymentFeeRule__c> getAllRules() {
        return [
            SELECT Id, Name, RuleName__c, RuleType__c, TargetMethodKey__c,
                   TargetCategory__c, FeeType__c, FeeValue__c, FeeLabel__c,
                   IsEnabled__c, SortOrder__c
            FROM PaymentFeeRule__c
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder__c ASC NULLS LAST, CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static Id saveRule(Map<String, Object> ruleData) {
        PaymentFeeRule__c rule;

        String ruleId = (String) ruleData.get('id');
        if (String.isNotBlank(ruleId)) {
            rule = new PaymentFeeRule__c(Id = (Id) ruleId);
        } else {
            if (!Schema.sObjectType.PaymentFeeRule__c.isCreateable()) {
                throw new AuraHandledException('手数料ルールの作成権限がありません。');
            }
            rule = new PaymentFeeRule__c();
        }

        if (ruleData.containsKey('ruleName'))         rule.RuleName__c         = (String)  ruleData.get('ruleName');
        if (ruleData.containsKey('ruleType'))          rule.RuleType__c         = (String)  ruleData.get('ruleType');
        if (ruleData.containsKey('targetMethodKey'))   rule.TargetMethodKey__c  = (String)  ruleData.get('targetMethodKey');
        if (ruleData.containsKey('targetCategory'))    rule.TargetCategory__c   = (String)  ruleData.get('targetCategory');
        if (ruleData.containsKey('feeType'))           rule.FeeType__c          = (String)  ruleData.get('feeType');
        if (ruleData.containsKey('feeValue'))          rule.FeeValue__c         = Decimal.valueOf(String.valueOf(ruleData.get('feeValue')));
        if (ruleData.containsKey('feeLabel'))          rule.FeeLabel__c         = (String)  ruleData.get('feeLabel');
        if (ruleData.containsKey('isEnabled'))         rule.IsEnabled__c        = (Boolean) ruleData.get('isEnabled');
        if (ruleData.containsKey('sortOrder') && ruleData.get('sortOrder') != null)
            rule.SortOrder__c = Decimal.valueOf(String.valueOf(ruleData.get('sortOrder')));

        upsert rule;
        return rule.Id;
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        if (!Schema.sObjectType.PaymentFeeRule__c.isDeletable()) {
            throw new AuraHandledException('手数料ルールの削除権限がありません。');
        }
        delete new PaymentFeeRule__c(Id = ruleId);
    }

    @AuraEnabled
    public static void toggleRule(Id ruleId, Boolean enabled) {
        update new PaymentFeeRule__c(Id = ruleId, IsEnabled__c = enabled);
    }

    // ----------------------------------------------------------------
    // 手数料計算
    // ----------------------------------------------------------------

    /**
     * 指定した基本金額に対して、全ての該当ルールの手数料を計算して返す。
     *
     * @param methodKey       決済手段キー（例: 'payjp_card'）。null なら決済手段別ルールは除外。
     * @param paymentCategory 支払種別（例: '年会費'）。null なら全支払い共通のみ適用。
     * @param baseAmount      基本金額（円）。
     */
    @AuraEnabled(cacheable=true)
    public static FeeCalculationResult calculateFees(
        String methodKey, String paymentCategory, Decimal baseAmount) {

        List<PaymentFeeRule__c> rules = queryApplicableRules(methodKey, paymentCategory);
        return computeResult(rules, baseAmount);
    }

    /**
     * 作成時（決済手段未確定）に適用するルールのみ計算する。
     * 対象: 全支払い共通 + カテゴリ別
     */
    @AuraEnabled(cacheable=true)
    public static FeeCalculationResult calculateCreationFees(
        String paymentCategory, Decimal baseAmount) {

        List<PaymentFeeRule__c> rules = [
            SELECT Id, RuleName__c, RuleType__c, FeeType__c, FeeValue__c, FeeLabel__c
            FROM PaymentFeeRule__c
            WHERE IsEnabled__c = true
            AND (
                RuleType__c = '全支払い共通'
                OR (RuleType__c = 'カテゴリ別' AND TargetCategory__c INCLUDES (:paymentCategory))
            )
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder__c ASC NULLS LAST
        ];
        return computeResult(rules, baseAmount);
    }

    /**
     * 決済手段別ルールのみ計算（支払い時に追加で適用）。
     */
    @AuraEnabled(cacheable=true)
    public static FeeCalculationResult calculateMethodFees(
        String methodKey, Decimal baseAmount) {

        if (String.isBlank(methodKey)) {
            FeeCalculationResult empty = new FeeCalculationResult();
            empty.totalFeeAmount = 0;
            empty.breakdown      = new List<FeeLineItem>();
            empty.breakdownJson  = '[]';
            return empty;
        }

        List<PaymentFeeRule__c> rules = [
            SELECT Id, RuleName__c, RuleType__c, FeeType__c, FeeValue__c, FeeLabel__c
            FROM PaymentFeeRule__c
            WHERE IsEnabled__c = true
            AND RuleType__c = '決済手段別'
            AND TargetMethodKey__c LIKE :('%' + methodKey + '%')
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder__c ASC NULLS LAST
        ];
        // LIKE 検索は部分一致なので完全一致をフィルタリング
        List<PaymentFeeRule__c> exact = new List<PaymentFeeRule__c>();
        for (PaymentFeeRule__c r : rules) {
            Set<String> keys = new Set<String>(r.TargetMethodKey__c.split(';'));
            if (keys.contains(methodKey.trim())) exact.add(r);
        }
        return computeResult(exact, baseAmount);
    }

    // ----------------------------------------------------------------
    // Private helpers
    // ----------------------------------------------------------------

    private static List<PaymentFeeRule__c> queryApplicableRules(
        String methodKey, String paymentCategory) {

        List<PaymentFeeRule__c> allEnabled = [
            SELECT Id, RuleName__c, RuleType__c, TargetMethodKey__c,
                   TargetCategory__c, FeeType__c, FeeValue__c, FeeLabel__c
            FROM PaymentFeeRule__c
            WHERE IsEnabled__c = true
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder__c ASC NULLS LAST
        ];

        List<PaymentFeeRule__c> result = new List<PaymentFeeRule__c>();
        for (PaymentFeeRule__c r : allEnabled) {
            if (r.RuleType__c == '全支払い共通') {
                result.add(r);
            } else if (r.RuleType__c == 'カテゴリ別' && String.isNotBlank(paymentCategory)) {
                Set<String> cats = new Set<String>(r.TargetCategory__c != null
                    ? r.TargetCategory__c.split(';') : new List<String>());
                if (cats.contains(paymentCategory.trim())) result.add(r);
            } else if (r.RuleType__c == '決済手段別' && String.isNotBlank(methodKey)) {
                Set<String> keys = new Set<String>(r.TargetMethodKey__c != null
                    ? r.TargetMethodKey__c.split(';') : new List<String>());
                if (keys.contains(methodKey.trim())) result.add(r);
            }
        }
        return result;
    }

    private static FeeCalculationResult computeResult(
        List<PaymentFeeRule__c> rules, Decimal baseAmount) {

        FeeCalculationResult res = new FeeCalculationResult();
        res.breakdown      = new List<FeeLineItem>();
        res.totalFeeAmount = 0;

        for (PaymentFeeRule__c r : rules) {
            FeeLineItem item = new FeeLineItem();
            item.ruleId   = r.Id;
            item.label    = String.isNotBlank(r.FeeLabel__c) ? r.FeeLabel__c : r.RuleName__c;
            item.feeType  = r.FeeType__c;
            item.feeValue = r.FeeValue__c ?? 0;
            item.ruleType = r.RuleType__c;

            if (r.FeeType__c == '料率（%）') {
                item.feeAmount = (baseAmount * item.feeValue / 100)
                    .setScale(0, System.RoundingMode.HALF_UP);
            } else {
                item.feeAmount = item.feeValue.setScale(0, System.RoundingMode.HALF_UP);
            }

            res.breakdown.add(item);
            res.totalFeeAmount += item.feeAmount;
        }

        // JSON シリアライズ（Payment__c.FeeBreakdown__c 保存用）
        List<Map<String, Object>> jsonList = new List<Map<String, Object>>();
        for (FeeLineItem item : res.breakdown) {
            jsonList.add(new Map<String, Object>{
                'label'     => item.label,
                'feeType'   => item.feeType,
                'feeValue'  => item.feeValue,
                'feeAmount' => item.feeAmount,
                'ruleType'  => item.ruleType
            });
        }
        res.breakdownJson = JSON.serialize(jsonList);

        return res;
    }
}
