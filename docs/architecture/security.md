# セキュリティモデル

Willen 会員ポータルのセキュリティ設計を説明します。組織全体のデフォルト（OWD）、共有ルール、権限セット、SOQL セキュリティ、外部連携認証の各層で多重防御を実現しています。

---

## 組織全体の共有設定（OWD）

| オブジェクト | OWD | 理由 |
|---|---|---|
| `Member__c` | **Private** | 会員情報は本人と管理者のみが参照できる必要がある |
| `Payment__c` | **Private** | 支払い情報は機密情報 |
| `TeamWiki__c` | **Private** | アクセス範囲はWikiごとに異なるため個別制御 |
| `WikiPage__c` | **ControlledByParent** | 親TeamWikiの共有設定を継承 |
| `WikiPageVersion__c` | **ControlledByParent** | 親WikiPageの共有設定を継承 |
| `ActivityParticipant__c` | **ControlledByParent** | 参加者情報はイベントの共有設定に従う |
| `SupportInquiry__c` | **Private** | 問い合わせ内容は送信者と担当者のみ参照 |
| `IndividualNotification__c` | **Private** | 通知は宛先会員と管理者のみ参照 |

!!! note "Private OWDの意味"
    Private に設定されたオブジェクトは、レコードオーナーと上位ロール（または明示的な共有）を持つユーザーのみがアクセスできます。管理者がすべてのレコードを見るには **ModifyAll / ViewAll** 権限が必要です。

---

## 共有ルール

### Member__c の共有ルール

| ルール種別 | 条件 | 共有先グループ | 付与するアクセス |
|---|---|---|---|
| 基準共有 | すべての `Member__c` レコード | `MemberPortalAdmins` パブリックグループ | **編集（Edit）** |

管理者グループに全会員レコードの編集権限を付与します。

---

### TeamWiki__c の共有ルール

| ルール種別 | 条件 / 対象 | 共有先 | 付与するアクセス |
|---|---|---|---|
| 基準共有 | `AccessLevel__c = '全会員'` | `AllInternalUsers` | 参照（Read） |
| 基準共有 | `AccessLevel__c = '外部公開'` | `AllInternalUsers` | 参照（Read） |
| 基準共有 | `IsActive__c = true` | `MemberPortalAdmins` | 編集（Edit） |
| **Apex 管理共有** | `AccessLevel__c = '組織メンバーのみ'` | 組織メンバー（動的） | 参照（Read） |

!!! warning "組織メンバーのみの共有はApexで管理"
    `AccessLevel__c = '組織メンバーのみ'` に設定されたWikiは、標準共有ルールでは対応できません。`TeamWikiSharingService` が Apex 管理共有（`TeamWiki__Share`）を使って対象組織のメンバーにのみアクセスを付与します。

---

### TeamWikiSharingService（Apex 管理共有）

```apex
// クラス宣言: without sharing（共有ルールを意図的に無視して共有レコードを操作）
public without sharing class TeamWikiSharingService {

    // 組織メンバーへのアクセス付与（非同期）
    @future
    public static void grantOrgMemberAccess(Id wikiId, Id orgUnitId) { ... }

    // Wiki の共有設定を再計算（組織メンバー変更時など）
    public static void recalculateSharing(Id wikiId) { ... }
}
```

!!! info "without sharing の理由"
    Apex 管理共有を操作するためには `without sharing` が必要です。このクラス内では共有レコード（`__Share` オブジェクト）のみを操作し、ビジネスデータへの書き込みは行いません。

---

## 権限セット

### MemberPortalAdmin

HR・管理部門スタッフ向けの管理者権限セットです。

| カテゴリ | 付与される権限 |
|---|---|
| オブジェクト権限 | 全20+カスタムオブジェクトに **CRUD（作成・参照・編集・削除）** |
| システム権限 | **ModifyAllData / ViewAllData** |
| Apex クラス | 全コントローラー・サービスクラスへのアクセス |
| フィールドレベルセキュリティ | `OktaUserId__c`、`SlackUserId__c` を含む全フィールドへの参照・編集 |

---

### MemberPortalUser

Experience Cloud ポータル会員向けの制限権限セットです。

