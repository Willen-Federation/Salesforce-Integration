# チームWiki

組織単位（OrgUnit__c）ごとのナレッジベースを提供する機能です。所属組織に応じたアクセス制御と、バージョン履歴による変更追跡をサポートします。

---

## 概要

チームWikiは、各組織が独自のドキュメントを作成・管理するためのナレッジベース機能です。ページはMarkdown（またはプレーンテキスト）で記述でき、階層構造・タグ・バージョン履歴をサポートします。

---

## データモデル

```
TeamWiki__c（Wikiスペース）
    │  OWD: Private
    │  AccessLevel__c, EditLevel__c で共有範囲を制御
    │
    └─── WikiPage__c（ページ）
              │  共有設定: ControlledByParent
              │  ParentPage__c 自己参照で階層構造を実現
              │
              └─── WikiPageVersion__c（バージョン履歴）
                        共有設定: ControlledByParent
                        追記専用（削除・更新禁止）
```

### TeamWiki__c 主要項目

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `Name` | Text | Wikiスペース名 |
| `OrgUnit__c` | Lookup | 所属組織単位 |
| `AccessLevel__c` | Picklist | アクセス制御レベル（下記参照） |
| `EditLevel__c` | Picklist | 編集権限レベル（下記参照） |
| `Description__c` | Text | Wikiスペースの説明 |

### WikiPage__c 主要項目

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `Title__c` | Text | ページタイトル |
| `Content__c` | LongTextArea | ページ本文（Markdown / プレーンテキスト） |
| `Slug__c` | Text | URL用の識別子（自動生成） |
| `Status__c` | Picklist | 下書き / 公開 / アーカイブ |
| `ParentPage__c` | Lookup(WikiPage__c) | 親ページ（階層構造） |
| `Tags__c` | Text | タグ（カンマ区切り） |
| `ViewCount__c` | Number | 閲覧数（ページロードごとにインクリメント） |
| `TeamWiki__c` | MasterDetail | 親Wikiスペース |

### WikiPageVersion__c 主要項目

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `Content__c` | LongTextArea | その時点のページ全文スナップショット |
| `Editor__c` | Lookup(User) | 編集者 |
| `EditSummary__c` | Text | 編集概要（コメット） |
| `VersionNumber__c` | Number | バージョン番号（自動採番） |
| `WikiPage__c` | MasterDetail | 対象ページ |

---

## アクセス制御

### AccessLevel__c（閲覧権限）

| 値 | 説明 | 共有の仕組み |
|----|------|------------|
| `組織メンバーのみ` | 関連 OrgUnit__c の所属メンバーのみ閲覧可 | Apex Managed Sharing（`TeamWikiSharingService`） |
| `全会員` | すべての内部ユーザーが閲覧可 | 条件ベース共有ルール（AllInternalUsers に Read 付与） |
| `外部公開` | Experience Cloud のゲストユーザーも閲覧可 | AllInternalUsers への共有ルール + Experience Cloud ゲストプロファイル設定 |

!!! warning "外部公開の設定"
    `AccessLevel__c = '外部公開'` に設定しても、Experience Cloud のゲストユーザープロファイルで `WikiPage__c` および `TeamWiki__c` オブジェクトへのアクセスを別途許可しなければ、ゲストは閲覧できません。外部公開にする場合は必ずゲストプロファイルの設定を確認してください。

!!! note "Apex Managed Sharing の実装"
    `TeamWikiSharingService` は以下のロジックで共有レコードを管理します。

    ```apex
    public class TeamWikiSharingService {
        public static void updateSharing(Id teamWikiId) {
            TeamWiki__c wiki = [
                SELECT Id, AccessLevel__c, EditLevel__c, OrgUnit__c
                FROM TeamWiki__c WHERE Id = :teamWikiId
            ];

            // 既存の Apex Managed Sharing を削除
            delete [
                SELECT Id FROM TeamWiki__Share
                WHERE ParentId = :teamWikiId AND RowCause = Schema.TeamWiki__Share.RowCause.Manual
            ];

            if (wiki.AccessLevel__c == '組織メンバーのみ') {
                // OrgUnit の所属メンバーに共有を付与
                List<Member__c> members = [
                    SELECT Id, OwnerId FROM Member__c
                    WHERE OrgUnit__c = :wiki.OrgUnit__c AND MemberStatus__c = '活動中'
                ];
                List<TeamWiki__Share> shares = new List<TeamWiki__Share>();
                for (Member__c m : members) {
                    TeamWiki__Share s = new TeamWiki__Share();
                    s.ParentId = teamWikiId;
                    s.UserOrGroupId = m.OwnerId;
                    s.AccessLevel = wiki.EditLevel__c == '組織メンバーのみ' ? 'Edit' : 'Read';
                    s.RowCause = Schema.TeamWiki__Share.RowCause.Manual;
                    shares.add(s);
                }
                insert shares;
            }
        }
    }
    ```

### EditLevel__c（編集権限）

| 値 | 説明 |
|----|------|
| `組織メンバーのみ` | 関連 OrgUnit__c の所属メンバーが編集可 |
| `管理者のみ` | `MemberPortalAdmins` グループのメンバーのみ編集可 |

