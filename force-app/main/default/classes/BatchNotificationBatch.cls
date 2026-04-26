public class BatchNotificationBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    private Id notificationId;

    public BatchNotificationBatch(Id notificationId) {
        this.notificationId = notificationId;
    }

    // Schedulable: 予約送信用
    public void execute(SchedulableContext sc) {
        List<BatchNotification__c> scheduled = [
            SELECT Id FROM BatchNotification__c
            WHERE NotificationStatus__c = '送信予約済み'
            AND ScheduledDate__c <= :Datetime.now()
            WITH SECURITY_ENFORCED
        ];
        for (BatchNotification__c n : scheduled) {
            Database.executeBatch(new BatchNotificationBatch(n.Id), 50);
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        BatchNotification__c notif = [
            SELECT Id, NotificationType__c, TargetOrgUnit__c, Channel__c
            FROM BatchNotification__c WHERE Id = :notificationId
            WITH SECURITY_ENFORCED
        ];

        update new BatchNotification__c(
            Id = notificationId,
            NotificationStatus__c = '送信中',
            SentDate__c = Datetime.now()
        );

        String soql = 'SELECT Id, Email__c, SlackUserId__c, LastName__c, FirstName__c '
                    + 'FROM Member__c WHERE MemberStatus__c IN (\'正会員\', \'準会員\') ';

        if (notif.NotificationType__c == '組織別' && notif.TargetOrgUnit__c != null) {
            Id orgUnitId = notif.TargetOrgUnit__c;
            soql += 'AND OrgUnit__c = \'' + String.escapeSingleQuotes(orgUnitId) + '\' ';
        }
        soql += 'WITH SECURITY_ENFORCED ORDER BY Name';
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<Member__c> members) {
        BatchNotification__c notif = [
            SELECT Id, Name, Content__c, Channel__c, SentCount__c, FailedCount__c
            FROM BatchNotification__c WHERE Id = :notificationId
            WITH SECURITY_ENFORCED
        ];

        Integer sentCount   = (Integer)(notif.SentCount__c != null ? notif.SentCount__c : 0);
        Integer failedCount = (Integer)(notif.FailedCount__c != null ? notif.FailedCount__c : 0);
        Set<String> channels = new Set<String>(notif.Channel__c.split(';'));

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Member__c member : members) {
            if (channels.contains('メール') && String.isNotBlank(member.Email__c)) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ member.Email__c });
                email.setSubject('[通知] ' + notif.Name);
                email.setHtmlBody(notif.Content__c);
                email.setSaveAsActivity(false);
                emails.add(email);
                sentCount++;
            }

            if (channels.contains('Slack') && String.isNotBlank(member.SlackUserId__c)) {
                try {
                    SlackIntegrationService.sendDirectMessage(member.SlackUserId__c,
                        notif.Name + '\n\n' + notif.Content__c.stripHtmlTags());
                } catch (Exception e) {
                    failedCount++;
                    System.debug(LoggingLevel.WARN, 'Slack DM failed for ' + member.Id + ': ' + e.getMessage());
                }
            }
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                failedCount += emails.size();
                sentCount   -= emails.size();
            }
        }

        update new BatchNotification__c(
            Id = notificationId,
            SentCount__c   = sentCount,
            FailedCount__c = failedCount
        );
    }

    public void finish(Database.BatchableContext bc) {
        BatchNotification__c notif = [
            SELECT Id, FailedCount__c FROM BatchNotification__c
            WHERE Id = :notificationId WITH SECURITY_ENFORCED
        ];

        String finalStatus = (notif.FailedCount__c != null && notif.FailedCount__c > 0)
            ? '送信失敗' : '送信完了';

        update new BatchNotification__c(
            Id = notificationId,
            NotificationStatus__c = finalStatus
        );
    }
}
