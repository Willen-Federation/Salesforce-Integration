public with sharing class ActivityController {

    @AuraEnabled
    public static String createActivity(Map<String, Object> activityData) {
        Activity__c act = new Activity__c(
            ActivityTitle__c  = (String) activityData.get('title'),
            ActivityType__c   = (String) activityData.get('activityType'),
            ActivityDate__c   = Date.valueOf((String) activityData.get('activityDate')),
            Location__c       = (String) activityData.get('location'),
            Description__c    = (String) activityData.get('description'),
            ActivityStatus__c = '登録済み'
        );
        if (activityData.get('memberId') != null) {
            act.Member__c = (Id) activityData.get('memberId');
        }
        if (activityData.get('hours') != null) {
            act.Hours__c = Decimal.valueOf(String.valueOf(activityData.get('hours')));
        }
        if (!Schema.sObjectType.Activity__c.isCreateable()) {
            throw new AuraHandledException('活動レコードの作成権限がありません。');
        }
        insert act;
        return act.Name;
    }

    @AuraEnabled
    public static String createEvent(Map<String, Object> eventData) {
        if (!Schema.sObjectType.Activity__c.isCreateable()) {
            throw new AuraHandledException('イベントレコードの作成権限がありません。');
        }

        Activity__c event = new Activity__c(
            ActivityTitle__c     = (String) eventData.get('title'),
            ActivityType__c      = (String) eventData.get('activityType'),
            ActivityDate__c      = Date.valueOf((String) eventData.get('activityDate')),
            Location__c          = (String) eventData.get('location'),
            Description__c       = (String) eventData.get('description'),
            ActivityStatus__c    = '登録済み',
            IsEvent__c           = true,
            IsPublic__c          = eventData.get('isPublic') != null ? (Boolean) eventData.get('isPublic') : false
        );

        if (eventData.get('memberId') != null) {
            event.Member__c = (Id) eventData.get('memberId');
        }
        if (eventData.get('eventStartDatetime') != null) {
            event.EventStartDatetime__c = Datetime.valueOf((String) eventData.get('eventStartDatetime'));
        }
        if (eventData.get('eventEndDatetime') != null) {
            event.EventEndDatetime__c = Datetime.valueOf((String) eventData.get('eventEndDatetime'));
        }
        if (eventData.get('registrationDeadline') != null) {
            event.RegistrationDeadline__c = Date.valueOf((String) eventData.get('registrationDeadline'));
        }
        if (eventData.get('maxParticipants') != null) {
            event.MaxParticipants__c = Integer.valueOf(String.valueOf(eventData.get('maxParticipants')));
        }
        if (eventData.get('registrationFee') != null) {
            event.RegistrationFee__c = Decimal.valueOf(String.valueOf(eventData.get('registrationFee')));
        }
        if (eventData.get('onlineUrl') != null) {
            event.OnlineUrl__c = (String) eventData.get('onlineUrl');
        }

        insert event;
        return event.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Activity__c> getActivitiesByMember(Id memberId) {
        return [
            SELECT Id, Name, ActivityTitle__c, ActivityType__c, ActivityDate__c,
                   Location__c, Hours__c, ActivityStatus__c, Points__c,
                   IsEvent__c, IsPublic__c
            FROM Activity__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate__c DESC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Activity__c> getPublicEvents() {
        return [
            SELECT Id, Name, ActivityTitle__c, ActivityType__c, ActivityDate__c,
                   EventStartDatetime__c, EventEndDatetime__c, Location__c,
                   Description__c, MaxParticipants__c, CurrentParticipants__c,
                   RegistrationDeadline__c, RegistrationFee__c, OnlineUrl__c,
                   ActivityStatus__c
            FROM Activity__c
            WHERE IsEvent__c = true
            AND   IsPublic__c = true
            AND   ActivityStatus__c NOT IN ('キャンセル')
            AND   (RegistrationDeadline__c >= TODAY OR RegistrationDeadline__c = null)
            WITH SECURITY_ENFORCED
            ORDER BY EventStartDatetime__c ASC NULLS LAST
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Activity__c> getUpcomingEvents() {
        return [
            SELECT Id, Name, ActivityTitle__c, ActivityType__c, ActivityDate__c,
                   EventStartDatetime__c, EventEndDatetime__c, Location__c,
                   Description__c, MaxParticipants__c, CurrentParticipants__c,
                   RegistrationDeadline__c, RegistrationFee__c, OnlineUrl__c,
                   IsPublic__c, ActivityStatus__c
            FROM Activity__c
            WHERE IsEvent__c = true
            AND   ActivityStatus__c NOT IN ('キャンセル')
            WITH SECURITY_ENFORCED
            ORDER BY EventStartDatetime__c ASC NULLS LAST
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Id registerForEvent(Map<String, Object> registrationData) {
        Id activityId = (Id) registrationData.get('activityId');

        Activity__c event = [
            SELECT Id, MaxParticipants__c, CurrentParticipants__c, RegistrationDeadline__c, ActivityStatus__c
            FROM Activity__c
            WHERE Id = :activityId
            WITH SECURITY_ENFORCED
        ];

        if (event.ActivityStatus__c == 'キャンセル') {
            throw new AuraHandledException('このイベントはキャンセルされています。');
        }
        if (event.RegistrationDeadline__c != null && event.RegistrationDeadline__c < Date.today()) {
            throw new AuraHandledException('参加申込の締切が過ぎています。');
        }
        if (event.MaxParticipants__c != null && event.CurrentParticipants__c >= event.MaxParticipants__c) {
            throw new AuraHandledException('定員に達しています。');
        }

        ActivityParticipant__c participant = new ActivityParticipant__c(
            Activity__c             = activityId,
            ParticipantName__c      = (String) registrationData.get('participantName'),
            ParticipantEmail__c     = (String) registrationData.get('participantEmail'),
            ParticipantOrganization__c = (String) registrationData.get('participantOrganization'),
            ParticipationStatus__c  = '申込済み',
            RegistrationDate__c     = Datetime.now(),
            IsExternalParticipant__c = registrationData.get('memberId') == null,
            Remarks__c              = (String) registrationData.get('remarks')
        );
        if (registrationData.get('memberId') != null) {
            participant.Member__c = (Id) registrationData.get('memberId');
        }

        if (!Schema.sObjectType.ActivityParticipant__c.isCreateable()) {
            throw new AuraHandledException('参加申込レコードの作成権限がありません。');
        }
        insert participant;

        event.CurrentParticipants__c = (event.CurrentParticipants__c == null ? 0 : event.CurrentParticipants__c) + 1;
        update event;

        return participant.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityParticipant__c> getParticipantsByEvent(Id activityId) {
        return [
            SELECT Id, Name, ParticipantName__c, ParticipantEmail__c,
                   ParticipantOrganization__c, ParticipationStatus__c,
                   RegistrationDate__c, IsExternalParticipant__c,
                   PaymentStatus__c, Remarks__c, Member__c, Member__r.Name
            FROM ActivityParticipant__c
            WHERE Activity__c = :activityId
            WITH SECURITY_ENFORCED
            ORDER BY RegistrationDate__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityParticipant__c> getMyRegistrations(Id memberId) {
        return [
            SELECT Id, Name, Activity__c, Activity__r.ActivityTitle__c,
                   Activity__r.EventStartDatetime__c, Activity__r.Location__c,
                   ParticipationStatus__c, RegistrationDate__c
            FROM ActivityParticipant__c
            WHERE Member__c = :memberId
            WITH SECURITY_ENFORCED
            ORDER BY RegistrationDate__c DESC
            LIMIT 100
        ];
    }
}