---

## コンポーネント

| コンポーネント | 種別 | 説明 |
|--------------|------|------|
| `teamWikiViewer` | LWC | サイドバーのページツリー + メインコンテンツエリア。閲覧・編集モードの切り替えをサポート |
| `teamWikiEditor` | LWC | スタンドアロンの編集タブ（独立ページでの編集用） |

### teamWikiViewer の画面構成

```
┌─────────────────────────────────────────────────┐
│  [Wikiスペース名]                                 │
├──────────────┬──────────────────────────────────┤
│              │                                  │
│  ページツリー  │  ページタイトル                   │
│              │                                  │
│  ▶ ページA   │  本文（Markdown レンダリング）       │
│    ▶ 子ページ │                                  │
│  ▶ ページB   │  閲覧数: 42  最終更新: 2024-03-15  │
│  ▶ ページC   │                                  │
│              │  [編集] [バージョン履歴]            │
└──────────────┴──────────────────────────────────┘
```

---

## ページの作成手順

```
1. [新規ページ] ボタンをクリック
    │
    ▼
2. 以下の情報を入力
    │  ・タイトル（Title__c）
    │  ・本文（Content__c）— Markdown またはプレーンテキスト
    │  ・ステータス（Status__c）— 下書き / 公開 / アーカイブ
    │  ・タグ（Tags__c）— カンマ区切り
    │  ・編集概要（EditSummary__c）— 変更内容の説明
    │  ・親ページ（ParentPage__c）— 階層構造を設定する場合
    ▼
3. [保存] ボタンをクリック
    │  ① WikiPage__c を作成/更新
    │  ② Slug__c を自動生成（タイトルから）
    │  ③ WikiPageVersion__c を新規作成（スナップショット保存）
    │  ④ ViewCount__c は変更しない
```

---

## ページ階層（ParentPage__c）

`WikiPage__c.ParentPage__c` は同オブジェクトへの自己参照（Lookup）です。これにより、任意の深さのページツリーを構築できます。

```
Wikiスペース: 2024年度活動記録
  │
  ├─ 総会（ParentPage__c = null）
  │    ├─ 第1回定時総会（ParentPage__c = 総会）
  │    └─ 第2回臨時総会（ParentPage__c = 総会）
  │
  ├─ 広報活動
  │    ├─ SNS運用ガイドライン
  │    └─ デザインテンプレート集
  │
  └─ 予算・会計
```

!!! tip "階層の深さ"
    技術的には無制限の階層が可能ですが、ナビゲーションの可読性のために **3階層まで**を推奨します。

---

## バージョン履歴

ページを保存するたびに `WikiPageVersion__c` レコードが作成されます。バージョン履歴レコードは**追記専用**であり、編集・削除はできません。

```apex
// WikiPage__c 保存時のバージョン作成（Trigger / Service 例）
WikiPageVersion__c version = new WikiPageVersion__c();
version.WikiPage__c = page.Id;
version.Content__c = page.Content__c;
version.Editor__c = UserInfo.getUserId();
version.EditSummary__c = editSummary;
version.VersionNumber__c = nextVersionNumber;
insert version;
```

!!! warning "バージョン削除禁止"
    `WikiPageVersion__c` レコードの削除は禁止されています。トリガーで削除操作を検知した場合はエラーをスローします。監査目的でバージョン履歴の完全性を保証するための設計です。

---

## Slug の自動生成

ページ保存時、`Slug__c` はタイトルから自動生成されます。

```javascript
// Slug 生成ロジック（概要）
function generateSlug(title) {
    return title
        .toLowerCase()
        .replace(/\s+/g, '-')      // スペースをハイフンに
        .replace(/[^\w\-]/g, '')   // 英数字・ハイフン以外を除去
        .replace(/--+/g, '-');     // 連続ハイフンを単一に
}
// 例: "2024年度 活動報告" → "2024-" （日本語は除去される）
// 日本語タイトルの場合はローマ字または英語タイトルを推奨
```

!!! info "日本語タイトルと Slug"
    日本語タイトルの場合、Slug は短い文字列になることがあります。URLの一意性はレコードIDで保証されているため、Slug の重複は許容されますが、SEOや共有リンクの可読性のために英語タイトルの使用を推奨します。

---

## 閲覧数（ViewCount__c）

`teamWikiViewer` LWC がページを表示するたびに `ViewCount__c` をインクリメントします。

```apex
@AuraEnabled
public static void incrementViewCount(Id pageId) {
    WikiPage__c page = [SELECT Id, ViewCount__c FROM WikiPage__c WHERE Id = :pageId];
    page.ViewCount__c = (page.ViewCount__c == null ? 0 : page.ViewCount__c) + 1;
    update page;
}
```

!!! note "管理者の閲覧はカウントしない"
    `MemberPortalAdmins` グループのメンバーによる閲覧はカウントしないよう、`incrementViewCount()` 内で呼び出し元ユーザーのグループを確認してください（現時点では未実装、将来の改善項目）。
