# スケジュール済みジョブ管理

Willen 会員ポータルで稼働するバッチ・スケジューラジョブの設定・監視・トラブルシューティングを説明します。

---

## ジョブ一覧

| ジョブ名 | クラス名 | スケジュール | バッチサイズ | 目的 |
|---|---|---|---|---|
| PersonnelChangePublisherBatch | `PersonnelChangePublisherBatch` | 毎時0分（`0 0 * * * ?`） | 20 | 人事変更の発表通知送信 |
| BatchNotificationBatch | `BatchNotificationBatch` | 設定可変 | 200 | ポータル通知の一括送信 |

---

## 1. PersonnelChangePublisherBatch

### 概要

承認済みの人事変更を自動的に発表するバッチジョブです。発表予定日が到来した人事変更に対して Slack 通知・メール通知を送信し、ステータスを更新します。

### スケジュール

| 項目 | 値 |
|---|---|
| Cron 式 | `0 0 * * * ?` |
| 実行頻度 | **毎時0分**（1時間ごと） |
| バッチサイズ | **20**（Callout を含むため小さく設定） |

### 処理対象クエリ

```soql
SELECT Id, Name, Member__c, FromOrgUnit__c, ToOrgUnit__c,
       ChangeType__c, PublicationDate__c, AnnouncementStatus__c
FROM   PersonnelChange__c
WHERE  AnnouncementStatus__c = '発表予定'
  AND  PublicationDate__c    <= :Datetime.now()
  AND  ApprovalStatus__c    = '承認済み'
WITH SECURITY_ENFORCED
ORDER BY PublicationDate__c ASC
```

### 処理内容

```
対象レコードを取得（バッチサイズ=20単位）
    │
    ▼
各PersonnelChange__c について:
    │
    ├── 1. SlackIntegrationService.notifyPersonnelChange() — Slack チャンネルに通知
    ├── 2. EmailNotificationService.sendPersonnelChangeNotification() — メール送信
    ├── 3. AnnouncementStatus__c = '発表済み' に更新
    └── 4. AnnouncedAt__c = Datetime.now() を設定
```

### 登録方法（匿名 Apex）

```apex
// Setup → Developer Console → Execute Anonymous
PersonnelChangePublisherBatch.scheduleHourly();
```

または手動でスケジュールを設定する場合：

```apex
System.schedule(
    'PersonnelChangePublisherBatch',  // ジョブ名
    '0 0 * * * ?',                    // Cron式（毎時0分）
    new PersonnelChangePublisherBatch()
);
```

!!! tip "確認方法"
    登録後は **Setup → Scheduled Jobs** を開いて `PersonnelChangePublisherBatch` が一覧に表示されていることを確認してください。

---

## 2. BatchNotificationBatch

### 概要

ポータル通知（`BatchNotification__c`）を一括処理して会員に送信するバッチジョブです。

### 登録方法（匿名 Apex）

```apex
// スケジュール例（毎日午前9時）
System.schedule(
    'BatchNotificationBatch_Daily',
    '0 0 9 * * ?',
    new BatchNotificationBatch()
);
```

---

## ジョブ登録・管理手順

### 登録済みジョブの確認

```
Setup → クイック検索で「Scheduled Jobs」を検索
    ↓
「Scheduled Jobs」をクリック
    ↓
ジョブ一覧が表示される
```

または SOQL でも確認できます：

```soql
SELECT Id, JobType, CronJobDetail.Name, State,
       NextFireTime, PreviousFireTime, TimesTriggered
FROM   CronTrigger
WHERE  CronJobDetail.Name LIKE '%Batch%'
ORDER BY NextFireTime ASC
```

---

### 実行中ジョブの確認

```
Setup → クイック検索で「Apex Jobs」を検索
    ↓
「Apex Jobs」をクリック
    ↓
実行中・完了・エラーのジョブ一覧が表示される
```

SOQL による確認：

