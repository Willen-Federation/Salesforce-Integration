public with sharing class IndividualNotificationService {

    private static final String WILLEN_EMAIL_SUFFIX = '@willen.jp';

    public class NotificationException extends Exception {}

    @AuraEnabled
    public static Id createAndSend(Map<String, Object> notifData) {
        IndividualNotification__c notif = buildRecord(notifData);
        notif.NotificationStatus__c = '送信予約';
        if (!Schema.sObjectType.IndividualNotification__c.isCreateable()) {
            throw new AuraHandledException('通知レコードの作成権限がありません。');
        }
        insert notif;
        sendNotification(notif.Id);
        return notif.Id;
    }

    @AuraEnabled
    public static Id saveDraft(Map<String, Object> notifData) {
        IndividualNotification__c notif = buildRecord(notifData);
        notif.NotificationStatus__c = '下書き';
        insert notif;
        return notif.Id;
    }

    @AuraEnabled
    public static void scheduleNotification(Id notifId, Datetime scheduledTime) {
        IndividualNotification__c upd = new IndividualNotification__c(
            Id                    = notifId,
            NotificationStatus__c = '送信予約',
            ScheduledSendTime__c  = scheduledTime
        );
        update upd;
    }

    @Future(callout=true)
    public static void sendNotification(Id notifId) {
        IndividualNotification__c notif = [
            SELECT Id, Subject__c, BodyTemplate__c, DeliveryChannels__c,
                   RecipientType__c, RecipientMember__c, RecipientOrgUnit__c,
                   RecipientMemberType__c, RelatedObjectType__c, RelatedRecordId__c,
                   WillenEmailDomain__c
            FROM IndividualNotification__c
            WHERE Id = :notifId
        ];

        List<Member__c> recipients = resolveRecipients(notif);

        Integer sent = 0;
        Integer failed = 0;
        List<String> channels = notif.DeliveryChannels__c != null
            ? notif.DeliveryChannels__c.split(';') : new List<String>();

        for (Member__c member : recipients) {
            String mergedBody = mergePlaceholders(notif.BodyTemplate__c, notif.RelatedObjectType__c, notif.RelatedRecordId__c, member);
            String mergedSubject = mergePlaceholders(notif.Subject__c, notif.RelatedObjectType__c, notif.RelatedRecordId__c, member);

            try {
                for (String channel : channels) {
                    if (channel.trim() == '個人登録メール' && String.isNotBlank(member.Email__c)) {
                        sendEmail(member.Email__c, mergedSubject, mergedBody);
                    } else if (channel.trim() == 'Willenメール') {
                        String willenEmail = buildWillenEmail(member, notif.WillenEmailDomain__c);
                        if (String.isNotBlank(willenEmail)) {
                            sendEmail(willenEmail, mergedSubject, mergedBody);
                        }
                    } else if (channel.trim() == 'Slack' && String.isNotBlank(member.SlackUserId__c)) {
                        SlackIntegrationService.sendDirectMessage(member.SlackUserId__c, mergedBody);
                    } else if (channel.trim() == 'ポータル通知') {
                        createPortalNotification(member.Id, mergedSubject, mergedBody, notifId);
                    }
                }
                sent++;
            } catch (Exception e) {
                System.debug('Notification send failed for ' + member.Id + ': ' + e.getMessage());
                failed++;
            }
        }

        update new IndividualNotification__c(
            Id                    = notifId,
            NotificationStatus__c = '送信済み',
            SentCount__c          = sent,
            FailedCount__c        = failed,
            SentAt__c             = Datetime.now()
        );
    }

    public static String mergePlaceholders(String template, String objectType, String recordId, Member__c member) {
        if (String.isBlank(template)) return '';

        String result = template;
        result = result.replace('{!Member.LastName}',    member.LastName__c  ?? '');
        result = result.replace('{!Member.FirstName}',   member.FirstName__c ?? '');
        result = result.replace('{!Member.Email}',       member.Email__c     ?? '');
        result = result.replace('{!Member.MemberType}',  member.MemberType__c ?? '');
        result = result.replace('{!Member.MemberStatus}', member.MemberStatus__c ?? '');
        result = result.replace('{!Member.Organization}', member.Organization__c ?? '');
        result = result.replace('{!Member.Position}',    member.Position__c  ?? '');
        result = result.replace('{!Member.Name}',        (member.LastName__c ?? '') + ' ' + (member.FirstName__c ?? ''));
        result = result.replace('{!Today}', Date.today().format());
        result = result.replace('{!Now}', Datetime.now().format('yyyy/MM/dd HH:mm'));

        if (String.isNotBlank(objectType) && String.isNotBlank(recordId)) {
            result = mergeRelatedRecord(result, objectType, recordId);
        }
        return result;
    }

    private static String mergeRelatedRecord(String template, String objectType, String recordId) {
        try {
            if (objectType == 'Payment__c') {
                Payment__c rec = [SELECT Id, Name, Amount__c, BaseAmount__c, PlatformFee__c,
                                         PaymentStatus__c, DueDate__c FROM Payment__c WHERE Id = :recordId LIMIT 1];
                PortalConfiguration__c cfg = PortalConfiguration__c.getOrgDefaults();
                String feeLabel = 'プラットフォーム利用手数料';
                String portalUrl = cfg?.PortalBaseUrl__c ?? '';
                template = template.replace('{!Payment.Name}',        rec.Name ?? '');
                template = template.replace('{!Payment.Amount}',       rec.Amount__c   != null ? '¥' + String.valueOf(Integer.valueOf(rec.Amount__c))   : '');
                template = template.replace('{!Payment.BaseAmount}',   rec.BaseAmount__c != null ? '¥' + String.valueOf(Integer.valueOf(rec.BaseAmount__c)) : '');
                template = template.replace('{!Payment.PlatformFee}',  rec.PlatformFee__c != null && rec.PlatformFee__c > 0
                    ? feeLabel + ': ¥' + String.valueOf(Integer.valueOf(rec.PlatformFee__c)) : '');
                template = template.replace('{!Payment.Status}',       rec.PaymentStatus__c ?? '');
                template = template.replace('{!Payment.DueDate}',      rec.DueDate__c != null ? rec.DueDate__c.format() : '');
                template = template.replace('{!Payment.PaymentUrl}',   String.isNotBlank(portalUrl) ? portalUrl : '');
            } else if (objectType == 'Activity__c') {
                Activity__c rec = [SELECT Id, Name, ActivityTitle__c, ActivityDate__c, Location__c FROM Activity__c WHERE Id = :recordId LIMIT 1];
                template = template.replace('{!Activity.Title}',    rec.ActivityTitle__c ?? '');
                template = template.replace('{!Activity.Date}',     rec.ActivityDate__c != null ? rec.ActivityDate__c.format() : '');
                template = template.replace('{!Activity.Location}', rec.Location__c ?? '');
            } else if (objectType == 'GeneralMeeting__c') {
                GeneralMeeting__c rec = [SELECT Id, Name, MeetingDate__c, Location__c, ResponseDeadline__c FROM GeneralMeeting__c WHERE Id = :recordId LIMIT 1];
                template = template.replace('{!Meeting.Name}',      rec.Name ?? '');
                template = template.replace('{!Meeting.Date}',      rec.MeetingDate__c != null ? rec.MeetingDate__c.format('yyyy/MM/dd HH:mm') : '');
                template = template.replace('{!Meeting.Location}',  rec.Location__c ?? '');
                template = template.replace('{!Meeting.Deadline}',  rec.ResponseDeadline__c != null ? rec.ResponseDeadline__c.format('yyyy/MM/dd HH:mm') : '');
            }
        } catch (Exception e) {
            System.debug('PlaceFolder merge failed: ' + e.getMessage());
        }
        return template;
    }

    private static List<Member__c> resolveRecipients(IndividualNotification__c notif) {
        if (notif.RecipientType__c == '特定会員' && notif.RecipientMember__c != null) {
            return [SELECT Id, LastName__c, FirstName__c, Email__c, SlackUserId__c,
                           MemberType__c, MemberStatus__c, Organization__c, Position__c
                    FROM Member__c WHERE Id = :notif.RecipientMember__c WITH SECURITY_ENFORCED];
        } else if (notif.RecipientType__c == '組織単位' && notif.RecipientOrgUnit__c != null) {
            return [SELECT Id, LastName__c, FirstName__c, Email__c, SlackUserId__c,
                           MemberType__c, MemberStatus__c, Organization__c, Position__c
                    FROM Member__c WHERE OrgUnit__c = :notif.RecipientOrgUnit__c AND MemberStatus__c IN ('正会員','準会員') WITH SECURITY_ENFORCED LIMIT 200];
        } else if (notif.RecipientType__c == '会員種別' && notif.RecipientMemberType__c != null) {
            return [SELECT Id, LastName__c, FirstName__c, Email__c, SlackUserId__c,
                           MemberType__c, MemberStatus__c, Organization__c, Position__c
                    FROM Member__c WHERE MemberType__c = :notif.RecipientMemberType__c AND MemberStatus__c IN ('正会員','準会員') WITH SECURITY_ENFORCED LIMIT 500];
        } else if (notif.RecipientType__c == '全会員') {
            return [SELECT Id, LastName__c, FirstName__c, Email__c, SlackUserId__c,
                           MemberType__c, MemberStatus__c, Organization__c, Position__c
                    FROM Member__c WHERE MemberStatus__c IN ('正会員','準会員') WITH SECURITY_ENFORCED LIMIT 2000];
        }
        return new List<Member__c>();
    }

    private static String buildWillenEmail(Member__c member, String domain) {
        if (String.isBlank(member.LastName__c)) return null;
        String suffix = String.isNotBlank(domain) ? domain : WILLEN_EMAIL_SUFFIX;
        String localPart = (member.LastName__c + (member.FirstName__c ?? '')).toLowerCase()
            .replaceAll('[^a-z0-9]', '');
        return String.isNotBlank(localPart) ? localPart + suffix : null;
    }

    private static void sendEmail(String toAddress, String subject, String body) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toAddress });
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static void createPortalNotification(Id memberId, String subject, String body, Id sourceId) {
        BatchNotification__c n = new BatchNotification__c(
            Name         = subject.left(80),
            Content__c   = body,
            Channel__c   = 'ポータル内通知',
            Status__c    = '送信予約済み',
            TargetType__c = '個別'
        );
        insert n;
    }

    private static IndividualNotification__c buildRecord(Map<String, Object> data) {
        IndividualNotification__c notif = new IndividualNotification__c(
            Subject__c              = (String) data.get('subject'),
            BodyTemplate__c         = (String) data.get('bodyTemplate'),
            DeliveryChannels__c     = (String) data.get('deliveryChannels'),
            RecipientType__c        = (String) data.get('recipientType')
        );
        if (data.get('recipientMemberId') != null)   notif.RecipientMember__c       = (Id) data.get('recipientMemberId');
        if (data.get('recipientOrgUnitId') != null)  notif.RecipientOrgUnit__c      = (Id) data.get('recipientOrgUnitId');
        if (data.get('recipientMemberType') != null) notif.RecipientMemberType__c   = (String) data.get('recipientMemberType');
        if (data.get('relatedObjectType') != null)   notif.RelatedObjectType__c     = (String) data.get('relatedObjectType');
        if (data.get('relatedRecordId') != null)     notif.RelatedRecordId__c       = (String) data.get('relatedRecordId');
        if (data.get('scheduledSendTime') != null)   notif.ScheduledSendTime__c     = Datetime.valueOf((String) data.get('scheduledSendTime'));
        if (data.get('willenEmailDomain') != null)   notif.WillenEmailDomain__c     = (String) data.get('willenEmailDomain');
        return notif;
    }

    /**
     * テストメール送信。
     * 現在ユーザーに紐づく Member__c でマージし testEmail へ送信する。
     * マージ済み本文を返すので LWC でプレビュー表示できる。
     */
    @AuraEnabled
    public static String sendTestEmail(String subject, String bodyTemplate,
                                       String relatedObjectType, String relatedRecordId,
                                       String testEmail) {
        if (String.isBlank(testEmail))    throw new AuraHandledException('テスト送信先メールアドレスを入力してください。');
        if (String.isBlank(bodyTemplate)) throw new AuraHandledException('本文を入力してください。');

        Member__c member = resolveTestMember();
        String mergedSubject = mergePlaceholders(subject, relatedObjectType, relatedRecordId, member);
        String mergedBody    = mergePlaceholders(bodyTemplate, relatedObjectType, relatedRecordId, member);

        sendEmail(testEmail, '[テスト] ' + mergedSubject, mergedBody);
        return mergedBody;
    }

    private static Member__c resolveTestMember() {
        Id userId = UserInfo.getUserId();
        List<Member__c> members = [
            SELECT Id, LastName__c, FirstName__c, Email__c, SlackUserId__c,
                   MemberType__c, MemberStatus__c, Organization__c, Position__c
            FROM Member__c
            WHERE UserId__c = :userId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!members.isEmpty()) return members[0];

        // 代替: ダミー会員でプレースホルダーを埋める
        Member__c dummy = new Member__c();
        dummy.LastName__c    = UserInfo.getLastName();
        dummy.FirstName__c   = UserInfo.getFirstName();
        dummy.Email__c       = UserInfo.getUserEmail();
        dummy.MemberType__c  = '正会員';
        dummy.MemberStatus__c = '正会員';
        return dummy;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPlaceholderHelp(String objectType) {
        List<Map<String, String>> result = new List<Map<String, String>>{
            new Map<String,String>{'placeholder' => '{!Member.Name}',       'description' => '会員氏名（姓名）'},
            new Map<String,String>{'placeholder' => '{!Member.LastName}',   'description' => '姓'},
            new Map<String,String>{'placeholder' => '{!Member.FirstName}',  'description' => '名'},
            new Map<String,String>{'placeholder' => '{!Member.Email}',      'description' => '登録メールアドレス'},
            new Map<String,String>{'placeholder' => '{!Member.MemberType}', 'description' => '会員種別'},
            new Map<String,String>{'placeholder' => '{!Member.Organization}','description' => '所属組織名'},
            new Map<String,String>{'placeholder' => '{!Member.Position}',   'description' => '役職'},
            new Map<String,String>{'placeholder' => '{!Today}',             'description' => '今日の日付'},
            new Map<String,String>{'placeholder' => '{!Now}',               'description' => '現在日時'}
        };
        if (objectType == 'Payment__c') {
            result.add(new Map<String,String>{'placeholder' => '{!Payment.Name}',   'description' => '支払い番号'});
            result.add(new Map<String,String>{'placeholder' => '{!Payment.Amount}', 'description' => '支払い金額'});
            result.add(new Map<String,String>{'placeholder' => '{!Payment.DueDate}','description' => '支払期限'});
        } else if (objectType == 'GeneralMeeting__c') {
            result.add(new Map<String,String>{'placeholder' => '{!Meeting.Name}',     'description' => '総会名'});
            result.add(new Map<String,String>{'placeholder' => '{!Meeting.Date}',     'description' => '開催日時'});
            result.add(new Map<String,String>{'placeholder' => '{!Meeting.Location}', 'description' => '開催場所'});
            result.add(new Map<String,String>{'placeholder' => '{!Meeting.Deadline}', 'description' => '回答期限'});
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<IndividualNotification__c> getRecentNotifications(Integer limitCount) {
        Integer lim = (limitCount != null && limitCount > 0) ? limitCount : 10;
        return [
            SELECT Id, Subject__c, RecipientType__c, DeliveryChannels__c,
                   NotificationStatus__c, SentCount__c, SentAt__c
            FROM IndividualNotification__c
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :lim
        ];
    }
}
