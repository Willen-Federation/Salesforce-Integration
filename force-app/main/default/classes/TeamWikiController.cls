public with sharing class TeamWikiController {

    @AuraEnabled(cacheable=true)
    public static List<TeamWiki__c> getWikisByOrgUnit(Id orgUnitId) {
        return [
            SELECT Id, Name, Description__c, IsActive__c, AccessLevel__c, EditLevel__c, HomePageContent__c,
                   OrgUnit__r.Name, OrgUnit__r.UnitCode__c
            FROM TeamWiki__c
            WHERE OrgUnit__c = :orgUnitId
            AND   IsActive__c = true
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<TeamWiki__c> getAccessibleWikis() {
        return [
            SELECT Id, Name, Description__c, AccessLevel__c, EditLevel__c,
                   OrgUnit__r.Name, OrgUnit__r.UnitCode__c
            FROM TeamWiki__c
            WHERE IsActive__c = true
            AND   AccessLevel__c IN ('全会員', '外部公開')
            WITH SECURITY_ENFORCED
            ORDER BY OrgUnit__r.Name, Name
        ];
    }

    @AuraEnabled
    public static Id createWiki(String wikiName, Id orgUnitId, String description,
                                String accessLevel, String editLevel) {
        if (!Schema.sObjectType.TeamWiki__c.isCreateable()) {
            throw new AuraHandledException('Wiki作成権限がありません。');
        }
        TeamWiki__c wiki = new TeamWiki__c(
            Name          = wikiName,
            OrgUnit__c    = orgUnitId,
            Description__c = description,
            AccessLevel__c = accessLevel,
            EditLevel__c   = editLevel,
            IsActive__c    = true
        );
        insert wiki;
        return wiki.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<WikiPage__c> getWikiPages(Id wikiId) {
        return [
            SELECT Id, Name, Slug__c, PageStatus__c, Tags__c, SortOrder__c,
                   ParentPage__c, ParentPage__r.Name, ViewCount__c, CurrentVersion__c,
                   LastEditedBy__r.Name, LastModifiedDate
            FROM WikiPage__c
            WHERE TeamWiki__c = :wikiId
            AND   PageStatus__c = '公開'
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder__c ASC NULLS LAST, Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static WikiPage__c getWikiPageDetail(Id pageId) {
        WikiPage__c page = [
            SELECT Id, Name, Content__c, Slug__c, PageStatus__c, Tags__c,
                   SortOrder__c, ViewCount__c, CurrentVersion__c,
                   LastEditedBy__r.Name, LastModifiedDate,
                   TeamWiki__r.Name, TeamWiki__r.EditLevel__c,
                   TeamWiki__r.OrgUnit__c, TeamWiki__r.OrgUnit__r.Name
            FROM WikiPage__c
            WHERE Id = :pageId
            WITH SECURITY_ENFORCED
        ];
        // Increment view count (best-effort)
        try {
            WikiPage__c upd = new WikiPage__c(Id = pageId, ViewCount__c = (page.ViewCount__c == null ? 1 : page.ViewCount__c + 1));
            update upd;
        } catch (Exception e) { /* non-critical */ }
        return page;
    }

    @AuraEnabled
    public static Id savePage(Map<String, Object> pageData) {
        Id pageId = pageData.get('id') != null ? (Id) pageData.get('id') : null;
        String content = (String) pageData.get('content');
        String editSummary = (String) pageData.get('editSummary');

        if (pageId == null) {
            if (!Schema.sObjectType.WikiPage__c.isCreateable()) {
                throw new AuraHandledException('Wikiページ作成権限がありません。');
            }
            WikiPage__c page = new WikiPage__c(
                TeamWiki__c    = (Id) pageData.get('wikiId'),
                Name           = (String) pageData.get('title'),
                Content__c     = content,
                Slug__c        = buildSlug((String) pageData.get('title')),
                PageStatus__c  = (String) pageData.get('pageStatus') ?? '下書き',
                Tags__c        = (String) pageData.get('tags'),
                SortOrder__c   = 0,
                CurrentVersion__c = 1,
                LastEditedBy__c = UserInfo.getUserId()
            );
            if (pageData.get('parentPageId') != null) {
                page.ParentPage__c = (Id) pageData.get('parentPageId');
            }
            insert page;
            saveVersion(page.Id, 1, content, editSummary);
            return page.Id;
        } else {
            WikiPage__c existing = [SELECT Id, CurrentVersion__c, Content__c FROM WikiPage__c WHERE Id = :pageId WITH SECURITY_ENFORCED];
            Integer newVersion = Integer.valueOf(existing.CurrentVersion__c == null ? 1 : existing.CurrentVersion__c) + 1;

            WikiPage__c upd = new WikiPage__c(
                Id               = pageId,
                Content__c       = content,
                CurrentVersion__c = newVersion,
                LastEditedBy__c  = UserInfo.getUserId()
            );
            if (pageData.get('title') != null)      upd.Name          = (String) pageData.get('title');
            if (pageData.get('pageStatus') != null)  upd.PageStatus__c = (String) pageData.get('pageStatus');
            if (pageData.get('tags') != null)        upd.Tags__c       = (String) pageData.get('tags');
            update upd;
            saveVersion(pageId, newVersion, content, editSummary);
            return pageId;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WikiPageVersion__c> getPageVersions(Id pageId) {
        return [
            SELECT Id, Name, VersionNumber__c, EditSummary__c, EditedBy__r.Name, CreatedDate
            FROM WikiPageVersion__c
            WHERE WikiPage__c = :pageId
            WITH SECURITY_ENFORCED
            ORDER BY VersionNumber__c DESC
            LIMIT 50
        ];
    }

    @AuraEnabled
    public static void deletePage(Id pageId) {
        if (!Schema.sObjectType.WikiPage__c.isDeletable()) {
            throw new AuraHandledException('Wikiページ削除権限がありません。');
        }
        WikiPage__c page = new WikiPage__c(Id = pageId, PageStatus__c = 'アーカイブ');
        update page;
    }

    private static void saveVersion(Id pageId, Integer versionNum, String content, String summary) {
        WikiPageVersion__c ver = new WikiPageVersion__c(
            WikiPage__c     = pageId,
            VersionNumber__c = versionNum,
            Content__c      = content,
            EditSummary__c  = String.isNotBlank(summary) ? summary : '編集',
            EditedBy__c     = UserInfo.getUserId()
        );
        insert ver;
    }

    private static String buildSlug(String title) {
        if (String.isBlank(title)) return 'page';
        return title.toLowerCase().replaceAll('[^a-z0-9\\u3040-\\u9fff]', '-').replaceAll('-+', '-').left(100);
    }
}
