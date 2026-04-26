# 総会管理

年次総会（定時総会）の開催管理、出欠確認、議決権行使に関する仕様をまとめます。

---

## GeneralMeeting__c オブジェクト

### 主要項目一覧

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `FiscalYear__c` | Text | 対象事業年度（例: `2024`） |
| `MeetingDate__c` | DateTime | 開催日時 |
| `MeetingStatus__c` | Picklist | 開催ステータス（下記参照） |
| `ResponseDeadline__c` | DateTime | 出欠回答期限 |
| `Agenda__c` | LongTextArea | 議案リスト（後述の書式） |
| `AttendanceCount__c` | Number | 出席予定者数（自動集計） |
| `ProxyCount__c` | Number | 委任状提出者数（自動集計） |
| `AbsenceCount__c` | Number | 欠席者数（自動集計） |
| `Location__c` | Text | 開催場所 |
| `MeetingNotes__c` | LongTextArea | 議事録 |

### MeetingStatus__c の状態遷移

| ステータス | 説明 | 会員の操作 |
|-----------|------|-----------|
| `準備中` | 管理者が内容を設定中 | 参照不可 |
| `出欠受付中` | 出欠・委任状の回答を受け付けている | 回答可能 |
| `締め切り` | 回答期限を過ぎた、または管理者が締め切った | 回答不可 |
| `開催済み` | 総会が終了した | 結果閲覧のみ |

---

## フォーム種別

総会管理では以下のフォーム種別を使用します。いずれも `FormTemplate__c` + `FormField__c` で構成されます。

| フォーム種別 | `FormType__c` の値 | 用途 |
|------------|------------------|------|
| 出欠確認 | `出欠確認` | 出席・欠席の意思表示 |
| 委任状 | `委任状` | 欠席時の議決権委任 |
| 議決権行使 | `議決権行使` | 欠席時の議案ごとの賛否表明 |

詳細は [フォームビルダー](form-builder.md) のページを参照してください。

---

## 会員側フロー（generalMeetingForm LWC）

```
[会員がポータルにアクセス]
    │
    ▼
総会カードを表示（MeetingStatus__c = '出欠受付中' のみ表示）
    │
    ▼
出欠選択
    ├─── 出席
    │         └─▶ そのまま送信へ
    │
    ├─── 欠席（委任状あり）
    │         └─▶ 委任先氏名入力（ProxyName__c）必須
    │
    ├─── 欠席（権利行使書提出）
    │         └─▶ 議案ごとの賛否選択（Agenda__c から自動生成）
    │
    └─── 欠席
              └─▶ そのまま送信へ
    │
    ▼
送信（GeneralMeetingController.submitAttendanceResponse()）
    │  ① FormResponse__c を作成
    │  ② AttendanceCount__c / ProxyCount__c / AbsenceCount__c を更新
    │  ③ 確認メール送信（SendConfirmationEmail__c = true の場合）
    ▼
送信完了画面
```

!!! warning "回答期限の強制"
    `ResponseDeadline__c` を過ぎた後に送信しようとすると、`submitAttendanceResponse()` はエラーをスローします。フロントエンド・バックエンドの両方で期限チェックを行っています。

    ```apex
    if (meeting.ResponseDeadline__c < DateTime.now()) {
        throw new AuraHandledException('回答期限（' +
            meeting.ResponseDeadline__c.format('yyyy年MM月dd日 HH:mm') +
            '）を過ぎているため、送信できません。');
    }
    ```

---

## 議案の書式（Agenda__c）

`Agenda__c` に入力する議案の書式は以下の通りです。「第」で始まる行が議決権行使の選択肢として自動解析されます。

```
第1号議案 2024年度事業報告承認の件
第2号議案 2024年度決算報告承認の件
第3号議案 役員改選の件
（参考）次期事業計画について
```

