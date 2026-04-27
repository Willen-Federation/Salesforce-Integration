public with sharing class GmoAozoraRaConfigController {

    @AuraEnabled(cacheable=true)
    public static List<GmoAozoraRaConfig__c> getRaConfigs() {
        return [
            SELECT Id, Name, PaymentCategory__c, RaId__c, IsActive__c, Description__c
            FROM GmoAozoraRaConfig__c
            ORDER BY PaymentCategory__c ASC
        ];
    }

    @AuraEnabled
    public static void saveRaConfig(Map<String, Object> record) {
        if (!Schema.sObjectType.GmoAozoraRaConfig__c.isCreateable()
            && !Schema.sObjectType.GmoAozoraRaConfig__c.isUpdateable()) {
            throw new AuraHandledException('入金先設定の保存権限がありません。');
        }

        GmoAozoraRaConfig__c cfg = new GmoAozoraRaConfig__c();

        if (record.containsKey('id') && String.isNotBlank((String) record.get('id'))) {
            cfg.Id = (Id) record.get('id');
        }
        cfg.Name                = (String)  record.get('name');
        cfg.PaymentCategory__c  = (String)  record.get('paymentCategory');
        cfg.RaId__c             = (String)  record.get('raId');
        cfg.IsActive__c         = record.get('isActive') != null ? (Boolean) record.get('isActive') : true;
        cfg.Description__c      = (String)  record.get('description');

        upsert cfg;
    }

    @AuraEnabled
    public static void deleteRaConfig(Id configId) {
        if (!Schema.sObjectType.GmoAozoraRaConfig__c.isDeletable()) {
            throw new AuraHandledException('入金先設定の削除権限がありません。');
        }
        delete new GmoAozoraRaConfig__c(Id = configId);
    }
}
