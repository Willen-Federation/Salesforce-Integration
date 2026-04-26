public with sharing class SlackIntegrationService {

    private static final String NAMED_CREDENTIAL = 'callout:SlackAPI';

    public static void notifyPersonnelChange(Id personnelChangeId) {
        PersonnelChange__c change = [
            SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.SlackUserId__c, ChangeType__c,
                   FromUnit__r.Name, FromUnit__r.SlackChannelId__c,
                   ToUnit__r.Name, ToUnit__r.SlackChannelId__c,
                   EffectiveDate__c, FromPosition__c, ToPosition__c,
                   NotifySlack__c
            FROM PersonnelChange__c
            WHERE Id = :personnelChangeId
            WITH SECURITY_ENFORCED
        ];

        if (!change.NotifySlack__c) return;

        String memberName = change.Member__r.LastName__c + ' ' + change.Member__r.FirstName__c;
        String message = buildPersonnelChangeMessage(change, memberName);

        List<String> channels = new List<String>();
        if (String.isNotBlank(change.FromUnit__r?.SlackChannelId__c)) {
            channels.add(change.FromUnit__r.SlackChannelId__c);
        }
        if (String.isNotBlank(change.ToUnit__r?.SlackChannelId__c)
                && change.ToUnit__r.SlackChannelId__c != change.FromUnit__r?.SlackChannelId__c) {
            channels.add(change.ToUnit__r.SlackChannelId__c);
        }

        for (String channelId : channels) {
            sendMessage(channelId, message);
        }

        PersonnelChange__c update = new PersonnelChange__c(
            Id = personnelChangeId,
            SlackNotificationSent__c = true
        );
        Database.update(update, false);
    }

    public static void notifyMemberApproved(Id memberId) {
        Member__c member = [
            SELECT Id, LastName__c, FirstName__c, OrgUnit__r.SlackChannelId__c
            FROM Member__c
            WHERE Id = :memberId
            WITH SECURITY_ENFORCED
        ];

        String channelId = member.OrgUnit__r?.SlackChannelId__c;
        if (String.isBlank(channelId)) return;

        String msg = ':white_check_mark: 新しい会員が承認されました\n'
                   + '氏名: ' + member.LastName__c + ' ' + member.FirstName__c;
        sendMessage(channelId, msg);
    }

    public static void notifySupportInquiry(Id inquiryId) {
        SupportInquiry__c inq = [
            SELECT Id, Name, Subject__c, Category__c, Priority__c,
                   ContactName__c, NotifySlack__c
            FROM SupportInquiry__c
            WHERE Id = :inquiryId
            WITH SECURITY_ENFORCED
        ];

        if (!inq.NotifySlack__c) return;

        PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();
        String channelId = config.SupportSlackChannelId__c;
        if (String.isBlank(channelId)) return;

        String priorityEmoji = inq.Priority__c == '高' ? ':red_circle:' :
                               inq.Priority__c == '中' ? ':large_yellow_circle:' : ':large_green_circle:';

        String msg = priorityEmoji + ' 新規お問い合わせ [' + inq.Name + ']\n'
                   + '件名: ' + inq.Subject__c + '\n'
                   + 'カテゴリ: ' + inq.Category__c + '\n'
                   + '優先度: ' + inq.Priority__c + '\n'
                   + '問い合わせ者: ' + inq.ContactName__c;

        sendMessage(channelId, msg);
    }

    public static void sendDirectMessage(String slackUserId, String message) {
        if (String.isBlank(slackUserId)) return;
        Map<String, Object> payload = new Map<String, Object>{
            'channel' => slackUserId,
            'text'    => message
        };
        postToSlack('/chat.postMessage', JSON.serialize(payload));
    }

    @Future(callout=true)
    public static void sendMessage(String channelId, String message) {
        if (String.isBlank(channelId)) return;
        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'text'    => message
        };
        postToSlack('/chat.postMessage', JSON.serialize(payload));
    }

    private static void postToSlack(String endpoint, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        req.setBody(body);
        req.setTimeout(10000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR,
                'Slack API error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    private static String buildPersonnelChangeMessage(PersonnelChange__c change, String memberName) {
        String fromInfo = (change.FromUnit__r != null ? change.FromUnit__r.Name : '―')
                        + (String.isNotBlank(change.FromPosition__c) ? '/' + change.FromPosition__c : '');
        String toInfo   = (change.ToUnit__r != null ? change.ToUnit__r.Name : '―')
                        + (String.isNotBlank(change.ToPosition__c) ? '/' + change.ToPosition__c : '');

        return ':office: *人事異動のお知らせ*\n'
             + '氏名: ' + memberName + '\n'
             + '異動種別: ' + change.ChangeType__c + '\n'
             + '異動前: ' + fromInfo + '\n'
             + '異動後: ' + toInfo + '\n'
             + '発令日: ' + change.EffectiveDate__c.format();
    }
}
