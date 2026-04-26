public with sharing class FormBuilderController {

    @AuraEnabled(cacheable=true)
    public static FormTemplate__c getTemplate(Id templateId) {
        return [
            SELECT Id, Name, FormType__c, Description__c, IsActive__c,
                   ResponseDeadline__c, RequiresAuth__c, SaveToRecord__c,
                   SendConfirmationEmail__c, ConfirmationEmailTemplate__c,
                   AssignedToUser__c, AssignedToUser__r.Name, TotalResponses__c,
                   GeneralMeeting__c, GeneralMeeting__r.Name
            FROM FormTemplate__c
            WHERE Id = :templateId
            WITH SECURITY_ENFORCED
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<FormField__c> getFields(Id templateId) {
        return [
            SELECT Id, Name, FieldType__c, IsRequired__c, SortOrder__c,
                   PicklistOptions__c, PlaceholderText__c, HelpText__c, ApiKey__c
            FROM FormField__c
            WHERE FormTemplate__c = :templateId
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder__c ASC
        ];
    }

    @AuraEnabled
    public static Id createTemplate(Map<String, Object> templateData) {
        if (!Schema.sObjectType.FormTemplate__c.isCreateable()) {
            throw new AuraHandledException('フォームテンプレートの作成権限がありません。');
        }
        FormTemplate__c template = new FormTemplate__c(
            Name                     = (String) templateData.get('name'),
            FormType__c              = (String) templateData.get('formType'),
            Description__c           = (String) templateData.get('description'),
            IsActive__c              = templateData.get('isActive') != null ? (Boolean) templateData.get('isActive') : true,
            RequiresAuth__c          = templateData.get('requiresAuth') != null ? (Boolean) templateData.get('requiresAuth') : true,
            SaveToRecord__c          = templateData.get('saveToRecord') != null ? (Boolean) templateData.get('saveToRecord') : true,
            SendConfirmationEmail__c = templateData.get('sendConfirmation') != null ? (Boolean) templateData.get('sendConfirmation') : true
        );
        if (templateData.get('meetingId') != null)          template.GeneralMeeting__c           = (Id)      templateData.get('meetingId');
        if (templateData.get('responseDeadline') != null)   template.ResponseDeadline__c         = Datetime.valueOf((String) templateData.get('responseDeadline'));
        if (templateData.get('confirmationTemplate') != null) template.ConfirmationEmailTemplate__c = (String) templateData.get('confirmationTemplate');
        insert template;
        return template.Id;
    }

    @AuraEnabled
    public static void saveFields(Id templateId, List<Map<String, Object>> fields) {
        List<FormField__c> toDelete = [SELECT Id FROM FormField__c WHERE FormTemplate__c = :templateId];
        if (!toDelete.isEmpty()) delete toDelete;

        List<FormField__c> toInsert = new List<FormField__c>();
        Integer order = 0;
        for (Map<String, Object> f : fields) {
            toInsert.add(new FormField__c(
                FormTemplate__c    = templateId,
                Name               = (String) f.get('label'),
                FieldType__c       = (String) f.get('fieldType'),
                IsRequired__c      = f.get('isRequired') != null ? (Boolean) f.get('isRequired') : false,
                SortOrder__c       = order++,
                PicklistOptions__c = (String) f.get('picklistOptions'),
                PlaceholderText__c = (String) f.get('placeholder'),
                HelpText__c        = (String) f.get('helpText'),
                ApiKey__c          = (String) f.get('apiKey') ?? 'field_' + order
            ));
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled(cacheable=true)
    public static List<FormTemplate__c> getAllTemplates() {
        return [
            SELECT Id, Name, FormType__c, IsActive__c, TotalResponses__c,
                   ResponseDeadline__c, GeneralMeeting__r.Name, AssignedToUser__r.Name
            FROM FormTemplate__c
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static void toggleActive(Id templateId, Boolean isActive) {
        update new FormTemplate__c(Id = templateId, IsActive__c = isActive);
    }

    @AuraEnabled
    public static Id duplicateTemplate(Id templateId) {
        FormTemplate__c src = [
            SELECT Name, FormType__c, Description__c, RequiresAuth__c,
                   SaveToRecord__c, SendConfirmationEmail__c, ConfirmationEmailTemplate__c
            FROM FormTemplate__c WHERE Id = :templateId WITH SECURITY_ENFORCED
        ];
        FormTemplate__c newTemplate = src.clone(false, true, false, false);
        newTemplate.Name = src.Name + '（コピー）';
        newTemplate.TotalResponses__c = 0;
        insert newTemplate;

        List<FormField__c> srcFields = [SELECT Name, FieldType__c, IsRequired__c, SortOrder__c, PicklistOptions__c, PlaceholderText__c, HelpText__c, ApiKey__c FROM FormField__c WHERE FormTemplate__c = :templateId WITH SECURITY_ENFORCED ORDER BY SortOrder__c];
        List<FormField__c> newFields = new List<FormField__c>();
        for (FormField__c f : srcFields) {
            FormField__c nf = f.clone(false, true, false, false);
            nf.FormTemplate__c = newTemplate.Id;
            newFields.add(nf);
        }
        if (!newFields.isEmpty()) insert newFields;
        return newTemplate.Id;
    }
}
