# 権限セット管理

Willen 会員ポータルでは2種類の権限セットを使用して、管理者と会員のアクセス権限を制御します。

---

## 権限セット一覧

| 権限セット名 | 対象ユーザー | 概要 |
|---|---|---|
| `MemberPortalAdmin` | HR・管理部門スタッフ | 全オブジェクトへのフルアクセス + 全 Apex クラス |
| `MemberPortalUser` | Experience Cloud ポータル会員 | 最小限の読み取り + 特定の作成権限 |

---

## MemberPortalAdmin

HR・管理部門スタッフ向けの管理者権限セットです。会員ポータルのすべての機能を操作できます。

### オブジェクト権限

| オブジェクト | 参照 | 作成 | 編集 | 削除 | ViewAll | ModifyAll |
|---|---|---|---|---|---|---|
| `Member__c` | あり | あり | あり | あり | あり | あり |
| `Payment__c` | あり | あり | あり | あり | あり | あり |
| `Donation__c` | あり | あり | あり | あり | あり | あり |
| `Activity__c` | あり | あり | あり | あり | あり | あり |
| `ActivityParticipant__c` | あり | あり | あり | あり | あり | あり |
| `OrgUnit__c` | あり | あり | あり | あり | あり | あり |
| `PersonnelChange__c` | あり | あり | あり | あり | あり | あり |
| `ChangeRequest__c` | あり | あり | あり | あり | あり | あり |
| `BatchNotification__c` | あり | あり | あり | あり | あり | あり |
| `SupportInquiry__c` | あり | あり | あり | あり | あり | あり |
| `PortalConfiguration__c` | あり | あり | あり | あり | あり | あり |
| `TeamWiki__c` | あり | あり | あり | あり | あり | あり |
| `WikiPage__c` | あり | あり | あり | あり | あり | あり |
| `WikiPageVersion__c` | あり | あり | あり | あり | あり | あり |
| `IndividualNotification__c` | あり | あり | あり | あり | あり | あり |
| `GeneralMeeting__c` | あり | あり | あり | あり | あり | あり |
| `FormTemplate__c` | あり | あり | あり | あり | あり | あり |
| `FormField__c` | あり | あり | あり | あり | あり | あり |
| `FormResponse__c` | あり | あり | あり | あり | あり | あり |
| `FormFieldResponse__c` | あり | あり | あり | あり | あり | あり |

### Apex クラスアクセス

全コントローラー・サービスクラスへのアクセスが付与されます：

- `MemberRegistrationController`
- `PaymentController`
- `DonationController`
- `ActivityController`
- `SupportInquiryController`
- `OrgChartController`
- `ChangeRequestController`
- `TeamWikiController`
- `GeneralMeetingController`
- `FormBuilderController`
- `PortalConfigController`
- `DocumentGenerationController`
- `PayjpCalloutService`
- `PaymentGatewayService`
- `OktaIntegrationService`
- `SlackIntegrationService`
- `EmailNotificationService`
- `IndividualNotificationService`
- `TeamWikiSharingService`
- `WorkflowApprovalService`

### フィールドレベルセキュリティ

`OktaUserId__c` および `SlackUserId__c` を含む **全フィールドへの参照・編集** が可能です。

---

## MemberPortalUser

Experience Cloud ポータルの認証済み会員向けの権限セットです。最小権限の原則に基づき、必要最小限のアクセスのみ付与されます。

### オブジェクト権限

| オブジェクト | 参照 | 作成 | 編集 | 削除 | 備考 |
|---|---|---|---|---|---|
| `Member__c` | 自分のみ | - | - | - | OWD=Private のため自分のレコードのみ |
| `Payment__c` | 自分のみ | - | - | - | 閲覧のみ |
| `Donation__c` | 自分のみ | あり | - | - | |
| `SupportInquiry__c` | 自分のもの | あり | - | - | 問い合わせ送信は可能 |
| `FormResponse__c` | 自分のもの | あり | - | - | フォーム回答送信は可能 |
| `FormFieldResponse__c` | 自分のもの | あり | - | - | |
| `FormTemplate__c` | あり | - | - | - | フォーム構成の参照のみ |
| `FormField__c` | あり | - | - | - | フォームフィールドの参照のみ |
| `GeneralMeeting__c` | あり | - | - | - | 総会情報の閲覧のみ |
| `TeamWiki__c` | 共有ルールに従う | - | - | - | AccessLevel による制御 |
| `WikiPage__c` | あり | あり | - | - | Wiki閲覧 + 新規ページ作成 |
| `WikiPageVersion__c` | あり | あり | - | - | バージョン保存 |
| `ActivityParticipant__c` | 自分のもの | あり | - | - | イベント参加登録 |
| `Activity__c` | あり（公開のみ） | - | - | - | IsPublic__c=true のみ |

