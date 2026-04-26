public with sharing class ChangeRequestController {

    @AuraEnabled
    public static String createChangeRequest(Id memberId, String requestType, String priority,
                                              String description, String implementationDate) {
        ChangeRequest__c cr = new ChangeRequest__c(
            RequesterMember__c  = memberId,
            RequestType__c      = requestType,
            Priority__c         = priority,
            Description__c      = description,
            RequestDate__c      = Date.today(),
            ApprovalStatus__c   = '申請中'
        );
        if (String.isNotBlank(implementationDate)) {
            cr.ImplementationDate__c = Date.valueOf(implementationDate);
        }
        if (!Schema.sObjectType.ChangeRequest__c.isCreateable()) {
            throw new AuraHandledException('変更申請レコードの作成権限がありません。');
        }
        insert cr;

        try {
            WorkflowApprovalService.submitChangeRequestForApproval(cr.Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '承認プロセス自動起動エラー: ' + e.getMessage());
        }
        return cr.Name;
    }
}
