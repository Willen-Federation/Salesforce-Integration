public with sharing class GeneralMeetingController {

    @AuraEnabled(cacheable=true)
    public static List<GeneralMeeting__c> getUpcomingMeetings() {
        return [
            SELECT Id, Name, FiscalYear__c, MeetingDate__c, Location__c, OnlineUrl__c,
                   MeetingStatus__c, ResponseDeadline__c, AttendanceCount__c,
                   ProxyCount__c, AbsenceCount__c, Agenda__c, AttachmentUrl__c
            FROM GeneralMeeting__c
            WHERE MeetingStatus__c IN ('準備中', '出欠受付中', '締め切り')
            WITH SECURITY_ENFORCED
            ORDER BY MeetingDate__c DESC
            LIMIT 10
        ];
    }

    @AuraEnabled(cacheable=true)
    public static GeneralMeeting__c getMeetingDetail(Id meetingId) {
        return [
            SELECT Id, Name, FiscalYear__c, MeetingDate__c, Location__c, OnlineUrl__c,
                   MeetingStatus__c, ResponseDeadline__c, AttendanceCount__c,
                   ProxyCount__c, AbsenceCount__c, Agenda__c, AttachmentUrl__c,
                   ReminderSentAt__c
            FROM GeneralMeeting__c
            WHERE Id = :meetingId
            WITH SECURITY_ENFORCED
        ];
    }

    @AuraEnabled
    public static Id createMeeting(Map<String, Object> meetingData) {
        if (!Schema.sObjectType.GeneralMeeting__c.isCreateable()) {
            throw new AuraHandledException('総会レコードの作成権限がありません。');
        }
        GeneralMeeting__c meeting = new GeneralMeeting__c(
            Name            = (String) meetingData.get('name'),
            FiscalYear__c   = Integer.valueOf(String.valueOf(meetingData.get('fiscalYear'))),
            MeetingDate__c  = Datetime.valueOf((String) meetingData.get('meetingDate')),
            MeetingStatus__c = '準備中'
        );
        if (meetingData.get('location') != null)         meeting.Location__c         = (String) meetingData.get('location');
        if (meetingData.get('onlineUrl') != null)        meeting.OnlineUrl__c        = (String) meetingData.get('onlineUrl');
        if (meetingData.get('responseDeadline') != null) meeting.ResponseDeadline__c = Datetime.valueOf((String) meetingData.get('responseDeadline'));
        if (meetingData.get('agenda') != null)           meeting.Agenda__c           = (String) meetingData.get('agenda');
        if (meetingData.get('attachmentUrl') != null)    meeting.AttachmentUrl__c    = (String) meetingData.get('attachmentUrl');
        insert meeting;
        return meeting.Id;
    }

    @AuraEnabled
    public static void updateMeetingStatus(Id meetingId, String status) {
        update new GeneralMeeting__c(Id = meetingId, MeetingStatus__c = status);
    }

    @AuraEnabled(cacheable=true)
    public static FormResponse__c getMemberResponse(Id meetingId, Id memberId) {
        List<FormTemplate__c> templates = [
            SELECT Id FROM FormTemplate__c WHERE GeneralMeeting__c = :meetingId AND IsActive__c = true LIMIT 1
        ];
        if (templates.isEmpty()) return null;

        List<FormResponse__c> responses = [
            SELECT Id, Name, AttendanceChoice__c, ProxyName__c, VotingChoicesJson__c,
                   FieldAnswersJson__c, ResponseStatus__c, SubmittedAt__c
            FROM FormResponse__c
            WHERE FormTemplate__c = :templates[0].Id
            AND   Member__c = :memberId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return responses.isEmpty() ? null : responses[0];
    }

    @AuraEnabled
    public static Id submitAttendanceResponse(Id meetingId, Id memberId, String attendanceChoice,
                                               String proxyName, String votingChoicesJson, String fieldAnswersJson) {
        List<FormTemplate__c> templates = [
            SELECT Id, IsActive__c, ResponseDeadline__c, SendConfirmationEmail__c, ConfirmationEmailTemplate__c, Name
            FROM FormTemplate__c
            WHERE GeneralMeeting__c = :meetingId
            AND   IsActive__c = true
            ORDER BY CreatedDate DESC LIMIT 1
        ];

        if (templates.isEmpty()) {
            throw new AuraHandledException('この総会の受付フォームが見つかりません。');
        }
        FormTemplate__c template = templates[0];

        if (template.ResponseDeadline__c != null && template.ResponseDeadline__c < Datetime.now()) {
            throw new AuraHandledException('回答期限が過ぎています。');
        }

        List<FormResponse__c> existing = [
            SELECT Id FROM FormResponse__c WHERE FormTemplate__c = :template.Id AND Member__c = :memberId LIMIT 1
        ];

        Member__c member = [SELECT Id, LastName__c, FirstName__c, Email__c FROM Member__c WHERE Id = :memberId WITH SECURITY_ENFORCED];

        FormResponse__c response;
        if (!existing.isEmpty()) {
            response = new FormResponse__c(
                Id                 = existing[0].Id,
                AttendanceChoice__c = attendanceChoice,
                ProxyName__c       = proxyName,
                VotingChoicesJson__c = votingChoicesJson,
                FieldAnswersJson__c = fieldAnswersJson,
                ResponseStatus__c  = '回答済み',
                SubmittedAt__c     = Datetime.now()
            );
            update response;
        } else {
            response = new FormResponse__c(
                FormTemplate__c    = template.Id,
                Member__c          = memberId,
                RespondentName__c  = member.LastName__c + ' ' + member.FirstName__c,
                RespondentEmail__c = member.Email__c,
                AttendanceChoice__c = attendanceChoice,
                ProxyName__c       = proxyName,
                VotingChoicesJson__c = votingChoicesJson,
                FieldAnswersJson__c = fieldAnswersJson,
                ResponseStatus__c  = '回答済み',
                SubmittedAt__c     = Datetime.now()
            );
            insert response;
            update new FormTemplate__c(Id = template.Id, TotalResponses__c = [SELECT COUNT() FROM FormResponse__c WHERE FormTemplate__c = :template.Id]);
        }

        updateMeetingCounts(meetingId);

        if (template.SendConfirmationEmail__c && String.isNotBlank(member.Email__c)) {
            String body = String.isNotBlank(template.ConfirmationEmailTemplate__c)
                ? template.ConfirmationEmailTemplate__c
                : buildDefaultConfirmationBody(member, attendanceChoice, meetingId);
            sendConfirmation(member.Email__c, '【受付完了】' + template.Name, body);
            update new FormResponse__c(Id = response.Id, ConfirmationEmailSent__c = true);
        }
        return response.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<FormResponse__c> getResponsesForMeeting(Id meetingId) {
        List<FormTemplate__c> templates = [SELECT Id FROM FormTemplate__c WHERE GeneralMeeting__c = :meetingId LIMIT 1];
        if (templates.isEmpty()) return new List<FormResponse__c>();
        return [
            SELECT Id, Name, Member__r.LastName__c, Member__r.FirstName__c,
                   Member__r.Email__c, Member__r.MemberType__c,
                   RespondentName__c, RespondentEmail__c,
                   AttendanceChoice__c, ProxyName__c, ResponseStatus__c, SubmittedAt__c
            FROM FormResponse__c
            WHERE FormTemplate__c = :templates[0].Id
            WITH SECURITY_ENFORCED
            ORDER BY SubmittedAt__c DESC
            LIMIT 500
        ];
    }

    @AuraEnabled
    public static void sendReminders(Id meetingId) {
        GeneralMeeting__c meeting = [SELECT Id, Name, MeetingDate__c, ResponseDeadline__c FROM GeneralMeeting__c WHERE Id = :meetingId WITH SECURITY_ENFORCED];
        List<FormTemplate__c> templates = [SELECT Id FROM FormTemplate__c WHERE GeneralMeeting__c = :meetingId LIMIT 1];
        if (templates.isEmpty()) return;

        Set<Id> respondedMemberIds = new Set<Id>();
        for (FormResponse__c r : [SELECT Member__c FROM FormResponse__c WHERE FormTemplate__c = :templates[0].Id]) {
            if (r.Member__c != null) respondedMemberIds.add(r.Member__c);
        }

        List<Member__c> unreplied = [
            SELECT Id, LastName__c, FirstName__c, Email__c
            FROM Member__c
            WHERE MemberStatus__c IN ('正会員', '準会員')
            AND   Id NOT IN :respondedMemberIds
            WITH SECURITY_ENFORCED
            LIMIT 500
        ];

        String subject = '【催促】' + meeting.Name + ' 出欠のご回答をお願いします';
        String deadline = meeting.ResponseDeadline__c != null ? meeting.ResponseDeadline__c.format('yyyy/MM/dd HH:mm') : '—';

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Member__c m : unreplied) {
            if (String.isBlank(m.Email__c)) continue;
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ m.Email__c });
            email.setSubject(subject);
            email.setPlainTextBody(
                m.LastName__c + ' ' + m.FirstName__c + ' 様\n\n'
                + meeting.Name + ' の出欠確認フォームへのご回答がまだのようです。\n'
                + '回答期限: ' + deadline + '\n\n'
                + '会員ポータルよりご回答ください。'
            );
            email.setSaveAsActivity(false);
            emails.add(email);
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
        update new GeneralMeeting__c(Id = meetingId, ReminderSentAt__c = Datetime.now());
    }

    private static void updateMeetingCounts(Id meetingId) {
        List<FormTemplate__c> templates = [SELECT Id FROM FormTemplate__c WHERE GeneralMeeting__c = :meetingId LIMIT 1];
        if (templates.isEmpty()) return;
        Integer attend = [SELECT COUNT() FROM FormResponse__c WHERE FormTemplate__c = :templates[0].Id AND AttendanceChoice__c = '出席'];
        Integer proxy  = [SELECT COUNT() FROM FormResponse__c WHERE FormTemplate__c = :templates[0].Id AND AttendanceChoice__c LIKE '%委任状%'];
        Integer absent = [SELECT COUNT() FROM FormResponse__c WHERE FormTemplate__c = :templates[0].Id AND AttendanceChoice__c LIKE '%欠席%'];
        update new GeneralMeeting__c(Id = meetingId, AttendanceCount__c = attend, ProxyCount__c = proxy, AbsenceCount__c = absent);
    }

    private static String buildDefaultConfirmationBody(Member__c member, String choice, Id meetingId) {
        return member.LastName__c + ' ' + member.FirstName__c + ' 様\n\n'
             + 'ご回答いただきありがとうございます。\n'
             + '回答内容: ' + choice + '\n\n'
             + '詳細は会員ポータルよりご確認ください。';
    }

    private static void sendConfirmation(String toEmail, String subject, String body) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }
}