### 非表示フィールド

!!! warning "機密フィールドは MemberPortalUser に非表示"
    以下のフィールドは `MemberPortalUser` 権限セットでは **参照不可・編集不可** です。

| フィールド | 理由 |
|---|---|
| `Member__c.OktaUserId__c` | 外部 IdP の内部識別子を会員に公開しない |
| `Member__c.SlackUserId__c` | Slack の内部ユーザーIDを会員に公開しない |

---

## オブジェクト別アクセス権限比較表

| オブジェクト | MemberPortalAdmin | MemberPortalUser |
|---|---|---|
| `Member__c` | 全件 CRUD + ModifyAll | 自分のレコード参照のみ |
| `Payment__c` | 全件 CRUD + ModifyAll | 自分の履歴参照のみ |
| `SupportInquiry__c` | 全件 CRUD + ModifyAll | 作成 + 自分のもの参照 |
| `PortalConfiguration__c` | 全件 CRUD + ModifyAll | **アクセス不可** |
| `PersonnelChange__c` | 全件 CRUD + ModifyAll | **アクセス不可** |
| `IndividualNotification__c` | 全件 CRUD + ModifyAll | **アクセス不可** |
| `FormBuilderController` | 利用可 | **アクセス不可** |
| `OktaUserId__c` フィールド | 参照・編集可 | **非表示** |
| `SlackUserId__c` フィールド | 参照・編集可 | **非表示** |

---

## 権限セットの割り当て

### Salesforce CLI（推奨）

```bash
# MemberPortalAdmin の割り当て
sf org assign permset \
  --name MemberPortalAdmin \
  --on-behalf-of user@example.com \
  --target-org <orgAlias>

# MemberPortalUser の割り当て
sf org assign permset \
  --name MemberPortalUser \
  --on-behalf-of portaluser@willen.jp \
  --target-org <orgAlias>
```

### 複数ユーザーへの一括割り当て（匿名 Apex）

```apex
// 特定プロファイルの全ユーザーに MemberPortalUser を割り当てる
List<User> users = [
    SELECT Id FROM User
    WHERE Profile.Name = 'Customer Community User'
      AND IsActive = true
    WITH SECURITY_ENFORCED
];

PermissionSet ps = [
    SELECT Id FROM PermissionSet
    WHERE Name = 'MemberPortalUser'
    LIMIT 1
];

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (User u : users) {
    assignments.add(new PermissionSetAssignment(
        AssigneeId = u.Id,
        PermissionSetId = ps.Id
    ));
}
insert assignments;
System.debug(assignments.size() + ' 件のユーザーに MemberPortalUser を割り当てました。');
```

### Setup UI からの割り当て

```
Setup → Users → ユーザー一覧
    ↓
対象ユーザーのリンクをクリック
    ↓
「Permission Set Assignments」セクション
    ↓
「Edit Assignments」をクリック
    ↓
MemberPortalAdmin または MemberPortalUser を選択して保存
```

---

## 権限割り当て確認クエリ

```soql
-- 特定ユーザーの権限セット割り当てを確認
SELECT PermissionSet.Name, Assignee.Name, Assignee.Email
FROM   PermissionSetAssignment
WHERE  Assignee.Email = 'admin@willen.jp'
ORDER BY PermissionSet.Name
```

```soql
-- MemberPortalAdmin が割り当てられたユーザー一覧
SELECT Assignee.Name, Assignee.Email, Assignee.IsActive
FROM   PermissionSetAssignment
WHERE  PermissionSet.Name = 'MemberPortalAdmin'
  AND  Assignee.IsActive = true
ORDER BY Assignee.Name
```

---

## 注意事項

!!! warning "Experience Cloud ゲストユーザー"
    Experience Cloud のゲストユーザー（未認証）には権限セットを割り当てることができません。ゲストユーザーのアクセスはプロファイルとシェアリング設定で制御してください。公開イベント（`IsPublic__c = true`）と外部公開Wiki（`AccessLevel__c = '外部公開'`）のみアクセスを許可します。

!!! tip "権限セットの継承"
    `MemberPortalAdmin` と `MemberPortalUser` は独立した権限セットです。管理者ユーザーには `MemberPortalAdmin` **のみ**を割り当ててください。両方を割り当てる必要はありません（`MemberPortalAdmin` の権限が優先されます）。
