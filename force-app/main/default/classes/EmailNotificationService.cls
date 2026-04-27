public with sharing class EmailNotificationService {

    public static void sendMemberRegistrationConfirmation(Id memberId) {
        Member__c member = queryMember(memberId);
        String body = buildRegistrationConfirmationBody(member);
        sendEmail(
            member.Email__c,
            '【会員登録受付】お申し込みありがとうございます',
            body
        );
    }

    public static void sendMemberApprovalNotification(Id memberId) {
        Member__c member = queryMember(memberId);
        String body = '【' + member.LastName__c + ' ' + member.FirstName__c + ' 様】\n\n'
            + '会員登録が承認されました。正会員としてポータルをご利用いただけます。\n\n'
            + '会員番号: ' + member.Name + '\n'
            + '会員種別: ' + member.MemberType__c + '\n\n'
            + 'ポータルサイトにログインしてサービスをご利用ください。\n\n'
            + '※本メールはシステムから自動送信されています。';
        sendEmail(member.Email__c, '【会員登録完了】正会員として承認されました', body);
    }

    public static void sendPaymentCreatedNotification(Id paymentId) {
        Payment__c payment = [
            SELECT Id, Name, Member__r.Email__c, Member__r.LastName__c, Member__r.FirstName__c,
                   PaymentType__c, Amount__c, DueDate__c, Description__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        String body = '【' + payment.Member__r.LastName__c + ' ' + payment.Member__r.FirstName__c + ' 様】\n\n'
            + '以下の支払いが発生しました。期限までにお支払いください。\n\n'
            + '支払い番号: ' + payment.Name + '\n'
            + '種別: ' + payment.PaymentType__c + '\n'
            + '金額: ¥' + String.valueOf(payment.Amount__c.longValue()) + '\n'
            + '支払期限: ' + payment.DueDate__c.format() + '\n'
            + (String.isNotBlank(payment.Description__c) ? '摘要: ' + payment.Description__c + '\n' : '')
            + '\nポータルサイトよりお支払い手続きをお願いします。';

        sendEmail(payment.Member__r.Email__c, '【支払いのご案内】' + payment.PaymentType__c, body);
    }

    public static void sendPaymentConfirmation(Id paymentId) {
        Payment__c payment = [
            SELECT Id, Name, Member__r.Email__c, Member__r.LastName__c, Member__r.FirstName__c,
                   PaymentType__c, Amount__c, PaymentDate__c, PaymentMethod__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        String body = '【' + payment.Member__r.LastName__c + ' ' + payment.Member__r.FirstName__c + ' 様】\n\n'
            + 'お支払いを確認しました。ありがとうございます。\n\n'
            + '支払い番号: ' + payment.Name + '\n'
            + '種別: ' + payment.PaymentType__c + '\n'
            + '金額: ¥' + String.valueOf(payment.Amount__c.longValue()) + '\n'
            + '支払日: ' + payment.PaymentDate__c.format() + '\n'
            + '支払方法: ' + payment.PaymentMethod__c + '\n\n'
            + '領収書の発行はポータルサイトよりご申請ください。';

        sendEmail(payment.Member__r.Email__c, '【支払い完了】' + payment.PaymentType__c + ' のお支払いを確認しました', body);
    }

    public static void sendReceiptNotification(Id paymentId) {
        Payment__c payment = [
            SELECT Id, Name, ReceiptNumber__c, Member__r.Email__c,
                   Member__r.LastName__c, Member__r.FirstName__c,
                   Amount__c, PaymentDate__c, Description__c
            FROM Payment__c WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];

        String body = '【' + payment.Member__r.LastName__c + ' ' + payment.Member__r.FirstName__c + ' 様】\n\n'
            + '領収書を発行しました。ポータルサイトよりダウンロードしてください。\n\n'
            + '領収書番号: ' + payment.ReceiptNumber__c + '\n'
            + '金額: ¥' + String.valueOf(payment.Amount__c.longValue()) + '\n'
            + '支払日: ' + payment.PaymentDate__c.format();

        sendEmail(payment.Member__r.Email__c, '【領収書発行】領収書が発行されました', body);
    }

    public static void sendDonationConfirmation(Id donationId) {
        Donation__c don = [
            SELECT Id, Name, DonorEmail__c, DonorName__c, Amount__c,
                   Purpose__c, DonationDate__c, ReceiptNumber__c, IsAnonymous__c
            FROM Donation__c WHERE Id = :donationId WITH SECURITY_ENFORCED
        ];

        if (don.IsAnonymous__c || String.isBlank(don.DonorEmail__c)) return;

        String body = '【' + don.DonorName__c + ' 様】\n\n'
            + 'ご寄付をいただき、誠にありがとうございます。\n\n'
            + '寄付番号: ' + don.Name + '\n'
            + '寄付金額: ¥' + String.valueOf(don.Amount__c.longValue()) + '\n'
            + '用途: ' + don.Purpose__c + '\n'
            + '受付日: ' + don.DonationDate__c.format() + '\n\n'
            + '領収書番号: ' + don.ReceiptNumber__c + '\n'
            + '税控除証明書が必要な場合はポータルよりお申し込みください。';

        sendEmail(don.DonorEmail__c, '【寄付受付確認】ご寄付ありがとうございます', body);
    }

    public static void sendInquiryAutoReply(Id inquiryId) {
        SupportInquiry__c inq = [
            SELECT Id, Name, ContactEmail__c, ContactName__c, Subject__c
            FROM SupportInquiry__c WHERE Id = :inquiryId WITH SECURITY_ENFORCED
        ];

        String body = '【' + inq.ContactName__c + ' 様】\n\n'
            + 'お問い合わせを受け付けました。\n\n'
            + '問い合わせ番号: ' + inq.Name + '\n'
            + '件名: ' + inq.Subject__c + '\n\n'
            + '内容を確認の上、担当者よりご連絡いたします。\n'
            + '（通常3営業日以内に回答いたします）\n\n'
            + '※本メールはシステムから自動送信されています。返信はできません。';

        sendEmail(inq.ContactEmail__c, '【自動返信】お問い合わせを受け付けました [' + inq.Name + ']', body);
    }

    public static void sendPersonnelChangeNotification(Id personnelChangeId) {
        PersonnelChange__c change = [
            SELECT Id, Name, Member__r.Email__c, Member__r.LastName__c, Member__r.FirstName__c,
                   ChangeType__c, FromUnit__r.Name, ToUnit__r.Name,
                   FromPosition__c, ToPosition__c, EffectiveDate__c, NotifyEmail__c
            FROM PersonnelChange__c WHERE Id = :personnelChangeId WITH SECURITY_ENFORCED
        ];

        if (!change.NotifyEmail__c) return;

        String body = '【' + change.Member__r.LastName__c + ' ' + change.Member__r.FirstName__c + ' 様】\n\n'
            + '以下の人事異動が登録されました。\n\n'
            + '異動種別: ' + change.ChangeType__c + '\n'
            + '発令日: ' + change.EffectiveDate__c.format() + '\n'
            + '異動前: ' + (change.FromUnit__r != null ? change.FromUnit__r.Name : '―')
                + (String.isNotBlank(change.FromPosition__c) ? ' / ' + change.FromPosition__c : '') + '\n'
            + '異動後: ' + (change.ToUnit__r != null ? change.ToUnit__r.Name : '―')
                + (String.isNotBlank(change.ToPosition__c) ? ' / ' + change.ToPosition__c : '') + '\n\n'
            + 'ご不明な点はポータルよりお問い合わせください。';

        sendEmail(change.Member__r.Email__c, '【人事異動のご連絡】' + change.ChangeType__c, body);
    }

    public static void sendAdminAlert(String subject, String body) {
        PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();
        String adminEmail = config?.FromEmailAddress__c;
        if (String.isBlank(adminEmail)) return;
        sendEmail(adminEmail, subject, body);
    }

    private static void sendEmail(String toAddress, String subject, String body) {
        if (String.isBlank(toAddress)) return;

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toAddress });
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSaveAsActivity(false);

        PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();
        if (String.isNotBlank(config?.FromEmailAddress__c)) {
            email.setSenderDisplayName(config.OrganizationName__c);
        }

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static Member__c queryMember(Id memberId) {
        return [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c,
                   MemberType__c, MemberStatus__c
            FROM Member__c WHERE Id = :memberId WITH SECURITY_ENFORCED
        ];
    }
}