| オブジェクト | 参照 | 作成 | 編集 | 削除 |
|---|---|---|---|---|
| `Member__c`（自分のレコード） | 自分のみ | - | - | - |
| `Payment__c`（自分のレコード） | 自分のみ | - | - | - |
| `SupportInquiry__c` | 自分のもの | あり | - | - |
| `FormResponse__c` | 自分のもの | あり | - | - |
| `FormTemplate__c` | あり | - | - | - |
| `FormField__c` | あり | - | - | - |
| `GeneralMeeting__c` | あり | - | - | - |
| `TeamWiki__c` | 共有ルールに従う | - | - | - |
| `WikiPage__c` | あり | あり | - | - |
| `WikiPageVersion__c` | あり | あり | - | - |
| `ActivityParticipant__c` | 自分のもの | あり | - | - |

#### 非表示フィールド（MemberPortalUser）

!!! warning "OktaUserId__c / SlackUserId__c は会員に非表示"
    `OktaUserId__c` と `SlackUserId__c` は `MemberPortalUser` 権限セットでは **参照不可・編集不可** です。外部 IdP の内部識別子が会員に漏洩しないよう FLS で制御しています。

| フィールド | MemberPortalAdmin | MemberPortalUser |
|---|---|---|
| `OktaUserId__c` | 参照・編集可 | **非表示** |
| `SlackUserId__c` | 参照・編集可 | **非表示** |

---

## SOQL セキュリティ

すべてのコントローラークラスで `WITH SECURITY_ENFORCED` を使用しています。

```apex
// すべてのSOQLクエリにWITH SECURITY_ENFORCEDを付与
List<Member__c> members = [
    SELECT Id, Name, Email__c, MemberType__c
    FROM   Member__c
    WHERE  Id = :memberId
    WITH SECURITY_ENFORCED
];
```

!!! note "WITH SECURITY_ENFORCED の効果"
    FLS（フィールドレベルセキュリティ）と OWD を SOQL レベルで自動的に適用します。現在のユーザーが参照権限を持たないフィールドをクエリしようとすると `System.QueryException` が発生します。

---

## Named Credentials（外部連携認証）

すべての外部サービスへの接続は Named Credentials を経由します。エンドポイント URL や認証情報をコードにハードコードすることは禁止されています。

| Named Credential 名 | 接続先 | 認証方式 |
|---|---|---|
| `OktaAPI` | Okta REST API | OAuth 2.0 / API Token |
| `SlackAPI` | Slack Bot API | Bot Token (Bearer) |
| `PayjpAPI` | Pay.jp API | Basic Auth（Secret Key） |
| `OmiseAPI` | Omise API | Basic Auth（Secret Key） |
| `StripeAPI` | Stripe API | Bearer Token |
| `FincodeAPI` | Fincode API | API Key Header |

```apex
// 正しい実装例（Named Credentials を使用）
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:PayjpAPI/v1/charges');
req.setMethod('POST');

// NG: エンドポイントをハードコード（絶対に行わないこと）
// req.setEndpoint('https://api.pay.jp/v1/charges'); // ← 禁止
```

!!! danger "シークレットキーのハードコード禁止"
    API キーや Secret Key を Apex コード、カスタム設定、カスタムメタデータに直接記載することは禁止です。必ず Named Credentials の認証情報として保存してください。

---

## Experience Cloud ゲストユーザーのアクセス制御

ゲストユーザー（未認証の訪問者）がアクセスできるデータは最小限に制限されています。

| リソース | ゲストアクセス | 条件 |
|---|---|---|
| イベント | 参照・登録 | `Activity__c.IsPublic__c = true` のみ |
| Wikiページ | 参照 | `TeamWiki__c.AccessLevel__c = '外部公開'` のみ |
| 会員情報 | **アクセス不可** | - |
| 支払い情報 | **アクセス不可** | - |
| フォーム | 状況による | `FormTemplate__c.IsActive__c = true` のもの |

!!! warning "ゲストユーザーのプロファイル設定"
    Experience Cloud のゲストユーザープロファイルにはオブジェクト権限を最小限に設定してください。不要なオブジェクトへのアクセスは削除し、`IsPublic__c` / `AccessLevel__c` フィルタを Apex レイヤーで必ず適用してください。

---

## セキュリティチェックリスト

| 項目 | 実装状況 |
|---|---|
| 全 SOQL クエリに WITH SECURITY_ENFORCED | 実装済み |
| Named Credentials による外部連携 | 実装済み |
| OWD: Member__c = Private | 実装済み |
| FLS: OktaUserId__c/SlackUserId__c | MemberPortalUser で非表示 |
| Apex クラス: with sharing 宣言 | 全コントローラーで実装済み |
| without sharing は TeamWikiSharingService のみ | 実装済み |
| ゲストユーザーのアクセスを IsPublic__c で制御 | 実装済み |
| シークレットキーのハードコード | 禁止（Named Credentials 使用） |
