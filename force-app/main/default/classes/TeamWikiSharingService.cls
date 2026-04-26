public without sharing class TeamWikiSharingService {

    private static final String ROW_CAUSE_ORG_MEMBER = Schema.TeamWiki__Share.RowCause.OrgMember__c;

    /**
     * TeamWiki__c.AccessLevel__c = '組織メンバーのみ' のWikiに対して、
     * 該当OrgUnit__cに所属するMemberのUserへ読み取り共有を付与する。
     * EditLevel__c = '組織メンバーのみ' の場合はEdit権限も付与。
     * TeamWikiTrigger / batchから呼び出す。
     */
    @Future
    public static void grantOrgMemberAccess(Set<Id> wikiIds) {
        if (wikiIds == null || wikiIds.isEmpty()) return;

        List<TeamWiki__c> wikis = [
            SELECT Id, OrgUnit__c, AccessLevel__c, EditLevel__c
            FROM TeamWiki__c
            WHERE Id IN :wikiIds AND AccessLevel__c = '組織メンバーのみ'
            WITH SECURITY_ENFORCED
        ];
        if (wikis.isEmpty()) return;

        Set<Id> orgUnitIds = new Set<Id>();
        for (TeamWiki__c w : wikis) {
            if (w.OrgUnit__c != null) orgUnitIds.add(w.OrgUnit__c);
        }

        Map<Id, List<Id>> orgUnitToUsers = buildOrgUnitUserMap(orgUnitIds);

        // 既存の Apex 共有レコードを一旦削除して再発行
        delete [SELECT Id FROM TeamWiki__Share WHERE RowCause = :ROW_CAUSE_ORG_MEMBER AND ParentId IN :wikiIds];

        List<TeamWiki__Share> shares = new List<TeamWiki__Share>();
        for (TeamWiki__c w : wikis) {
            if (w.OrgUnit__c == null) continue;
            List<Id> users = orgUnitToUsers.get(w.OrgUnit__c);
            if (users == null) continue;
            String access = (w.EditLevel__c == '組織メンバーのみ') ? 'Edit' : 'Read';
            for (Id userId : users) {
                shares.add(new TeamWiki__Share(
                    ParentId    = w.Id,
                    UserOrGroupId = userId,
                    AccessLevel = access,
                    RowCause    = ROW_CAUSE_ORG_MEMBER
                ));
            }
        }
        if (!shares.isEmpty()) {
            Database.insert(shares, false);
        }
    }

    /**
     * OrgUnit__c の所属会員 (Member__c.OrgUnit__c) から UserId を逆引きする。
     */
    private static Map<Id, List<Id>> buildOrgUnitUserMap(Set<Id> orgUnitIds) {
        Map<Id, List<Id>> result = new Map<Id, List<Id>>();
        for (Member__c m : [
            SELECT Id, OrgUnit__c, UserId__c
            FROM Member__c
            WHERE OrgUnit__c IN :orgUnitIds AND UserId__c != null
            WITH SECURITY_ENFORCED
        ]) {
            if (!result.containsKey(m.OrgUnit__c)) result.put(m.OrgUnit__c, new List<Id>());
            result.get(m.OrgUnit__c).add(m.UserId__c);
        }
        return result;
    }

    /**
     * Wiki の AccessLevel__c / EditLevel__c が変更されたとき、
     * 共有レコードを再計算するエントリポイント。
     */
    public static void recalculateSharing(Set<Id> wikiIds) {
        grantOrgMemberAccess(wikiIds);
    }
}
