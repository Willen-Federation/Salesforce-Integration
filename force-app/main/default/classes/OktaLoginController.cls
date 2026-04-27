/**
 * ポータルログイン補助コントローラー。
 * OIDC 認証プロバイダーの URL 取得と、ログアウト・セッション確認を提供する。
 */
public with sharing class OktaLoginController {

    private static final String AUTH_PROVIDER_URL_SUFFIX = 'okta'; // セットアップで設定した URL サフィックスと一致させる

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getLoginConfig() {
        PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String oidcUrl = baseUrl + '/services/auth/sso/' + AUTH_PROVIDER_URL_SUFFIX;
        String startUrl = String.isNotBlank(config?.PortalBaseUrl__c) ? config.PortalBaseUrl__c : '/';

        return new Map<String, Object>{
            'oidcLoginUrl'  => oidcUrl + '?startURL=' + EncodingUtil.urlEncode(startUrl, 'UTF-8'),
            'organizationName' => config?.OrganizationName__c ?? '',
            'isOktaConfigured' => String.isNotBlank(config?.OktaDomain__c)
        };
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getCurrentUser() {
        try {
            Id userId = UserInfo.getUserId();
            if (userId == null) return new Map<String, Object>{ 'isLoggedIn' => false };

            String email = UserInfo.getUserEmail();
            List<Member__c> members = [
                SELECT Id, Name, LastName__c, FirstName__c, MemberType__c, MemberStatus__c, OktaUserId__c
                FROM Member__c
                WHERE Email__c = :email
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            Map<String, Object> result = new Map<String, Object>{
                'isLoggedIn' => true,
                'userId'     => userId,
                'userName'   => UserInfo.getName(),
                'email'      => email
            };

            if (!members.isEmpty()) {
                Member__c m = members[0];
                result.put('memberId',     m.Id);
                result.put('memberNumber', m.Name);
                result.put('fullName',     (m.LastName__c ?? '') + ' ' + (m.FirstName__c ?? ''));
                result.put('memberType',   m.MemberType__c ?? '');
                result.put('memberStatus', m.MemberStatus__c ?? '');
            }
            return result;
        } catch (Exception e) {
            return new Map<String, Object>{ 'isLoggedIn' => false };
        }
    }
}
