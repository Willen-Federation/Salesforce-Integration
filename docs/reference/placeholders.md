# プレースホルダー差し込みフィールドリファレンス

`individualNotificationComposer` LWC および `IndividualNotificationService.mergePlaceholders()` で使用できる差し込みフィールドの完全リファレンスです。

---

## 概要

差し込みフィールド（プレースホルダー）は `{!オブジェクト.フィールド}` の形式で通知テンプレートに埋め込みます。送信時に `IndividualNotificationService.mergePlaceholders()` が各プレースホルダーを実際の値に置換します。

```
テンプレート: {!Member.Name} 様、{!Payment.Amount}円のお支払いをお願いします。
送信結果:   山田 太郎 様、10000円のお支払いをお願いします。
```

---

## プレースホルダー一覧

### 会員情報（常に利用可能）

| プレースホルダー | 説明 | 例 | 適用オブジェクト |
|---|---|---|---|
| `{!Member.Name}` | 氏名（姓+名） | 山田 太郎 | 常に利用可 |
| `{!Member.LastName}` | 姓 | 山田 | 常に利用可 |
| `{!Member.FirstName}` | 名 | 太郎 | 常に利用可 |
| `{!Member.Email}` | 登録メールアドレス | yamada@example.com | 常に利用可 |
| `{!Member.MemberType}` | 会員種別 | 正会員 | 常に利用可 |
| `{!Member.MemberStatus}` | 会員ステータス | 正会員 | 常に利用可 |
| `{!Member.Organization}` | 所属組織名 | 第1事業部 | 常に利用可 |
| `{!Member.Position}` | 役職 | 部長 | 常に利用可 |

### 日時（常に利用可能）

| プレースホルダー | 説明 | 例 | 適用オブジェクト |
|---|---|---|---|
| `{!Today}` | 今日の日付 | 2025/01/15 | 常に利用可 |
| `{!Now}` | 現在日時 | 2025/01/15 14:30 | 常に利用可 |

### 支払い情報（relatedObjectType=Payment__c 時のみ）

| プレースホルダー | 説明 | 例 | 適用オブジェクト |
|---|---|---|---|
| `{!Payment.Name}` | 支払い番号 | PAY-0001 | `relatedObjectType=Payment__c` |
| `{!Payment.Amount}` | 支払い金額 | 10000 | `relatedObjectType=Payment__c` |
| `{!Payment.Status}` | 支払いステータス | 請求中 | `relatedObjectType=Payment__c` |
| `{!Payment.DueDate}` | 支払期限 | 2025/03/31 | `relatedObjectType=Payment__c` |

### 総会情報（relatedObjectType=GeneralMeeting__c 時のみ）

| プレースホルダー | 説明 | 例 | 適用オブジェクト |
|---|---|---|---|
| `{!Meeting.Name}` | 総会名 | 第50回定時総会 | `relatedObjectType=GeneralMeeting__c` |
| `{!Meeting.Date}` | 開催日時 | 2025/06/20 14:00 | `relatedObjectType=GeneralMeeting__c` |
| `{!Meeting.Location}` | 開催場所 | 東京都千代田区... | `relatedObjectType=GeneralMeeting__c` |
| `{!Meeting.Deadline}` | 回答期限 | 2025/06/10 17:00 | `relatedObjectType=GeneralMeeting__c` |

### 活動情報（relatedObjectType=Activity__c 時のみ）

| プレースホルダー | 説明 | 例 | 適用オブジェクト |
|---|---|---|---|
| `{!Activity.Title}` | 活動タイトル | 第2回研修会 | `relatedObjectType=Activity__c` |
| `{!Activity.Date}` | 活動日 | 2025/05/15 | `relatedObjectType=Activity__c` |
| `{!Activity.Location}` | 活動場所 | 大阪市北区... | `relatedObjectType=Activity__c` |

---

## Willen メールアドレス構成ルール

会員の Willen 社内メールアドレスは以下のルールで自動生成されます：

```
形式: (姓のローマ字 + 名のローマ字).toLowerCase().replaceAll('[^a-z0-9]', '') + '@willen.jp'

例:
  山田 太郎 → yamadataro@willen.jp
  鈴木 花子 → suzukihanako@willen.jp
  田中 一郎 → tanakaichirou@willen.jp
```

Apex での処理：

```apex
String willenEmail = (lastName + firstName)
    .toLowerCase()
    .replaceAll('[^a-z0-9]', '')
    + '@willen.jp';
```

!!! warning "アルファベット以外の文字について"
    姓名がひらがな・漢字等の場合、`replaceAll('[^a-z0-9]', '')` により文字が除去されます。実際の登録時は `Member__c.Email__c` フィールドに正しいメールアドレスを手動で設定してください。

---

## テンプレート例

### 例1: 出欠確認メール

```
件名: 【Willen】{!Meeting.Name} 出欠確認のお願い

{!Member.LastName} {!Member.FirstName} 様

いつもお世話になっております。Willen 事務局です。

下記の総会について、出欠のご回答をお願いいたします。

■ 総会名: {!Meeting.Name}
■ 開催日時: {!Meeting.Date}
■ 開催場所: {!Meeting.Location}
■ 回答期限: {!Meeting.Deadline}

会員ポータルよりご回答ください。
ご不明な点がございましたら、事務局までご連絡ください。

よろしくお願いいたします。
Willen 事務局
送信日: {!Today}
```

---

### 例2: 支払い催促メール

