public with sharing class SupportInquiryController {

    private static final Integer SLA_HOURS_HIGH   = 4;
    private static final Integer SLA_HOURS_MEDIUM = 24;
    private static final Integer SLA_HOURS_LOW    = 72;

    @AuraEnabled
    public static Id submitInquiry(Map<String, Object> inquiryData) {
        SupportInquiry__c inquiry = new SupportInquiry__c();
        inquiry.ContactName__c     = (String) inquiryData.get('contactName');
        inquiry.ContactEmail__c    = (String) inquiryData.get('contactEmail');
        inquiry.Category__c        = (String) inquiryData.get('category');
        inquiry.Subject__c         = (String) inquiryData.get('subject');
        inquiry.Body__c            = (String) inquiryData.get('body');
        inquiry.Priority__c        = '中';
        inquiry.InquiryStatus__c   = '受付済み';
        inquiry.NotifySlack__c     = true;
        inquiry.NotifyEmail__c     = true;
        inquiry.SLADeadline__c     = Datetime.now().addHours(SLA_HOURS_MEDIUM);

        Boolean isAuthenticated = inquiryData.get('isAuthenticated') != null
            ? (Boolean) inquiryData.get('isAuthenticated') : false;
        inquiry.IsAuthenticatedMember__c = isAuthenticated;

        if (inquiryData.containsKey('memberId') && inquiryData.get('memberId') != null) {
            inquiry.Member__c = (Id) inquiryData.get('memberId');
        }

        if (!Schema.sObjectType.SupportInquiry__c.isCreateable()) {
            throw new AuraHandledException('お問い合わせレコードの作成権限がありません。');
        }
        insert inquiry;

        EmailNotificationService.sendInquiryAutoReply(inquiry.Id);
        SlackIntegrationService.notifySupportInquiry(inquiry.Id);
        return inquiry.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<SupportInquiry__c> getInquiriesByMember(Id memberId) {
        return [
            SELECT Id, Name, Category__c, Subject__c, InquiryStatus__c,
                   Priority__c, CreatedDate, ResponseDate__c, SatisfactionRating__c,
                   SLADeadline__c, IsSLAMet__c
            FROM SupportInquiry__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static SupportInquiry__c getInquiryDetail(Id inquiryId) {
        return [
            SELECT Id, Name, ContactName__c, ContactEmail__c, Category__c,
                   Subject__c, Body__c, InquiryStatus__c, Priority__c,
                   Response__c, ResponseDate__c, AssignedTo__r.Name,
                   SatisfactionRating__c, SLADeadline__c, IsSLAMet__c,
                   IsAuthenticatedMember__c, EscalatedTo__r.Name,
                   EscalationDate__c, EscalationReason__c, Tags__c
            FROM SupportInquiry__c
            WHERE Id = :inquiryId
            WITH SECURITY_ENFORCED
        ];
    }

    @AuraEnabled
    public static void assignInquiry(Id inquiryId, Id userId) {
        SupportInquiry__c upd = new SupportInquiry__c(
            Id               = inquiryId,
            AssignedTo__c    = userId,
            InquiryStatus__c = '対応中'
        );
        update upd;
    }

    @AuraEnabled
    public static void escalateInquiry(Id inquiryId, Id escalateTo, String reason) {
        SupportInquiry__c inquiry = [
            SELECT Id, Priority__c, SLADeadline__c
            FROM SupportInquiry__c WHERE Id = :inquiryId WITH SECURITY_ENFORCED
        ];

        inquiry.EscalatedTo__c    = escalateTo;
        inquiry.EscalationDate__c = Datetime.now();
        inquiry.EscalationReason__c = reason;
        inquiry.Priority__c       = '高';
        inquiry.InquiryStatus__c  = '対応中';
        inquiry.SLADeadline__c    = Datetime.now().addHours(SLA_HOURS_HIGH);
        update inquiry;
    }

    @AuraEnabled
    public static void updatePriority(Id inquiryId, String priority) {
        Integer slaHours = priority == '高' ? SLA_HOURS_HIGH
            : priority == '中' ? SLA_HOURS_MEDIUM : SLA_HOURS_LOW;

        SupportInquiry__c upd = new SupportInquiry__c(
            Id             = inquiryId,
            Priority__c    = priority,
            SLADeadline__c = Datetime.now().addHours(slaHours)
        );
        update upd;
    }

    @AuraEnabled
    public static void respondToInquiry(Id inquiryId, String response) {
        SupportInquiry__c inquiry = [
            SELECT Id, ContactEmail__c, ContactName__c, Subject__c, Name,
                   Member__r.Email__c, NotifyEmail__c, FirstResponseDate__c,
                   SLADeadline__c
            FROM SupportInquiry__c WHERE Id = :inquiryId WITH SECURITY_ENFORCED
        ];

        Datetime now = Datetime.now();
        inquiry.Response__c      = response;
        inquiry.ResponseDate__c  = now;
        inquiry.InquiryStatus__c = '回答済み';

        if (inquiry.FirstResponseDate__c == null) {
            inquiry.FirstResponseDate__c = now;
            inquiry.IsSLAMet__c = (inquiry.SLADeadline__c == null || now <= inquiry.SLADeadline__c);
        }
        update inquiry;

        String toEmail = String.isNotBlank(inquiry.ContactEmail__c)
            ? inquiry.ContactEmail__c : inquiry.Member__r?.Email__c;

        if (String.isNotBlank(toEmail) && inquiry.NotifyEmail__c) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ toEmail });
            email.setSubject('【回答】' + inquiry.Subject__c + ' [' + inquiry.Name + ']');
            email.setPlainTextBody(
                '【' + inquiry.ContactName__c + ' 様】\n\n'
                + 'お問い合わせへの回答をお送りします。\n\n'
                + '---\n' + response + '\n---\n\n'
                + '引き続きご不明な点がございましたら、再度お問い合わせください。'
            );
            email.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        }
    }

    @AuraEnabled
    public static void addInternalNote(Id inquiryId, String note) {
        SupportInquiry__c inquiry = [
            SELECT Id, InternalNote__c FROM SupportInquiry__c WHERE Id = :inquiryId WITH SECURITY_ENFORCED
        ];
        String existing = String.isNotBlank(inquiry.InternalNote__c) ? inquiry.InternalNote__c + '\n\n' : '';
        inquiry.InternalNote__c = existing
            + '[' + Datetime.now().format('yyyy-MM-dd HH:mm') + '] '
            + UserInfo.getName() + ':\n' + note;
        update inquiry;
    }

    @AuraEnabled
    public static void closeInquiry(Id inquiryId, String satisfactionRating) {
        SupportInquiry__c upd = new SupportInquiry__c(
            Id                    = inquiryId,
            InquiryStatus__c      = '完了',
            SatisfactionRating__c = satisfactionRating
        );
        update upd;
    }

    @AuraEnabled(cacheable=true)
    public static List<SupportInquiry__c> getOpenInquiries() {
        return [
            SELECT Id, Name, ContactName__c, Category__c, Subject__c,
                   InquiryStatus__c, Priority__c, CreatedDate,
                   AssignedTo__r.Name, SLADeadline__c, IsSLAMet__c,
                   IsAuthenticatedMember__c, EscalatedTo__r.Name, Tags__c
            FROM SupportInquiry__c
            WHERE InquiryStatus__c NOT IN ('完了')
            WITH SECURITY_ENFORCED
            ORDER BY Priority__c ASC, CreatedDate ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<SupportInquiry__c> getOverdueSLAInquiries() {
        return [
            SELECT Id, Name, ContactName__c, Subject__c, Priority__c,
                   InquiryStatus__c, SLADeadline__c, AssignedTo__r.Name
            FROM SupportInquiry__c
            WHERE SLADeadline__c < :Datetime.now()
            AND   InquiryStatus__c NOT IN ('完了', '回答済み')
            WITH SECURITY_ENFORCED
            ORDER BY SLADeadline__c ASC
            LIMIT 100
        ];
    }
}
