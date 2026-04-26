# サポート問い合わせ（SupportInquiry__c）

会員からのサポート問い合わせを管理する機能です。SLA（サービスレベル合意）追跡、エスカレーション、内部メモ管理を提供します。

---

## オブジェクト概要

`SupportInquiry__c` は会員からの問い合わせを1件1レコードとして管理します。優先度に応じたSLA期限の自動計算、エスカレーション機能、対応担当者への内部メモ付与が可能です。

---

## フィールド一覧

| フィールド API名 | 種別 | 説明 |
|---|---|---|
| `Subject__c` | Text | 問い合わせ件名 |
| `Body__c` | Long Text Area | 問い合わせ本文 |
| `Priority__c` | Picklist | 優先度（高 / 中 / 低） |
| `InquiryType__c` | Picklist | 問い合わせ種別 |
| `ResponseStatus__c` | Picklist | 対応ステータス（未対応 / 対応中 / 解決済み） |
| `IsAuthenticatedMember__c` | Checkbox | 認証済み会員からの送信かどうか |
| `SLADeadline__c` | DateTime | SLA期限（優先度から自動計算） |
| `FirstResponseDate__c` | DateTime | 初回対応日時 |
| `IsSLAMet__c` | Checkbox | SLA達成フラグ（初回対応時に自動設定） |
| `EscalatedTo__c` | Lookup (User) | エスカレーション先ユーザー |
| `EscalationDate__c` | DateTime | エスカレーション実施日時 |
| `EscalationReason__c` | Long Text Area | エスカレーション理由 |
| `InternalNote__c` | Long Text Area | 内部メモ（会員には非表示） |
| `Tags__c` | Text | タグ（カンマ区切り） |
| `RelatedPayment__c` | Lookup (Payment__c) | 関連する支払いレコード |

---

## SLA（サービスレベル合意）

### 優先度別SLA時間

| 優先度 | SLA時間 | 説明 |
|---|---|---|
| 高 | **4時間** | 緊急度が高い問い合わせ。即時対応が必要 |
| 中 | **24時間** | 通常の問い合わせ |
| 低 | **72時間** | 参考・確認系の問い合わせ |

!!! note "SLADeadline__c の計算"
    `submitInquiry()` 呼び出し時に、送信日時に優先度対応時間を加算して `SLADeadline__c` が自動設定されます。

```apex
// SLA計算ロジック（概念コード）
Integer slaHours;
switch on inquiry.Priority__c {
    when '高' { slaHours = 4; }
    when '中' { slaHours = 24; }
    when '低' { slaHours = 72; }
    when else  { slaHours = 24; }
}
inquiry.SLADeadline__c = Datetime.now().addHours(slaHours);
```

### SLA達成判定

`respondToInquiry()` が呼び出されると：

1. `FirstResponseDate__c` に現在日時を設定
2. `FirstResponseDate__c <= SLADeadline__c` を評価
3. 結果を `IsSLAMet__c` に保存

!!! warning "SLA違反の監視"
    `getOverdueSLAInquiries()` は `SLADeadline__c < NOW` かつ `ResponseStatus__c != '解決済み'` のレコードをすべて返します。定期的にこのメソッドを呼び出して未対応件数を監視してください。

---

## 主要メソッド（SupportInquiryController）

### submitInquiry()

会員またはゲストが問い合わせを送信します。

```apex
@AuraEnabled
public static SupportInquiry__c submitInquiry(
    String subject,
    String body,
    String priority,
    String inquiryType
)
```

処理フロー：

1. `SupportInquiry__c` レコードを作成
2. Experience Cloud セッションが認証済みの場合、`IsAuthenticatedMember__c = true` を設定
3. 優先度に応じた `SLADeadline__c` を計算・設定
4. `ResponseStatus__c = '未対応'` で保存

---

### respondToInquiry()

担当者が問い合わせに初回返答を行います。

```apex
@AuraEnabled
public static void respondToInquiry(Id inquiryId, String responseText)
```

