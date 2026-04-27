/**
 * Okta OIDC 認証プロバイダー用のユーザー登録ハンドラー。
 *
 * Salesforce セットアップ手順:
 *   1. 設定 > ID > 認証プロバイダー > 新規 > OpenID Connect
 *   2. コンシューマーキー・シークレット: Okta アプリの Client ID / Secret
 *   3. 承認エンドポイント: https://<okta-domain>/oauth2/default/v1/authorize
 *   4. トークンエンドポイント:   https://<okta-domain>/oauth2/default/v1/token
 *   5. ユーザー情報エンドポイント: https://<okta-domain>/oauth2/default/v1/userinfo
 *   6. デフォルトスコープ: openid profile email
 *   7. 登録ハンドラー: OktaOidcRegistrationHandler
 *   8. ポータルURL に /services/auth/sso/<AuthProvider_URL_Suffix> を追加
 *
 * Experience Cloud（旧 Community）設定:
 *   - ポータルのログインページに「Oktaでログイン」ボタンを表示するには
 *     Community > Administration > Login & Registration で認証プロバイダーを有効化
 */
global class OktaOidcRegistrationHandler implements Auth.RegistrationHandler {

    global Auth.UserData generateUserData(
            String identifier, String firstName, String lastName,
            String email, String link, String username,
            String locale, Map<String, String> attrMap, List<String> selectedPermissions,
            Auth.AuthToken authToken) {

        return new Auth.UserData(
            identifier,   // identifier (sub claim)
            firstName,
            lastName,
            firstName + ' ' + lastName,
            email,
            null,         // existing user
            username ?? email,
            locale,
            'okta_oidc',  // provider
            null,
            attrMap
        );
    }

    global User createUser(Id portalId, Auth.UserData data) {
        // 既存 Member__c を検索して紐付け
        String email = data.email;
        List<Member__c> members = [
            SELECT Id, OktaUserId__c, Email__c, LastName__c, FirstName__c, MemberStatus__c
            FROM Member__c
            WHERE Email__c = :email
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // Member__c に OktaUserId を保存（初回のみ）
        if (!members.isEmpty() && String.isBlank(members[0].OktaUserId__c)) {
            Member__c m = new Member__c(Id = members[0].Id, OktaUserId__c = data.identifier);
            Database.update(m, false);
        }

        // Experience Cloud ゲストサイトではなく認証済みユーザーとして既存ポータルユーザーを返す
        List<User> existingUsers = [
            SELECT Id FROM User
            WHERE Email = :email AND IsActive = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!existingUsers.isEmpty()) return existingUsers[0];

        // 新規ポータルユーザーを作成（Experience Cloud 用プロファイル）
        User u = new User();
        u.Username       = email + '.portal';
        u.Email          = email;
        u.LastName        = String.isNotBlank(data.lastName)  ? data.lastName  : 'ユーザー';
        u.FirstName       = String.isNotBlank(data.firstName) ? data.firstName : '';
        u.Alias           = buildAlias(email);
        u.CommunityNickname = buildNickname(email);
        u.TimeZoneSidKey   = 'Asia/Tokyo';
        u.LocaleSidKey     = 'ja_JP';
        u.LanguageLocaleKey = 'ja';
        u.EmailEncodingKey  = 'UTF-8';

        // Experience Cloud ポータルプロファイル（環境に合わせて変更）
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        u.ProfileId = p.Id;

        return u;
    }

    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        User u = new User(Id = userId, Email = data.email);
        if (String.isNotBlank(data.lastName))  u.LastName  = data.lastName;
        if (String.isNotBlank(data.firstName)) u.FirstName = data.firstName;
        update u;

        // Member__c の OktaUserId を最新に保つ
        List<Member__c> members = [
            SELECT Id, OktaUserId__c FROM Member__c
            WHERE Email__c = :data.email WITH SECURITY_ENFORCED LIMIT 1
        ];
        if (!members.isEmpty() && String.isBlank(members[0].OktaUserId__c)) {
            Database.update(
                new Member__c(Id = members[0].Id, OktaUserId__c = data.identifier),
                false
            );
        }
    }

    // ----------------------------------------------------------------
    // Private helpers
    // ----------------------------------------------------------------

    private static String buildAlias(String email) {
        String local = email.split('@')[0];
        return local.length() > 8 ? local.substring(0, 8) : local;
    }

    private static String buildNickname(String email) {
        String base = email.split('@')[0].replaceAll('[^a-zA-Z0-9]', '');
        return (base.length() > 20 ? base.substring(0, 20) : base)
             + String.valueOf(Math.abs(Math.mod(email.hashCode(), 9999)));
    }
}
