# 個人通知

特定の会員または会員グループに対して、複数のチャネルを通じてメッセージを送信する機能です。

---

## 概要

`individualNotificationComposer` LWC を使用して、管理者がメッセージを作成・送信します。4種類の配信チャネルと、柔軟な受信者選択・差し込みフィールドをサポートします。

---

## 配信チャネル

| チャネル | 説明 | 使用データ |
|---------|------|-----------|
| 個人登録メール | `Member__c.Email__c` に送信 | 会員が登録した個人メールアドレス |
| Willenメール | `@willen.jp` アドレスに送信 | 姓名から自動構築（後述） |
| Slack DM | Slack ダイレクトメッセージ | `SlackUserId__c`（FLS制限あり） |
| ポータル通知 | ポータル内通知として表示 | `BatchNotification__c` レコードを作成 |

!!! info "チャネルの選択"
    複数チャネルを同時に選択できます。選択したすべてのチャネルで同じ本文が送信されます（差し込みフィールドは各受信者に応じてマージされます）。

---

## Willenメールアドレスの構築

Willenメールは会員の姓名から自動構築されます。

```apex
// IndividualNotificationService.buildWillenEmail() の実装
public static String buildWillenEmail(Member__c member) {
    String fullName = (member.LastName__c + member.FirstName__c);
    String localPart = fullName
        .toLowerCase()
        .replaceAll('[^a-z0-9]', '');  // アルファベット・数字以外を除去
    return localPart + '@willen.jp';
}
```

### 変換例

| 姓 | 名 | 生成されるメールアドレス |
|----|----|-----------------------|
| 田中 | Taro | `tanakaTaro`.toLowerCase() → `tanakataro@willen.jp` |
| Smith | John | `SmithJohn`.toLowerCase() → `smithjohn@willen.jp` |
| 佐藤 | 花子 | 日本語除去 → `@willen.jp`（要注意） |

!!! warning "日本語氏名の場合"
    姓名がすべて日本語の場合、英数字がゼロになり `@willen.jp` のみになります。日本語氏名の会員には Willenメールチャネルを使用しないでください。事前に「テストメール送信」で確認することを推奨します。

---

## 受信者の選択

| 受信者種別 | 説明 | 入力形式 |
|-----------|------|---------|
| `全会員` | すべての活動中会員 | — |
| `組織単位` | 特定の OrgUnit__c に所属する会員 | OrgUnit__c レコードを選択 |
| `会員種別` | 特定の会員種別（正会員/準会員/賛助会員） | ピックリストで選択 |
| `特定会員` | 個別に指定した会員 | Member__c ID をカンマ区切りで入力 |

---

## 差し込みフィールド（Merge Fields）

メッセージ本文に以下のプレースホルダーを使用すると、送信時に各会員の情報に置き換えられます。

### 会員情報

| プレースホルダー | 説明 | 例 |
|---------------|------|-----|
| `{!Member.Name}` | 氏名（フルネーム） | 田中太郎 |
| `{!Member.LastName}` | 姓 | 田中 |
| `{!Member.FirstName}` | 名 | 太郎 |
| `{!Member.Email}` | 個人登録メール | taro@example.com |
| `{!Member.MemberType}` | 会員種別 | 正会員 |
| `{!Member.Organization}` | 所属組織名 | 広報委員会 |
| `{!Member.Position}` | 役職 | 委員長 |

### 日付・時刻

| プレースホルダー | 説明 | 例 |
|---------------|------|-----|
| `{!Today}` | 今日の日付 | 2024年04月01日 |
| `{!Now}` | 現在日時 | 2024年04月01日 14:30 |

### 決済情報（relatedObjectType = Payment__c の場合）

| プレースホルダー | 説明 | 例 |
|---------------|------|-----|
| `{!Payment.Name}` | 決済レコード名 | 年会費-2024 |
| `{!Payment.Amount}` | 決済金額 | ¥10,000 |
| `{!Payment.DueDate}` | 支払期限 | 2024年05月31日 |

### 総会情報（relatedObjectType = GeneralMeeting__c の場合）

| プレースホルダー | 説明 | 例 |
|---------------|------|-----|
| `{!Meeting.Name}` | 総会名 | 2024年度定時総会 |
| `{!Meeting.Date}` | 開催日時 | 2024年06月15日 14:00 |
| `{!Meeting.Location}` | 開催場所 | オンライン（Zoom） |
| `{!Meeting.Deadline}` | 回答期限 | 2024年06月10日 17:00 |

### 差し込みフィールドの使用例

```
件名: {!Meeting.Name} の出欠確認のお願い

{!Member.LastName} 様

いつもお世話になっております。
{!Today} 現在、{!Meeting.Name} の出欠確認を受け付けております。

■ 開催日時: {!Meeting.Date}
■ 開催場所: {!Meeting.Location}
■ 回答期限: {!Meeting.Deadline}

ポータルよりご回答いただきますようお願いいたします。
```

