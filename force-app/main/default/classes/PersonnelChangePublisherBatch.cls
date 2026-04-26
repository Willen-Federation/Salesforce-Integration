public without sharing class PersonnelChangePublisherBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new PersonnelChangePublisherBatch(), 20);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Member__c, Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.Email__c, Member__r.SlackUserId__c,
                   ChangeType__c, FromUnit__c, FromUnit__r.Name,
                   ToUnit__c, ToUnit__r.Name, ToPosition__c, FromPosition__c,
                   EffectiveDate__c, AnnouncementStatus__c, NotifySlack__c, NotifyEmail__c
            FROM PersonnelChange__c
            WHERE AnnouncementStatus__c = '発表予定'
            AND   PublicationDate__c <= :Datetime.now()
            AND   ApprovalStatus__c = '承認済み'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<PersonnelChange__c> records) {
        List<PersonnelChange__c> toUpdate = new List<PersonnelChange__c>();

        for (PersonnelChange__c pc : records) {
            try {
                if (pc.NotifySlack__c) {
                    SlackIntegrationService.notifyPersonnelChange(pc.Id);
                }
                if (pc.NotifyEmail__c) {
                    EmailNotificationService.sendPersonnelChangeNotification(pc.Id);
                }
                toUpdate.add(new PersonnelChange__c(
                    Id                  = pc.Id,
                    AnnouncementStatus__c = '発表済み',
                    AnnouncedAt__c      = Datetime.now()
                ));
            } catch (Exception e) {
                System.debug('PersonnelChange publish failed for ' + pc.Id + ': ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {}

    public static String scheduleHourly() {
        String jobName = 'PersonnelChangePublisher_' + Datetime.now().format('yyyyMMdd');
        return System.schedule(jobName, '0 0 * * * ?', new PersonnelChangePublisherBatch());
    }
}