処理フロー：

1. `FirstResponseDate__c` に `Datetime.now()` を設定
2. `FirstResponseDate__c <= SLADeadline__c` を評価して `IsSLAMet__c` を設定
3. `ResponseStatus__c = '対応中'` に更新

---

### escalateInquiry()

問い合わせをエスカレーションします。

```apex
@AuraEnabled
public static void escalateInquiry(
    Id inquiryId,
    Id escalateTo,
    String reason
)
```

!!! info "エスカレーション時の動作"
    - `Priority__c` を **高** に引き上げ
    - SLAを **4時間** で再計算（現在日時から）
    - `EscalatedTo__c`、`EscalationDate__c`、`EscalationReason__c` を設定

---

### addInternalNote()

内部メモを追記します（会員には表示されません）。

```apex
@AuraEnabled
public static void addInternalNote(Id inquiryId, String note)
```

!!! note "メモの追記形式"
    既存の `InternalNote__c` にタイムスタンプ付きで追記されます。上書きではなく**追記**です。

    ```
    [2025/01/15 14:30 - 山田太郎]
    顧客から追加情報を受領。決済ログを確認中。

    [2025/01/15 16:45 - 鈴木花子]
    Pay.jp 管理画面で決済エラーを確認。返金処理を実施予定。
    ```

---

### getOverdueSLAInquiries()

SLA期限超過の未解決問い合わせを取得します。

```apex
@AuraEnabled
public static List<SupportInquiry__c> getOverdueSLAInquiries()
```

内部クエリ：

```soql
SELECT Id, Subject__c, Priority__c, SLADeadline__c, ResponseStatus__c,
       EscalatedTo__c, CreatedDate
FROM   SupportInquiry__c
WHERE  SLADeadline__c < :Datetime.now()
  AND  ResponseStatus__c != '解決済み'
WITH SECURITY_ENFORCED
ORDER BY SLADeadline__c ASC
```

---

## IsAuthenticatedMember__c について

| 値 | 意味 |
|---|---|
| `true` | Experience Cloud の認証済みセッションから送信 |
| `false` | ゲストユーザーまたは未認証状態から送信 |

!!! tip "活用例"
    認証済み会員からの問い合わせは `Member__c` レコードと紐付けた詳細調査が可能です。`false` の場合はメールアドレスのみで追跡します。

---

## LWCコンポーネント

### supportInquiryForm

| 用途 | ターゲット |
|---|---|
| 会員によるチケット送信 | `lightningCommunity__Page` |
| 管理者によるチケット管理 | `lightningCommunity__Page`（管理者モード） |

!!! tip "コンポーネントの共用"
    `supportInquiryForm` は会員向けフォームと管理者向け画面で同一コンポーネントを使用します。管理者モードではエスカレーション・内部メモ機能が有効になります。

---

## 運用フロー

```
会員が送信
    │
    ▼
submitInquiry() → SLADeadline__c を計算・設定
    │
    ▼
ResponseStatus__c = '未対応'
    │
    ├─ SLA期限内に対応 ────────────────────────────────────▶ respondToInquiry()
    │                                                              │
    │                                                              ▼
    │                                                    IsSLAMet__c = true
    │                                                    ResponseStatus__c = '対応中'
    │                                                              │
    │                                                              ▼
    │                                                    ResponseStatus__c = '解決済み'
    │
    └─ SLA期限超過 ──────────▶ getOverdueSLAInquiries() で検出
                                          │
                                          ▼
                                escalateInquiry() → Priority__c = '高', SLA再計算
```

---

## よくある質問

!!! faq "エスカレーション後のSLAはどうなる？"
    `escalateInquiry()` を呼び出した時点の現在日時から 4時間後に `SLADeadline__c` が再設定されます。元の期限は上書きされます。

!!! faq "内部メモは会員に見えるか？"
    `InternalNote__c` は `supportInquiryForm` の会員向けビューでは表示されません。管理者権限を持つユーザーのみが閲覧・編集できます。
