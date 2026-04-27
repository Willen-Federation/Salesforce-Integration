/**
 * 外部ポータル会員向けのマイページコントローラー。
 *
 * Experience Cloud（コミュニティ）上の認証済みユーザーが呼び出す。
 * UserInfo.getUserId() から関連する Member__c を取得する。
 *
 * トークンベースのワンタイムアクセス（メールリンク）もサポート。
 */
public with sharing class PortalMemberController {

    // ----------------------------------------------------------------
    // マイページデータ取得
    // ----------------------------------------------------------------

    /**
     * 現在ログイン中のユーザーに関連する会員情報を返す。
     * Experience Cloud の認証済みユーザーを前提とする。
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMyProfile() {
        Id userId = UserInfo.getUserId();
        List<Member__c> members = [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c,
                   MemberStatus__c, MemberType__c, JoinDate__c,
                   Organization__c, Department__c, Position__c, Phone__c,
                   IsPortalEnabled__c
            FROM Member__c
            WHERE Email__c = :UserInfo.getUserEmail()
            AND IsPortalEnabled__c = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (members.isEmpty()) {
            throw new AuraHandledException('会員情報が見つかりません。');
        }

        Member__c m = members[0];
        return new Map<String, Object>{
            'id'             => m.Id,
            'memberNumber'   => m.Name,
            'lastName'       => m.LastName__c,
            'firstName'      => m.FirstName__c,
            'email'          => m.Email__c,
            'memberStatus'   => m.MemberStatus__c,
            'memberType'     => m.MemberType__c,
            'joinDate'       => m.JoinDate__c,
            'organization'   => m.Organization__c,
            'department'     => m.Department__c,
            'position'       => m.Position__c,
            'phone'          => m.Phone__c
        };
    }

    /**
     * 現在ログイン中の会員の支払い一覧を返す。
     */
    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getMyPayments() {
        List<Member__c> members = [
            SELECT Id FROM Member__c
            WHERE Email__c = :UserInfo.getUserEmail()
            AND IsPortalEnabled__c = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (members.isEmpty()) return new List<Payment__c>();

        return [
            SELECT Id, Name, PaymentType__c, Amount__c, BaseAmount__c,
                   PlatformFee__c, PaymentMethodFee__c,
                   PaymentStatus__c, DueDate__c, PaymentDate__c,
                   PaymentMethod__c, TransactionId__c,
                   ReceiptIssued__c, ReceiptIssuedDate__c, ReceiptNumber__c,
                   Description__c, FiscalYear__c,
                   ReviewRequired__c, ReviewStatus__c,
                   AllowedPaymentMethods__c, SelectedMethodKey__c,
                   RecurringPlan__c, RecurringPlan__r.PlanName__c
            FROM Payment__c
            WHERE Member__c = :members[0].Id
            WITH SECURITY_ENFORCED
            ORDER BY DueDate__c DESC
            LIMIT 100
        ];
    }

    /**
     * 現在ログイン中の会員の定期支払いプラン一覧を返す。
     */
    @AuraEnabled(cacheable=true)
    public static List<RecurringPaymentPlan__c> getMyRecurringPlans() {
        List<Member__c> members = [
            SELECT Id FROM Member__c
            WHERE Email__c = :UserInfo.getUserEmail()
            AND IsPortalEnabled__c = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (members.isEmpty()) return new List<RecurringPaymentPlan__c>();

        return [
            SELECT Id, Name, PlanName__c, PaymentType__c, BaseAmount__c,
                   Frequency__c, StartDate__c, EndDate__c, NextDueDate__c,
                   IsActive__c, Description__c, TotalGenerated__c, LastGeneratedDate__c
            FROM RecurringPaymentPlan__c
            WHERE Member__c = :members[0].Id
            WITH SECURITY_ENFORCED
            ORDER BY StartDate__c DESC
        ];
    }

    // ----------------------------------------------------------------
    // トークンベースアクセス（メールリンク）
    // ----------------------------------------------------------------

    /**
     * 会員にポータルアクセストークンを発行（管理者が呼び出す）。
     * 発行後、メールでリンクを送信する。
     */
    @AuraEnabled
    public static void generateAndSendPortalToken(Id memberId) {
        Member__c member = [
            SELECT Id, Email__c, LastName__c, FirstName__c, IsPortalEnabled__c
            FROM Member__c WHERE Id = :memberId WITH SECURITY_ENFORCED
        ];

        if (!member.IsPortalEnabled__c) {
            throw new AuraHandledException('このアカウントのポータルアクセスは無効です。');
        }

        String token = generateToken();
        update new Member__c(
            Id                   = memberId,
            PortalAccessToken__c = token,
            PortalTokenExpiry__c = System.now().addHours(72)
        );

        EmailNotificationService.sendPortalAccessLinkNotification(memberId, token);
    }

    /**
     * トークンを検証し、有効なら会員情報を返す（ゲストアクセス用）。
     */
    @AuraEnabled
    public static Map<String, Object> validatePortalToken(String token) {
        if (String.isBlank(token)) {
            throw new AuraHandledException('トークンが指定されていません。');
        }

        List<Member__c> members = [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c,
                   MemberStatus__c, MemberType__c, JoinDate__c,
                   PortalTokenExpiry__c, IsPortalEnabled__c
            FROM Member__c
            WHERE PortalAccessToken__c = :token
            AND IsPortalEnabled__c = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (members.isEmpty()) {
            throw new AuraHandledException('無効なアクセストークンです。');
        }
        Member__c m = members[0];
        if (m.PortalTokenExpiry__c < System.now()) {
            throw new AuraHandledException('アクセストークンの有効期限が切れています。再度リンクを発行してください。');
        }

        return new Map<String, Object>{
            'memberId'     => m.Id,
            'memberNumber' => m.Name,
            'lastName'     => m.LastName__c,
            'firstName'    => m.FirstName__c,
            'email'        => m.Email__c,
            'memberStatus' => m.MemberStatus__c,
            'memberType'   => m.MemberType__c,
            'joinDate'     => m.JoinDate__c
        };
    }

    // ----------------------------------------------------------------
    // Private
    // ----------------------------------------------------------------

    private static String generateToken() {
        Blob b = Crypto.generateAesKey(128);
        return EncodingUtil.convertToHex(b).substring(0, 40);
    }
}
