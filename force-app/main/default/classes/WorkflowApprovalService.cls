public with sharing class WorkflowApprovalService {

    @AuraEnabled
    public static void submitChangeRequestForApproval(Id changeRequestId) {
        ChangeRequest__c cr = [
            SELECT Id, RequestType__c, RequesterMember__c, RequesterMember__r.Email__c,
                   ApprovalStatus__c
            FROM ChangeRequest__c WHERE Id = :changeRequestId WITH SECURITY_ENFORCED
        ];

        if (cr.ApprovalStatus__c != '申請中') {
            throw new AuraHandledException('既に処理中の申請です。');
        }

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(changeRequestId);
        req.setComments('会員ポータルから申請');

        try {
            Approval.ProcessResult result = Approval.process(req);
            if (!result.isSuccess()) {
                throw new AuraHandledException('承認プロセスの起動に失敗しました: '
                    + result.getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

    }

    @AuraEnabled
    public static void approveChangeRequest(Id changeRequestId, String comment) {
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :changeRequestId
            AND ProcessInstance.Status = 'Pending'
            LIMIT 1
        ];
        if (workItems.isEmpty()) {
            throw new AuraHandledException('承認待ちのワークアイテムが見つかりません。');
        }

        req.setWorkitemId(workItems[0].Id);
        req.setAction('Approve');
        req.setComments(comment);
        Approval.process(req);

        ChangeRequest__c upd = new ChangeRequest__c(
            Id               = changeRequestId,
            ApprovalStatus__c = '承認済み',
            ApprovalDate__c  = Date.today()
        );
        update upd;

        processApprovedChangeRequest(changeRequestId);
    }

    @AuraEnabled
    public static void rejectChangeRequest(Id changeRequestId, String comment) {
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :changeRequestId
            AND ProcessInstance.Status = 'Pending'
            LIMIT 1
        ];
        if (workItems.isEmpty()) {
            throw new AuraHandledException('承認待ちのワークアイテムが見つかりません。');
        }

        req.setWorkitemId(workItems[0].Id);
        req.setAction('Reject');
        req.setComments(comment);
        Approval.process(req);

        update new ChangeRequest__c(
            Id = changeRequestId,
            ApprovalStatus__c = '却下',
            ApprovalComment__c = comment
        );
    }

    private static void processApprovedChangeRequest(Id changeRequestId) {
        ChangeRequest__c cr = [
            SELECT Id, RequestType__c, RequesterMember__c, Description__c
            FROM ChangeRequest__c WHERE Id = :changeRequestId WITH SECURITY_ENFORCED
        ];

        switch on cr.RequestType__c {
            when '退会申請' {
                update new Member__c(Id = cr.RequesterMember__c, MemberStatus__c = '退会');
                OktaIntegrationService.deactivateOktaUser(
                    [SELECT OktaUserId__c FROM Member__c WHERE Id = :cr.RequesterMember__c LIMIT 1].OktaUserId__c
                );
            }
            when '休会申請' {
                update new Member__c(Id = cr.RequesterMember__c, MemberStatus__c = '休会');
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ChangeRequest__c> getPendingApprovals() {
        return [
            SELECT Id, Name, RequestType__c, ApprovalStatus__c, Priority__c,
                   RequestDate__c, RequesterMember__r.LastName__c,
                   RequesterMember__r.FirstName__c, Description__c
            FROM ChangeRequest__c
            WHERE ApprovalStatus__c = '申請中'
            WITH SECURITY_ENFORCED
            ORDER BY Priority__c ASC, RequestDate__c ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ChangeRequest__c> getChangeRequestsByMember(Id memberId) {
        return [
            SELECT Id, Name, RequestType__c, ApprovalStatus__c, Priority__c,
                   RequestDate__c, ApprovalDate__c, Description__c, ApprovalComment__c
            FROM ChangeRequest__c
            WHERE RequesterMember__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY RequestDate__c DESC
            LIMIT 100
        ];
    }
}
