public with sharing class MemberRegistrationController {

    @AuraEnabled(cacheable=true)
    public static Member__c getMemberById(Id memberId) {
        return [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c, MemberStatus__c,
                   MemberType__c, JoinDate__c, Organization__c, Department__c,
                   Position__c, Phone__c, AnnualFee__c, OktaUserId__c,
                   OrgUnit__c, SlackUserId__c, Notes__c
            FROM Member__c
            WHERE Id = :memberId
            WITH SECURITY_ENFORCED
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Member__c getMemberByEmail(String email) {
        List<Member__c> members = [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c, MemberStatus__c,
                   MemberType__c, JoinDate__c, Organization__c, Department__c,
                   Position__c, Phone__c, OrgUnit__c, SlackUserId__c, OktaUserId__c
            FROM Member__c
            WHERE Email__c = :email
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return members.isEmpty() ? null : members[0];
    }

    @AuraEnabled
    public static Id registerMember(Map<String, Object> memberData) {
        Member__c member = new Member__c();
        member.LastName__c    = (String) memberData.get('lastName');
        member.FirstName__c   = (String) memberData.get('firstName');
        member.Email__c       = (String) memberData.get('email');
        member.MemberType__c  = (String) memberData.get('memberType');
        member.Organization__c = (String) memberData.get('organization');
        member.Department__c  = (String) memberData.get('department');
        member.Position__c    = (String) memberData.get('position');
        member.Phone__c       = (String) memberData.get('phone');
        member.MemberStatus__c = '申請中';
        member.JoinDate__c    = Date.today();

        if (!Schema.sObjectType.Member__c.isCreateable()) {
            throw new AuraHandledException('会員レコードの作成権限がありません。');
        }
        insert member;

        EmailNotificationService.sendMemberRegistrationConfirmation(member.Id);
        return member.Id;
    }

    @AuraEnabled
    public static void updateMemberProfile(Id memberId, Map<String, Object> updates) {
        Member__c member = new Member__c(Id = memberId);

        if (updates.containsKey('lastName'))      member.LastName__c      = (String) updates.get('lastName');
        if (updates.containsKey('firstName'))     member.FirstName__c     = (String) updates.get('firstName');
        if (updates.containsKey('phone'))         member.Phone__c         = (String) updates.get('phone');
        if (updates.containsKey('organization'))  member.Organization__c  = (String) updates.get('organization');
        if (updates.containsKey('department'))    member.Department__c    = (String) updates.get('department');
        if (updates.containsKey('position'))      member.Position__c      = (String) updates.get('position');
        if (updates.containsKey('notes'))         member.Notes__c         = (String) updates.get('notes');

        if (!Schema.sObjectType.Member__c.isUpdateable()) {
            throw new AuraHandledException('会員レコードの更新権限がありません。');
        }
        update member;
    }

    @AuraEnabled(cacheable=true)
    public static List<Member__c> searchMembers(String keyword, String statusFilter) {
        String likeKeyword = '%' + keyword + '%';
        String soql = 'SELECT Id, Name, LastName__c, FirstName__c, Email__c, '
                    + 'MemberStatus__c, MemberType__c, Organization__c, Department__c '
                    + 'FROM Member__c WHERE (LastName__c LIKE :likeKeyword '
                    + 'OR FirstName__c LIKE :likeKeyword OR Email__c LIKE :likeKeyword '
                    + 'OR Organization__c LIKE :likeKeyword) ';
        if (String.isNotBlank(statusFilter)) {
            soql += 'AND MemberStatus__c = :statusFilter ';
        }
        soql += 'WITH SECURITY_ENFORCED ORDER BY Name LIMIT 200';
        return Database.query(soql);
    }

    @AuraEnabled
    public static void approveMember(Id memberId) {
        Member__c member = new Member__c(
            Id = memberId,
            MemberStatus__c = '正会員',
            JoinDate__c = Date.today()
        );
        update member;

        EmailNotificationService.sendMemberApprovalNotification(memberId);
        SlackIntegrationService.notifyMemberApproved(memberId);
    }
}