```
件名: 【Willen】{!Payment.Name} お支払いのお願い

{!Member.Name} 様

いつもお世話になっております。Willen 会計担当です。

以下のお支払いについて、お手続きをお願いいたします。

━━━━━━━━━━━━━━━━━━━━━━━━
　支払い番号: {!Payment.Name}
　お支払い金額: ¥{!Payment.Amount}
　ステータス: {!Payment.Status}
　お支払期限: {!Payment.DueDate}
━━━━━━━━━━━━━━━━━━━━━━━━

期限を過ぎますとサービスのご利用に制限が生じる場合があります。
会員ポータルよりお手続きをお願いいたします。

ご不明な点は事務局までお問い合わせください。

Willen 会計担当
{!Now} 時点
```

---

### 例3: 人事発表通知

```
件名: 【Willen】人事発表のお知らせ

{!Member.Name} 様

このたび、以下の人事異動についてお知らせいたします。

━━━━━━━━━━━━━━━━━━━━━━━━
対象者: {!Member.Name}
現所属: {!Member.Organization}
役職: {!Member.Position}
発令日: {!Today}
━━━━━━━━━━━━━━━━━━━━━━━━

詳細については会員ポータルの組織図をご確認ください。

よろしくお願いいたします。
Willen 人事担当
```

---

## individualNotificationComposer での使い方

### ステップ 1: テンプレートの選択または作成

```
individualNotificationComposer を開く
    ↓
「テンプレートを選択」または「直接入力」を選択
    ↓
既存テンプレートを選択すると件名・本文が自動入力される
```

### ステップ 2: プレースホルダーの挿入

```
本文入力エリアにカーソルを置く
    ↓
「差し込みフィールド」ボタンをクリック
    ↓
利用可能なプレースホルダー一覧が表示される
    ↓
クリックで本文に挿入される: {!Member.Name} など
```

!!! tip "関連オブジェクトの選択"
    `{!Payment.*}` や `{!Meeting.*}` プレースホルダーを使用する場合は、「関連オブジェクト」の選択が必要です。コンポーザーの「関連レコード」フィールドで `Payment__c` または `GeneralMeeting__c` レコードを指定してください。

### ステップ 3: テストメールで確認

```
「テストメール送信」ボタンをクリック
    ↓
自分のメールアドレスにテストメールが送信される
    ↓
プレースホルダーが正しく置換されているか確認
```

```apex
// IndividualNotificationService.sendTestEmail()
// コンポーザーでのテスト送信時に呼び出される
public static void sendTestEmail(Id templateId, String toAddress) {
    // テンプレートを取得
    // ダミーの Member__c データでプレースホルダーを置換
    // toAddress へメール送信
}
```

### ステップ 4: 送信

```
宛先会員を選択（個人 / フィルター条件）
    │
    ├── 「即時送信」→ createAndSend() → 全宛先へ即時送信
    ├── 「送信予約」→ scheduleNotification(scheduledAt) → 指定日時に送信
    └── 「下書き保存」→ saveDraft() → 後で編集・送信
```

---

## mergePlaceholders() の実装

```apex
public static String mergePlaceholders(
    String template,      // 差し込み前のテンプレート文字列
    Id memberId,          // 宛先会員のID
    Id relatedObjectId,   // 関連レコードのID（nullable）
    String relatedObjectType  // 'Payment__c', 'GeneralMeeting__c', 'Activity__c' など
) {
    // 1. Member__c を取得
    Member__c member = [
        SELECT Name, LastName__c, FirstName__c, Email__c,
               MemberType__c, MemberStatus__c, OrgUnit__r.Name, Position__c
        FROM   Member__c WHERE Id = :memberId
        WITH SECURITY_ENFORCED
        LIMIT 1
    ];

    // 2. 基本プレースホルダーを置換
    String result = template
        .replace('{!Member.Name}',         member.Name)
        .replace('{!Member.LastName}',     member.LastName__c)
        .replace('{!Member.FirstName}',    member.FirstName__c)
        .replace('{!Member.Email}',        member.Email__c)
        .replace('{!Member.MemberType}',   member.MemberType__c)
        .replace('{!Member.MemberStatus}', member.MemberStatus__c)
        .replace('{!Member.Organization}', member.OrgUnit__r.Name)
        .replace('{!Member.Position}',     member.Position__c)
        .replace('{!Today}',               Date.today().format())
        .replace('{!Now}',                 Datetime.now().format());

    // 3. 関連オブジェクトのプレースホルダーを置換
    if (relatedObjectId != null) {
        switch on relatedObjectType {
            when 'Payment__c' {
                // Payment__c を取得して {!Payment.*} を置換
            }
            when 'GeneralMeeting__c' {
                // GeneralMeeting__c を取得して {!Meeting.*} を置換
            }
            when 'Activity__c' {
                // Activity__c を取得して {!Activity.*} を置換
            }
        }
    }

    return result;
}
```

---

## よくある質問

!!! faq "プレースホルダーが置換されずにそのまま送信された"
    以下を確認してください：
    - プレースホルダーの形式が正しいか（`{!` と `}` の間にスペースがないか）
    - 関連オブジェクトが必要なプレースホルダー（`{!Payment.*}` 等）を使う場合に `relatedObjectId` が設定されているか
    - 会員レコードの対象フィールドが空でないか

!!! faq "{!Member.Organization} が空になる"
    `Member__c.OrgUnit__c` が未設定の場合、`{!Member.Organization}` は空文字になります。会員の所属組織を設定してから送信してください。
