# 会員管理

会員ポータルにおける会員情報の登録・閲覧・更新に関する機能の仕様をまとめます。

---

## 会員種別

Willen 会員ポータルでは以下の3種別の会員を管理します。

| 種別 | API値 | 概要 | 導入フェーズ |
|------|-------|------|-------------|
| 正会員 | `正会員` | 通常の組織所属会員 | Phase 1 |
| 準会員 | `準会員` | 議決権なし・準所属会員 | Phase 1 |
| 賛助会員 | `賛助会員` | 財政支援を目的とした外部会員 | Phase 2 |

!!! info "Phase 2 追加"
    賛助会員（`賛助会員`）は Phase 2 から導入されました。既存の `Member__c` レコードに `MemberType__c = '賛助会員'` を設定することで有効になります。賛助会員専用のカスタム項目については後述の「賛助会員専用項目」を参照してください。

---

## Member__c オブジェクト

### 主要項目一覧

| 項目API名 | 型 | 説明 | FLS制限 |
|-----------|-----|------|---------|
| `MemberStatus__c` | Picklist | 会員ステータス（活動中/休会中/退会済み） | なし |
| `MemberType__c` | Picklist | 会員種別（正会員/準会員/賛助会員） | なし |
| `OrgUnit__c` | Lookup(OrgUnit__c) | 所属組織単位 | なし |
| `OktaUserId__c` | Text | Okta ユーザーID | **FLS制限あり** |
| `SlackUserId__c` | Text | Slack ユーザーID | **FLS制限あり** |
| `Email__c` | Email | 個人登録メールアドレス | なし |
| `SupportingMemberInfo__c` | LongTextArea | 賛助会員の会社名・役職等の付帯情報 | なし |
| `SupportingAmount__c` | Currency | 賛助額（年額） | なし |

!!! warning "FLS制限項目"
    `OktaUserId__c` および `SlackUserId__c` は **MemberPortalUser 権限セット** によってポータルユーザーから非表示に設定されています。これらの項目はシステム連携のみに使用され、会員本人やポータル管理者（管理者権限を持たない）は参照できません。

    ```xml
    <!-- MemberPortalUser.permissionset-meta.xml (抜粋) -->
    <fieldPermissions>
        <field>Member__c.OktaUserId__c</field>
        <readable>false</readable>
        <editable>false</editable>
    </fieldPermissions>
    <fieldPermissions>
        <field>Member__c.SlackUserId__c</field>
        <readable>false</readable>
        <editable>false</editable>
    </fieldPermissions>
    ```

### 組織共有設定（OWD）

| 設定 | 値 |
|------|-----|
| デフォルトの内部アクセス | **Private** |
| デフォルトの外部アクセス | Private |

`Member__c` の OWD は **Private** に設定されています。共有はすべて共有ルールまたは Apex Managed Sharing によって制御されます。

!!! note "MemberPortalAdmins 共有ルール"
    公開グループ `MemberPortalAdmins` のメンバーには、**編集（Edit）** アクセス権を付与する共有ルールが設定されています。これにより、管理者グループのユーザーはすべての `Member__c` レコードを参照・編集できます。

    ```
    共有ルール名: MemberPortalAdmins_Edit
    対象オブジェクト: Member__c
    共有元: すべてのレコード（条件なし）
    共有先: 公開グループ MemberPortalAdmins
    アクセスレベル: 編集
    ```

---

## 賛助会員専用項目

賛助会員（`MemberType__c = '賛助会員'`）には以下の追加項目があります。

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `SupportingMemberInfo__c` | LongTextArea(32768) | 会社名・役職・担当者名などの付帯情報（自由記述） |
| `SupportingAmount__c` | Currency | 賛助額（年額）。`PortalConfiguration__c.AnnualFeeSupporting__c` を参照して設定 |

!!! tip "賛助額の自動設定"
    新規賛助会員登録時、`SupportingAmount__c` は `PortalConfiguration__c` の `AnnualFeeSupporting__c` の値を初期値として設定します。個別に変更することも可能です。

---

## リストビュー

`Member__c` オブジェクトには以下のリストビューが定義されています。

| リストビュー名 | API名 | 表示対象 | フィルター条件 |
|--------------|-------|---------|--------------|
| 全アクティブ会員 | `OrgMemberView` | すべてのアクティブ会員 | `MemberStatus__c = '活動中'` |
| 賛助会員一覧 | `SupportingMemberView` | 賛助会員のみ | `MemberStatus__c = '活動中' AND MemberType__c = '賛助会員'` |

---

## 新規会員登録フロー

新規会員の登録は Experience Cloud 上の **`memberRegistrationForm` LWC** を通じて行います。

```
[ポータルユーザー]
    │
    ▼
memberRegistrationForm LWC（Experience Cloud）
    │  ① フォーム入力（氏名、メール、会員種別、所属組織）
    ▼
MemberRegistrationController.registerMember()
    │  ② Member__c レコード作成
    │  ③ OktaUserId__c 連携（OktaIntegrationService 経由）
    ▼
確認メール送信（SendConfirmationEmail__c = true の場合）
```

!!! info "必須入力項目"
    `memberRegistrationForm` で必須となる項目は以下の通りです。

    - 氏名（姓・名）
    - メールアドレス（`Email__c`）
    - 会員種別（`MemberType__c`）
    - 所属組織単位（`OrgUnit__c`）—— 賛助会員の場合は任意

---

## 所属組織の変更（人事異動フロー）

会員の `OrgUnit__c`（所属組織単位）を直接編集することは**禁止**されています。変更は必ず `PersonnelChange__c` レコードを介した承認フローを通じて行います。

!!! warning "直接編集は禁止"
    管理者であっても `Member__c.OrgUnit__c` を直接変更してはいけません。承認フローを経ずに変更した場合、Okta との同期やSlack チャンネル更新が行われず、権限管理に不整合が生じます。

### 変更手順

1. `PersonnelChange__c` レコードを作成（`ChangeType__c = '組織異動'`）
2. 承認プロセスを起動（`ApprovalStatus__c` = `申請中` → `承認済み`）
3. トリガーが自動的に `Member__c.OrgUnit__c` を更新
4. Okta グループへの同期が自動実行される

詳細は [人事異動](personnel-change.md) のページを参照してください。

---

## MemberPortalUser 権限セット

ポータルユーザーに付与される `MemberPortalUser` 権限セットは以下の制限を含みます。

| 制限内容 | 対象項目 |
|---------|---------|
| 参照・編集不可 | `Member__c.OktaUserId__c` |
| 参照・編集不可 | `Member__c.SlackUserId__c` |
| 参照のみ（編集不可） | `Member__c.MemberStatus__c` |

!!! note "権限セットの適用対象"
    `MemberPortalUser` はすべての Experience Cloud ポータルユーザーに適用されます。内部ユーザー（Salesforce ライセンス）には適用されません。内部ユーザーの権限は所属プロファイルおよび `MemberPortalAdmins` グループの共有ルールで制御されます。
