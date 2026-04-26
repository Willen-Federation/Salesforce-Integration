trigger PersonnelChangeTrigger on PersonnelChange__c (after insert, after update) {
    Set<Id> toSyncOkta        = new Set<Id>();
    Set<Id> toNotifyAnnounced = new Set<Id>();

    for (PersonnelChange__c pc : Trigger.new) {
        PersonnelChange__c old = Trigger.isUpdate ? Trigger.oldMap.get(pc.Id) : null;

        Boolean justApproved = Trigger.isUpdate
            && pc.ApprovalStatus__c == '承認済み'
            && old.ApprovalStatus__c != '承認済み';
        Boolean isNewApproved = Trigger.isInsert && pc.ApprovalStatus__c == '承認済み';

        // 承認直後: OrgUnit の即時反映 + Okta 同期のみ。通知は発表時まで保留。
        if (justApproved || isNewApproved) {
            toSyncOkta.add(pc.Id);
        }

        // AnnouncementStatus__c が '発表済み' になった瞬間: Slack + メール通知
        // PersonnelChangePublisherBatch がステータスを '発表済み' に更新したとき、
        // ここでトリガが再度発火し通知が送られる。
        Boolean justAnnounced = Trigger.isUpdate
            && pc.AnnouncementStatus__c == '発表済み'
            && old.AnnouncementStatus__c != '発表済み';
        if (justAnnounced) {
            toNotifyAnnounced.add(pc.Id);
        }
    }

    // OrgUnit 即時反映 + Okta グループ同期
    if (!toSyncOkta.isEmpty()) {
        Map<Id, Id> memberToUnit = new Map<Id, Id>();
        for (PersonnelChange__c pc : Trigger.new) {
            if (toSyncOkta.contains(pc.Id) && pc.ToUnit__c != null) {
                memberToUnit.put(pc.Member__c, pc.ToUnit__c);
            }
        }
        if (!memberToUnit.isEmpty()) {
            List<Member__c> toUpdate = new List<Member__c>();
            for (Id memberId : memberToUnit.keySet()) {
                toUpdate.add(new Member__c(Id = memberId, OrgUnit__c = memberToUnit.get(memberId)));
            }
            update toUpdate;
        }
        for (Id pcId : toSyncOkta) {
            OktaIntegrationService.processPersonnelChangeInOkta(pcId);
        }
    }

    // 発表確定後の通知（Slack + メール）
    for (PersonnelChange__c pc : Trigger.new) {
        if (!toNotifyAnnounced.contains(pc.Id)) continue;
        if (pc.NotifySlack__c && !pc.SlackNotificationSent__c) {
            SlackIntegrationService.notifyPersonnelChange(pc.Id);
        }
        if (pc.NotifyEmail__c) {
            EmailNotificationService.sendPersonnelChangeNotification(pc.Id);
        }
    }
}
