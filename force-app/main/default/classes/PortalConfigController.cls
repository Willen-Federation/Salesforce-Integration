public with sharing class PortalConfigController {

    public class ConfigData {
        @AuraEnabled public String organizationName;
        @AuraEnabled public String fromEmailAddress;
        @AuraEnabled public String portalBaseUrl;
        @AuraEnabled public String supportSlackChannelId;
        @AuraEnabled public String oktaDomain;
        @AuraEnabled public String payjpMode;
        @AuraEnabled public String omiseMode;
        @AuraEnabled public String stripeMode;
        @AuraEnabled public String fincodeMode;
        @AuraEnabled public String fincodeShopId;
        @AuraEnabled public String directDebitFormUrl;
        @AuraEnabled public String defaultPaymentProvider;
        @AuraEnabled public String gmoAozoraMode;
        @AuraEnabled public String gmoAozoraClientId;
        @AuraEnabled public String  gmoAozoraRaId;
        @AuraEnabled public Boolean gmoAozoraAutoTransferEnabled;
        @AuraEnabled public String  gmoAozoraAutoTransferAccountId;
        @AuraEnabled public String  gmoAozoraAutoTransferBankCode;
        @AuraEnabled public String  gmoAozoraAutoTransferBranchCode;
        @AuraEnabled public String  gmoAozoraAutoTransferAccountType;
        @AuraEnabled public String  gmoAozoraAutoTransferAccountNumber;
        @AuraEnabled public String  gmoAozoraAutoTransferBeneficiaryName;
        @AuraEnabled public Boolean enableDonation;
        @AuraEnabled public Boolean enableSlackNotification;
        @AuraEnabled public Decimal annualFeeIndividual;
        @AuraEnabled public Decimal annualFeeCorporate;
        @AuraEnabled public Decimal annualFeeStudent;
        @AuraEnabled public Decimal annualFeeSupporting;
    }

    @AuraEnabled(cacheable=true)
    public static ConfigData getPortalConfig() {
        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        ConfigData data = new ConfigData();
        data.organizationName        = config.OrganizationName__c;
        data.fromEmailAddress        = config.FromEmailAddress__c;
        data.portalBaseUrl           = config.PortalBaseUrl__c;
        data.supportSlackChannelId   = config.SupportSlackChannelId__c;
        data.oktaDomain              = config.OktaDomain__c;
        data.payjpMode               = config.PayjpMode__c;
        data.omiseMode               = config.OmiseMode__c;
        data.stripeMode              = config.StripeMode__c;
        data.fincodeMode             = config.FincodeMode__c;
        data.fincodeShopId           = config.FincodeShopId__c;
        data.directDebitFormUrl      = config.DirectDebitFormUrl__c;
        data.defaultPaymentProvider  = config.DefaultPaymentProvider__c;
        data.gmoAozoraMode           = config.GmoAozoraMode__c;
        data.gmoAozoraClientId       = config.GmoAozoraClientId__c;
        data.gmoAozoraRaId                        = config.GmoAozoraRaId__c;
        data.gmoAozoraAutoTransferEnabled         = config.GmoAozoraAutoTransferEnabled__c;
        data.gmoAozoraAutoTransferAccountId       = config.GmoAozoraAutoTransferAccountId__c;
        data.gmoAozoraAutoTransferBankCode        = config.GmoAozoraAutoTransferBankCode__c;
        data.gmoAozoraAutoTransferBranchCode      = config.GmoAozoraAutoTransferBranchCode__c;
        data.gmoAozoraAutoTransferAccountType     = config.GmoAozoraAutoTransferAccountType__c;
        data.gmoAozoraAutoTransferAccountNumber   = config.GmoAozoraAutoTransferAccountNumber__c;
        data.gmoAozoraAutoTransferBeneficiaryName = config.GmoAozoraAutoTransferBeneficiaryName__c;
        data.enableDonation                       = config.EnableDonation__c;
        data.enableSlackNotification = config.EnableSlackNotification__c;
        data.annualFeeIndividual     = config.AnnualFeeIndividual__c;
        data.annualFeeCorporate      = config.AnnualFeeCorporate__c;
        data.annualFeeStudent        = config.AnnualFeeStudent__c;
        data.annualFeeSupporting     = config.AnnualFeeSupporting__c;
        return data;
    }

    @AuraEnabled
    public static void savePortalConfig(Map<String, Object> settings) {
        if (!Schema.sObjectType.PortalConfiguration__c.isUpdateable()) {
            throw new AuraHandledException('ポータル設定の更新権限がありません。');
        }

        PortalConfiguration__c config = PortalConfiguration__c.getInstance();
        if (config.Id == null) {
            config = new PortalConfiguration__c(SetupOwnerId = UserInfo.getOrganizationId());
        }

        if (settings.containsKey('organizationName'))      config.OrganizationName__c        = (String)  settings.get('organizationName');
        if (settings.containsKey('fromEmailAddress'))      config.FromEmailAddress__c         = (String)  settings.get('fromEmailAddress');
        if (settings.containsKey('portalBaseUrl'))         config.PortalBaseUrl__c            = (String)  settings.get('portalBaseUrl');
        if (settings.containsKey('supportSlackChannelId')) config.SupportSlackChannelId__c    = (String)  settings.get('supportSlackChannelId');
        if (settings.containsKey('slackBotToken'))         config.SlackBotToken__c            = (String)  settings.get('slackBotToken');
        if (settings.containsKey('oktaDomain'))            config.OktaDomain__c               = (String)  settings.get('oktaDomain');
        if (settings.containsKey('oktaApiToken'))          config.OktaApiToken__c             = (String)  settings.get('oktaApiToken');
        if (settings.containsKey('payjpPublicKey'))        config.PayjpPublicKey__c           = (String)  settings.get('payjpPublicKey');
        if (settings.containsKey('payjpSecretKey'))        config.PayjpSecretKey__c           = (String)  settings.get('payjpSecretKey');
        if (settings.containsKey('payjpMode'))             config.PayjpMode__c                = (String)  settings.get('payjpMode');
        if (settings.containsKey('omisePublicKey'))        config.OmisePublicKey__c           = (String)  settings.get('omisePublicKey');
        if (settings.containsKey('omiseSecretKey'))        config.OmiseSecretKey__c           = (String)  settings.get('omiseSecretKey');
        if (settings.containsKey('omiseMode'))             config.OmiseMode__c                = (String)  settings.get('omiseMode');
        if (settings.containsKey('stripePublicKey'))       config.StripePublicKey__c          = (String)  settings.get('stripePublicKey');
        if (settings.containsKey('stripeSecretKey'))       config.StripeSecretKey__c          = (String)  settings.get('stripeSecretKey');
        if (settings.containsKey('stripeMode'))            config.StripeMode__c               = (String)  settings.get('stripeMode');
        if (settings.containsKey('fincodeShopId'))         config.FincodeShopId__c            = (String)  settings.get('fincodeShopId');
        if (settings.containsKey('fincodePublicKey'))      config.FincodePublicKey__c         = (String)  settings.get('fincodePublicKey');
        if (settings.containsKey('fincodeSecretKey'))      config.FincodeSecretKey__c         = (String)  settings.get('fincodeSecretKey');
        if (settings.containsKey('fincodeMode'))           config.FincodeMode__c              = (String)  settings.get('fincodeMode');
        if (settings.containsKey('directDebitFormUrl'))      config.DirectDebitFormUrl__c         = (String)  settings.get('directDebitFormUrl');
        if (settings.containsKey('defaultPaymentProvider')) config.DefaultPaymentProvider__c     = (String)  settings.get('defaultPaymentProvider');
        if (settings.containsKey('gmoAozoraMode'))          config.GmoAozoraMode__c              = (String)  settings.get('gmoAozoraMode');
        if (settings.containsKey('gmoAozoraClientId'))      config.GmoAozoraClientId__c          = (String)  settings.get('gmoAozoraClientId');
        if (settings.containsKey('gmoAozoraClientSecret'))  config.GmoAozoraClientSecret__c      = (String)  settings.get('gmoAozoraClientSecret');
        if (settings.containsKey('gmoAozoraWebhookSecret')) config.GmoAozoraWebhookSecret__c     = (String)  settings.get('gmoAozoraWebhookSecret');
        if (settings.containsKey('gmoAozoraRefreshToken'))              config.GmoAozoraRefreshToken__c              = (String)  settings.get('gmoAozoraRefreshToken');
        if (settings.containsKey('gmoAozoraRaId'))                     config.GmoAozoraRaId__c                      = (String)  settings.get('gmoAozoraRaId');
        if (settings.containsKey('gmoAozoraAutoTransferEnabled'))       config.GmoAozoraAutoTransferEnabled__c       = (Boolean) settings.get('gmoAozoraAutoTransferEnabled');
        if (settings.containsKey('gmoAozoraAutoTransferAccountId'))     config.GmoAozoraAutoTransferAccountId__c     = (String)  settings.get('gmoAozoraAutoTransferAccountId');
        if (settings.containsKey('gmoAozoraAutoTransferBankCode'))      config.GmoAozoraAutoTransferBankCode__c      = (String)  settings.get('gmoAozoraAutoTransferBankCode');
        if (settings.containsKey('gmoAozoraAutoTransferBranchCode'))    config.GmoAozoraAutoTransferBranchCode__c    = (String)  settings.get('gmoAozoraAutoTransferBranchCode');
        if (settings.containsKey('gmoAozoraAutoTransferAccountType'))   config.GmoAozoraAutoTransferAccountType__c   = (String)  settings.get('gmoAozoraAutoTransferAccountType');
        if (settings.containsKey('gmoAozoraAutoTransferAccountNumber')) config.GmoAozoraAutoTransferAccountNumber__c = (String)  settings.get('gmoAozoraAutoTransferAccountNumber');
        if (settings.containsKey('gmoAozoraAutoTransferBeneficiaryName')) config.GmoAozoraAutoTransferBeneficiaryName__c = (String) settings.get('gmoAozoraAutoTransferBeneficiaryName');
        if (settings.containsKey('enableDonation'))        config.EnableDonation__c           = (Boolean) settings.get('enableDonation');
        if (settings.containsKey('enableSlack'))           config.EnableSlackNotification__c  = (Boolean) settings.get('enableSlack');
        if (settings.containsKey('annualFeeIndividual'))   config.AnnualFeeIndividual__c      = Decimal.valueOf(String.valueOf(settings.get('annualFeeIndividual')));
        if (settings.containsKey('annualFeeCorporate'))    config.AnnualFeeCorporate__c       = Decimal.valueOf(String.valueOf(settings.get('annualFeeCorporate')));
        if (settings.containsKey('annualFeeStudent'))      config.AnnualFeeStudent__c         = Decimal.valueOf(String.valueOf(settings.get('annualFeeStudent')));
        if (settings.containsKey('annualFeeSupporting'))   config.AnnualFeeSupporting__c      = Decimal.valueOf(String.valueOf(settings.get('annualFeeSupporting')));

        upsert config;
    }
}