```soql
SELECT Id, ApexClassId, ApexClass.Name, Status,
       NumberOfErrors, JobItemsProcessed, TotalJobItems,
       CreatedDate, CompletedDate, ExtendedStatus
FROM   AsyncApexJob
WHERE  ApexClass.Name IN (
    'PersonnelChangePublisherBatch',
    'BatchNotificationBatch'
)
ORDER BY CreatedDate DESC
LIMIT 10
```

| Status 値 | 意味 |
|---|---|
| `Queued` | キュー待ち |
| `Processing` | 実行中 |
| `Completed` | 正常完了 |
| `Failed` | エラーで停止 |
| `Holding` | 保留中 |
| `Aborted` | 手動で中断 |

---

### ジョブの中断（Abort）

```
Setup → Apex Jobs
    ↓
中断したいジョブの「Abort」リンクをクリック
```

または匿名 Apex：

```apex
// ジョブIDを指定して中断
System.abortJob('7077F00000XXXXXX');
```

```apex
// ジョブ名で検索して中断
List<CronTrigger> jobs = [
    SELECT Id FROM CronTrigger
    WHERE CronJobDetail.Name = 'PersonnelChangePublisherBatch'
];
for (CronTrigger job : jobs) {
    System.abortJob(job.Id);
}
```

---

### 誤って削除した場合の再登録

!!! warning "ジョブを誤って削除・中断した場合"
    ジョブを Abort すると、次回以降の実行が行われなくなります。以下の手順で再登録してください。

```apex
// 1. 既存の同名ジョブがあれば先に削除
List<CronTrigger> existing = [
    SELECT Id FROM CronTrigger
    WHERE CronJobDetail.Name = 'PersonnelChangePublisherBatch'
];
for (CronTrigger ct : existing) {
    System.abortJob(ct.Id);
}

// 2. 再登録
PersonnelChangePublisherBatch.scheduleHourly();
System.debug('PersonnelChangePublisherBatch を再登録しました。');
```

---

## エラー発生時のトラブルシューティング

### エラーの確認

```soql
-- エラーが発生したジョブを確認
SELECT Id, ApexClass.Name, Status, ExtendedStatus,
       NumberOfErrors, CreatedDate
FROM   AsyncApexJob
WHERE  Status = 'Failed'
  AND  ApexClass.Name IN ('PersonnelChangePublisherBatch', 'BatchNotificationBatch')
ORDER BY CreatedDate DESC
LIMIT 5
```

### よくあるエラーと対処法

| エラー | 原因 | 対処法 |
|---|---|---|
| `System.CalloutException: Unauthorized endpoint` | Remote Site Settings 未設定 | Setup → Remote Site Settings で Slack/Okta のURLを登録 |
| `System.LimitException: Too many callouts` | 1 execute あたりの Callout 超過 | バッチサイズを小さくする（10以下に設定） |
| `UNABLE_TO_LOCK_ROW` | 同一レコードへの同時アクセス | バッチサイズを小さくするか、ジョブの実行間隔を広げる |
| `Named Credential not found` | Named Credential 未設定 | Setup → Named Credentials で SlackAPI 等を設定 |

---

## 監視ベストプラクティス

!!! tip "定期的な監視"
    以下のクエリを定期実行してジョブの健全性を確認してください。

```soql
-- 直近24時間のジョブ実行結果
SELECT ApexClass.Name, Status, NumberOfErrors,
       JobItemsProcessed, TotalJobItems, CreatedDate
FROM   AsyncApexJob
WHERE  CreatedDate >= :Datetime.now().addHours(-24)
  AND  ApexClass.Name IN ('PersonnelChangePublisherBatch', 'BatchNotificationBatch')
ORDER BY CreatedDate DESC
```

```soql
-- 次回実行予定の確認
SELECT CronJobDetail.Name, NextFireTime, State
FROM   CronTrigger
WHERE  State = 'WAITING'
ORDER BY NextFireTime ASC
```

!!! info "ジョブ失敗時の通知"
    バッチジョブがエラーで終了した場合、Salesforce はシステム管理者メールアドレスへ自動的にエラーメールを送信します。送信先は **Setup → Email → Organization-Wide Addresses** で確認できます。