---

## 送信モード

| モード | 動作 | 説明 |
|--------|------|------|
| 今すぐ送信 | `@Future` callout | 送信ボタン押下後、非同期で即時送信 |
| 予約送信 | `IndividualNotification__c` に `ScheduledSendTime__c` を設定 | 指定した日時に `scheduleNotification` バッチが送信 |
| 下書き保存 | `status = '下書き'` で保存 | 送信されない。後から編集・送信可能 |

```apex
// 今すぐ送信（@Future による非同期処理）
@Future(callout=true)
public static void sendNow(Id notificationId) {
    IndividualNotification__c notif = [
        SELECT Id, Subject__c, Body__c, RecipientType__c,
               DeliveryChannels__c, RelatedObjectType__c, RelatedObjectId__c
        FROM IndividualNotification__c WHERE Id = :notificationId
    ];
    IndividualNotificationService.send(notif);
}
```

---

## テストメール送信

`individualNotificationComposer` の「テストメール送信」ボタンを使用すると、指定したメールアドレスに、**現在のユーザーの会員データでマージした**本文をプレビュー送信できます。

```
[テストメール送信] ボタンをクリック
    │
    ▼
テスト送信先メールアドレスを入力
    │
    ▼
IndividualNotificationService.sendTestEmail(body, testAddress, currentUserId)
    │  ① 現在ユーザーの Member__c データを取得
    │  ② プレースホルダーをマージした本文を生成
    │  ③ testAddress にメールを送信
    │  ④ マージ済み本文を String で返却
    ▼
画面内でマージ済み本文をインライン表示（プレビュー）
```

```apex
// IndividualNotificationService.sendTestEmail() のシグネチャ
public static String sendTestEmail(
    String subject,
    String body,
    String testAddress,
    Id currentUserId
) {
    Member__c member = [
        SELECT Name, LastName__c, FirstName__c, Email__c,
               MemberType__c, OrgUnit__r.Name, Position__c
        FROM Member__c
        WHERE OwnerId = :currentUserId
        LIMIT 1
    ];

    String mergedBody = mergePlaceholders(body, member, null);

    // テストメール送信
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ testAddress });
    email.setSubject('[テスト] ' + subject);
    email.setPlainTextBody(mergedBody);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

    return mergedBody; // プレビュー用にフロントエンドへ返却
}
```

!!! tip "テストメールのベストプラクティス"
    本番送信前に必ずテストメールを送信して、差し込みフィールドが正しくマージされているか確認してください。特に日本語氏名のケースや、関連オブジェクト（Payment__c、GeneralMeeting__c）のプレースホルダーを使用する場合は念入りに確認してください。

---

## IndividualNotification__c オブジェクト

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `Subject__c` | Text | 件名 |
| `Body__c` | LongTextArea | 本文（プレースホルダー含む） |
| `Status__c` | Picklist | 下書き / 送信予約中 / 送信済み / 送信失敗 |
| `RecipientType__c` | Picklist | 全会員 / 組織単位 / 会員種別 / 特定会員 |
| `RecipientIds__c` | LongTextArea | 特定会員指定時の Member__c ID（カンマ区切り） |
| `DeliveryChannels__c` | MultiPicklist | 個人登録メール / Willenメール / Slack DM / ポータル通知 |
| `ScheduledSendTime__c` | DateTime | 予約送信の日時 |
| `SentAt__c` | DateTime | 実際の送信日時 |
| `RelatedObjectType__c` | Text | 関連オブジェクト種別（Payment__c / GeneralMeeting__c） |
| `RelatedObjectId__c` | Text | 関連レコードID |
| `CreatedBy` | Lookup(User) | 作成者（送信者） |

---

## Slack DM 送信

`SlackUserId__c` を使用して Slack のダイレクトメッセージを送信します。`SlackUserId__c` は FLS 制限のある項目ですが、`IndividualNotificationService` は **システム管理者コンテキスト**（`without sharing`）で実行されるため、ポータルユーザーが送信操作を行った場合でもアクセスできます。

```apex
// SlackIntegrationService.sendDM() の概要
public static void sendDM(String slackUserId, String message) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Slack/api/chat.postMessage');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(new Map<String, Object>{
        'channel' => slackUserId,
        'text' => message
    }));
    Http http = new Http();
    HttpResponse res = http.send(req);
    if (res.getStatusCode() != 200) {
        throw new CalloutException('Slack DM 送信失敗: ' + res.getBody());
    }
}
```

!!! warning "Slack DM と FLS"
    `SlackUserId__c` は FLS 制限項目ですが、`IndividualNotificationService` は `without sharing` で実行されます。このため、ポータルユーザーが操作した場合でも Slack DM を送信できますが、`SlackUserId__c` の値をフロントエンドに返さないよう実装してください。
