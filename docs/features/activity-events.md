# 活動・イベント管理（Activity__c / ActivityParticipant__c）

会員向けイベントの作成・公開・参加登録・出席管理を担う機能です。Experience Cloud ゲストユーザーも公開イベントを閲覧・登録できます。

---

## オブジェクト概要

### Activity__c

イベント（活動）の主レコード。会員が作成者でなくても登録可能です。

| フィールド API名 | 種別 | 説明 |
|---|---|---|
| `Member__c` | Lookup (Member__c) | 作成会員（nullable — 管理者が作成する場合は空） |
| `IsEvent__c` | Checkbox | イベントとして扱うかどうか |
| `IsPublic__c` | Checkbox | 公開イベントフラグ（Experience Cloud で表示） |
| `EventStartDatetime__c` | DateTime | イベント開始日時 |
| `EventEndDatetime__c` | DateTime | イベント終了日時 |
| `RegistrationDeadline__c` | DateTime | 申込締め切り日時 |
| `MaxParticipants__c` | Number | 最大参加人数（0 = 上限なし） |
| `CurrentParticipants__c` | Number | 現在の参加者数（登録時に自動加算） |
| `RegistrationFee__c` | Currency | 参加費（0 = 無料） |
| `OnlineUrl__c` | URL | オンライン参加URL（Zoom等） |

!!! note "Member__c は必須ではない"
    `Member__c` は Nullable Lookup です。管理者が社外向けイベントを直接作成する場合は空のまま保存できます。

---

### ActivityParticipant__c

参加者1名 = 1レコード。`Activity__c` との MasterDetail 関係のため、Activity削除時に連動削除されます。

| フィールド API名 | 種別 | 説明 |
|---|---|---|
| `Activity__c` | MasterDetail (Activity__c) | 参加するイベント |
| `Member__c` | Lookup (Member__c) | 参加会員（外部参加者の場合は空） |
| `ParticipantName__c` | Text | 参加者氏名 |
| `ParticipantEmail__c` | Email | 参加者メールアドレス |
| `ParticipationStatus__c` | Picklist | 参加ステータス |
| `IsExternalParticipant__c` | Checkbox | 外部参加者フラグ |
| `PaymentStatus__c` | Picklist | 支払いステータス |

#### ParticipationStatus__c の選択肢

| 値 | 説明 |
|---|---|
| `申込済み` | 申込完了・確定前 |
| `確定` | 参加確定 |
| `キャンセル` | キャンセル済み |
| `出席` | 当日出席 |
| `欠席` | 当日欠席 |

---

## 主要メソッド（ActivityController）

### createEvent()

管理者がイベントを新規作成します。

```apex
@AuraEnabled
public static Activity__c createEvent(
    String title,
    String description,
    Datetime startDatetime,
    Datetime endDatetime,
    Datetime registrationDeadline,
    Integer maxParticipants,
    Decimal registrationFee,
    Boolean isPublic,
    String onlineUrl
)
```

!!! warning "MaxParticipants__c の扱い"
    0 または null を渡すと上限なしとして扱われます。`registerForEvent()` 内の定員チェックはこの値を参照します。

---

### getPublicEvents() / getUpcomingEvents()

```apex
// 公開イベント一覧（Experience Cloud ゲストユーザー向け）
@AuraEnabled(cacheable=true)
public static List<Activity__c> getPublicEvents()

// 今後のイベント一覧（内部アプリ向け）
@AuraEnabled(cacheable=true)
public static List<Activity__c> getUpcomingEvents()
```

| メソッド | 対象 | IsPublic__c 条件 |
|---|---|---|
| `getPublicEvents()` | Experience Cloud（ゲスト含む） | `true` のみ |
| `getUpcomingEvents()` | 内部 Salesforce アプリ | 条件なし |

---

### registerForEvent()

参加登録処理。定員・締め切りチェックを行います。

```apex
@AuraEnabled
public static ActivityParticipant__c registerForEvent(
    Id activityId,
    String participantName,
    String participantEmail,
    String organization,
    Boolean isExternalParticipant
)
```

バリデーションロジック：