!!! info "議案の解析ロジック"
    `generalMeetingForm` LWC は `Agenda__c` を改行で分割し、`第` で始まる行のみを議決権行使の選択肢として抽出します。「（参考）」などで始まる行は議決権行使の対象外となります。

    ```javascript
    // LWC 側の議案解析（概要）
    get agendaItems() {
        if (!this.meeting.Agenda__c) return [];
        return this.meeting.Agenda__c
            .split('\n')
            .filter(line => line.trim().startsWith('第'))
            .map((line, index) => ({ id: index, label: line.trim(), vote: null }));
    }
    ```

---

## FormResponse__c の構造

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `AttendanceChoice__c` | Picklist | 出席 / 欠席（委任状あり）/ 欠席（権利行使書提出）/ 欠席 |
| `ProxyName__c` | Text | 委任先の氏名（委任状あり の場合） |
| `VotingChoicesJson__c` | LongTextArea | 議案ごとの賛否（JSON形式） |
| `FieldAnswersJson__c` | LongTextArea | カスタムフィールドの回答（JSON形式） |
| `Member__c` | Lookup | 回答した会員 |
| `GeneralMeeting__c` | Lookup | 対象の総会 |
| `SubmittedAt__c` | DateTime | 送信日時 |

### VotingChoicesJson__c の形式

```json
[
  {
    "agendaIndex": 0,
    "agendaLabel": "第1号議案 2024年度事業報告承認の件",
    "vote": "賛成"
  },
  {
    "agendaIndex": 1,
    "agendaLabel": "第2号議案 2024年度決算報告承認の件",
    "vote": "反対"
  },
  {
    "agendaIndex": 2,
    "agendaLabel": "第3号議案 役員改選の件",
    "vote": "棄権"
  }
]
```

---

## 管理者フロー

### 総会の作成から締め切りまで

| ステップ | 操作 | 結果 |
|---------|------|------|
| 1 | `GeneralMeeting__c` レコードを新規作成 | `MeetingStatus__c = '準備中'` |
| 2 | `Agenda__c` に議案を入力し、`ResponseDeadline__c` を設定 | — |
| 3 | `MeetingStatus__c` を `出欠受付中` に変更 | ポータルに総会カードが表示される |
| 4 | 応答状況をデータテーブルでモニタリング | リアルタイム集計 |
| 5 | 未回答会員にリマインダーメール送信 | `sendReminders()` 実行 |
| 6 | 期限到来または手動で `締め切り` に変更 | 新規送信を拒否 |
| 7 | 総会開催後、`開催済み` に変更 + 議事録入力 | — |

### リマインダー送信

```apex
// GeneralMeetingController.sendReminders() の概要
public static void sendReminders(Id meetingId) {
    // 回答済みの会員IDを取得
    Set<Id> respondedMemberIds = new Map<Id, FormResponse__c>(
        [SELECT Id, Member__c FROM FormResponse__c
         WHERE GeneralMeeting__c = :meetingId]
    ).keySet();

    // 未回答の活動中会員を取得
    List<Member__c> unreplied = [
        SELECT Id, Email__c, Name
        FROM Member__c
        WHERE MemberStatus__c = '活動中'
        AND Id NOT IN :respondedMemberIds
    ];

    // リマインダーメールを送信
    for (Member__c m : unreplied) {
        // ... メール送信処理
    }
}
```

!!! tip "リマインダーのベストプラクティス"
    回答期限の3日前と前日の2回リマインダーを送ることを推奨します。`GeneralMeeting__c` レコードの `ResponseDeadline__c` を基準に、管理者が手動でタイミングを調整してください。

---

## 確認メール

`FormTemplate__c.SendConfirmationEmail__c = true` の場合、回答送信時に自動で確認メールが送信されます。

| 条件 | メール内容 |
|------|-----------|
| 出席 | 出席登録完了の通知 + 開催日時・場所 |
| 欠席（委任状あり） | 委任先氏名を含む委任状受付完了通知 |
| 欠席（権利行使書提出） | 議案ごとの賛否内容を含む確認通知 |
| 欠席 | 欠席受付完了の通知 |
