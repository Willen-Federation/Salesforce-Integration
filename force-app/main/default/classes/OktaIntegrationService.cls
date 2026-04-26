/**
 * Okta SAML + SCIM自動プロビジョニング連携サービス
 *
 * Salesforce側の設定:
 *   - SSO設定: 管理 > ID > シングルサインオン設定 で SAML IdP としてOkta を登録
 *   - JIT(ジャストインタイム)プロビジョニング: SAML アサーション属性でユーザを自動作成
 *   - SCIM: OktaのSalesforce統合でSCIMv2エンドポイントを有効化
 *
 * このクラスはOkta Webhookや手動同期トリガーから呼び出します。
 */
public with sharing class OktaIntegrationService {

    private static final String NAMED_CREDENTIAL = 'callout:OktaAPI';

    // JITプロビジョニング: SAMLアサーションからMember__cを作成/更新
    public static void syncMemberFromSamlAssertion(Map<String, String> samlAttributes) {
        String email      = samlAttributes.get('email');
        String oktaUserId = samlAttributes.get('sub');
        String firstName  = samlAttributes.get('given_name');
        String lastName   = samlAttributes.get('family_name');
        String dept       = samlAttributes.get('department');
        String orgUnit    = samlAttributes.get('orgUnit');

        if (String.isBlank(email) || String.isBlank(oktaUserId)) return;

        List<Member__c> existing = [
            SELECT Id, OktaUserId__c, MemberStatus__c
            FROM Member__c WHERE Email__c = :email WITH SECURITY_ENFORCED LIMIT 1
        ];

        if (existing.isEmpty()) {
            Member__c member = new Member__c(
                Email__c        = email,
                OktaUserId__c   = oktaUserId,
                FirstName__c    = firstName,
                LastName__c     = lastName,
                Department__c   = dept,
                MemberStatus__c = '申請中',
                JoinDate__c     = Date.today()
            );
            insert member;
        } else {
            Member__c member = existing[0];
            member.OktaUserId__c = oktaUserId;
            if (String.isNotBlank(dept)) member.Department__c = dept;
            update member;
        }
    }

    // OktaグループとSalesforce OrgUnit__cの同期
    @Future(callout=true)
    public static void syncGroupMembership(Id memberId, String oktaGroupId, Boolean addToGroup) {
        Member__c member = [
            SELECT Id, OktaUserId__c FROM Member__c
            WHERE Id = :memberId WITH SECURITY_ENFORCED
        ];

        if (String.isBlank(member.OktaUserId__c) || String.isBlank(oktaGroupId)) return;

        String endpoint = NAMED_CREDENTIAL + '/api/v1/groups/' + oktaGroupId
                        + '/users/' + member.OktaUserId__c;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(addToGroup ? 'PUT' : 'DELETE');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(15000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 400) {
            System.debug(LoggingLevel.ERROR,
                'Okta group sync error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    // Oktaユーザーの有効化/無効化（退会処理と連動）
    @Future(callout=true)
    public static void deactivateOktaUser(String oktaUserId) {
        if (String.isBlank(oktaUserId)) return;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/v1/users/' + oktaUserId + '/lifecycle/deactivate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(15000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 400) {
            System.debug(LoggingLevel.ERROR,
                'Okta deactivate error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    // Oktaユーザープロファイルの更新（会員情報変更時）
    @Future(callout=true)
    public static void updateOktaUserProfile(String oktaUserId, String firstName,
                                              String lastName, String email, String department) {
        if (String.isBlank(oktaUserId)) return;

        Map<String, Object> profile = new Map<String, Object>{
            'firstName'  => firstName,
            'lastName'   => lastName,
            'email'      => email,
            'department' => department
        };
        Map<String, Object> body = new Map<String, Object>{ 'profile' => profile };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/v1/users/' + oktaUserId);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(body));
        req.setTimeout(15000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 400) {
            System.debug(LoggingLevel.ERROR,
                'Okta profile update error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    // 人事異動時にOktaグループを更新
    public static void processPersonnelChangeInOkta(Id personnelChangeId) {
        PersonnelChange__c change = [
            SELECT Id, Member__c, Member__r.OktaUserId__c,
                   FromUnit__r.OktaGroupId__c, ToUnit__r.OktaGroupId__c,
                   ApprovalStatus__c
            FROM PersonnelChange__c
            WHERE Id = :personnelChangeId WITH SECURITY_ENFORCED
        ];

        if (change.ApprovalStatus__c != '承認済み') return;
        if (String.isBlank(change.Member__r?.OktaUserId__c)) return;

        // 旧グループから削除
        if (String.isNotBlank(change.FromUnit__r?.OktaGroupId__c)) {
            syncGroupMembership(change.Member__c, change.FromUnit__r.OktaGroupId__c, false);
        }
        // 新グループへ追加
        if (String.isNotBlank(change.ToUnit__r?.OktaGroupId__c)) {
            syncGroupMembership(change.Member__c, change.ToUnit__r.OktaGroupId__c, true);
        }

        PersonnelChange__c upd = new PersonnelChange__c(
            Id = personnelChangeId,
            OktaGroupUpdated__c = true
        );
        Database.update(upd, false);
    }
}