```apex
// 1. 締め切りチェック
if (activity.RegistrationDeadline__c < Datetime.now()) {
    throw new AuraHandledException('申込期限を過ぎています。');
}

// 2. 定員チェック
if (activity.MaxParticipants__c > 0
    && activity.CurrentParticipants__c >= activity.MaxParticipants__c) {
    throw new AuraHandledException('定員に達しています。');
}

// 3. ActivityParticipant__c を挿入
// 4. CurrentParticipants__c をインクリメント（SELECT FOR UPDATE）
```

!!! warning "同時登録の競合"
    `CurrentParticipants__c` の更新は `SELECT ... FOR UPDATE` ロックを使用してください。ロックなしの場合、同時登録時に定員超過が発生する恐れがあります。

---

### getParticipantsByEvent()

イベントの参加者一覧を取得します（管理者向け）。

```apex
@AuraEnabled(cacheable=true)
public static List<ActivityParticipant__c> getParticipantsByEvent(Id activityId)
```

---

### getMyRegistrations()

会員が自分の過去の登録履歴を取得します。

```apex
@AuraEnabled(cacheable=true)
public static List<ActivityParticipant__c> getMyRegistrations()
```

!!! tip "Experience Cloud での利用"
    `getMyRegistrations()` は `UserInfo.getUserId()` で現在ログインユーザーを特定し、関連する `ActivityParticipant__c` を返します。ゲストユーザーはこのメソッドを利用できません。

---

## LWCコンポーネント

### activityEventPortal

Experience Cloud およびSalesforce内部アプリ両方で使用されるメインコンポーネント。

```html
<!-- Experience Cloud（公開イベントのみ） -->
<c-activity-event-portal show-internal-events={false}></c-activity-event-portal>

<!-- 内部 Salesforce アプリ（全イベント） -->
<c-activity-event-portal show-internal-events={true}></c-activity-event-portal>
```

#### showInternalEvents プロパティ

| 値 | 表示対象 | 想定利用場所 |
|---|---|---|
| `false`（デフォルト） | `IsPublic__c = true` のイベントのみ | Experience Cloud |
| `true` | 全イベント（非公開含む） | 内部 Salesforce アプリ |

#### ユーザー操作フロー

```
カードグリッド表示（公開イベント一覧）
    │
    ▼
イベントカードをクリック
    │
    ▼
イベント詳細表示（開催日時・定員・参加費・オンラインURL）
    │
    ▼
「申し込む」ボタン
    │
    ▼
登録フォーム（氏名・メールアドレス・所属組織）
    │
    ▼
registerForEvent() 呼び出し
    │
    ├─ 成功 → 完了メッセージ表示
    └─ エラー（定員超過 / 期限切れ）→ エラートースト表示
```

#### 管理者モードでのイベント作成

管理者がコンポーネントを開くと右上に「イベントを作成」ボタンが表示されます。

```
「イベントを作成」ボタンをクリック
    │
    ▼
モーダルフォームが開く
（タイトル・説明・日時・定員・参加費・公開設定）
    │
    ▼
ActivityController.createEvent() 呼び出し
    │
    ▼
カードグリッドが自動更新
```

---

### activityRegistration

スタンドアロンの参加登録コンポーネント（Experience Cloud 専用ページ向け）。

```
ターゲット: lightningCommunity__Page
用途: イベント詳細ページからの直接遷移による登録
```

---

## 公開イベントポータルの利用シナリオ

### ゲストユーザー（未認証）

!!! info "ゲストユーザーの制限"
    - `IsPublic__c = true` のイベントのみ閲覧・登録可能
    - `getMyRegistrations()` は利用不可
    - `IsExternalParticipant__c = true` として登録

### 認証済み会員

- 全公開イベントの閲覧・登録
- `getMyRegistrations()` で自分の登録履歴確認
- `Member__c` が自動的に `ActivityParticipant__c` に設定

### 管理者（MemberPortalAdmin）

- 全イベント（非公開含む）の閲覧
- イベント作成・編集・削除
- 参加者一覧の確認・ステータス変更

---

## SOQL クエリ例

```soql
-- 今後の公開イベント一覧
SELECT Id, Name, EventStartDatetime__c, EventEndDatetime__c,
       MaxParticipants__c, CurrentParticipants__c, RegistrationFee__c,
       IsPublic__c, OnlineUrl__c
FROM   Activity__c
WHERE  IsEvent__c = true
  AND  IsPublic__c = true
  AND  EventStartDatetime__c >= :Datetime.now()
WITH SECURITY_ENFORCED
ORDER BY EventStartDatetime__c ASC
```
