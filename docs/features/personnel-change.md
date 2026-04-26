# 人事異動管理

組織異動・役職変更・氏名変更・入退会などの人事異動を計画・承認・発表するための機能です。

---

## 概要

`PersonnelChange__c` オブジェクトは、会員の所属組織変更・役職変更・氏名変更・入退会のレコードを管理します。Phase 3 では**発表スケジュール機能**が追加され、承認後の公開タイミングを柔軟に制御できるようになりました。

---

## PersonnelChange__c オブジェクト

### 主要項目一覧

| 項目API名 | 型 | 説明 | フェーズ |
|-----------|-----|------|---------|
| `ChangeType__c` | Picklist | 組織異動 / 役職変更 / 氏名変更 / 入会 / 退会 | Phase 1 |
| `Member__c` | Lookup | 対象会員 | Phase 1 |
| `FromOrgUnit__c` | Lookup(OrgUnit__c) | 異動前の所属組織 | Phase 1 |
| `ToOrgUnit__c` | Lookup(OrgUnit__c) | 異動後の所属組織 | Phase 1 |
| `EffectiveDate__c` | Date | 発令日 | Phase 1 |
| `ApprovalStatus__c` | Picklist | 申請中 / 承認済み / 差戻し | Phase 1 |
| `InternalNote__c` | LongTextArea | 内部メモ（公開されない） | **Phase 3** |
| `AnnouncementStatus__c` | Picklist | 下書き / 発表予定 / 発表済み | **Phase 3** |
| `PublicationDate__c` | DateTime | 発表予定日時 | **Phase 3** |
| `AnnouncedAt__c` | DateTime | 実際に発表された日時（自動記録） | **Phase 3** |

!!! info "Phase 3 追加項目"
    `AnnouncementStatus__c`、`PublicationDate__c`、`AnnouncedAt__c`、`InternalNote__c` は Phase 3 から追加されました。Phase 1・2 で作成されたレコードは `AnnouncementStatus__c = null` となっており、発表スケジュール機能の対象外として扱われます。

---

## 人事異動ワークフロー

```
Step 1: 人事担当者が PersonnelChange__c を作成
    AnnouncementStatus__c = '下書き'
    ApprovalStatus__c = '申請中'
    │
    ▼
Step 2: 承認プロセス実行
    承認者がレコードを確認・承認
    ApprovalStatus__c → '承認済み'
    │
    ▼ トリガーが自動実行
Step 3: 即時反映（内部システム）
    ・Member__c.OrgUnit__c を ToOrgUnit__c に更新
    ・OktaIntegrationService 経由で Okta グループを同期
    │
    ▼ 人事担当者が発表日を設定
Step 4: 発表スケジュール設定
    AnnouncementStatus__c → '発表予定'
    PublicationDate__c に未来の日時を設定
    │
    ▼ 毎時実行（スケジュールバッチ）
Step 5: PersonnelChangePublisherBatch が実行
    条件: status='発表予定' AND PublicationDate__c <= NOW()
    AnnouncementStatus__c → '発表済み'
    AnnouncedAt__c に現在日時を記録
    │
    ▼ トリガーが検知
Step 6: 通知送信
    ・Slack 通知（SlackIntegrationService 経由）
    ・メール通知
```

!!! warning "Okta 同期のタイミング"
    Okta グループへの同期は**承認時点で即時**に実行されます。`PublicationDate__c`（発表日）には関係ありません。これは組織変更に伴うアクセス権限の変更は即時反映が必要なためです。外部への発表は `PublicationDate__c` で制御しますが、システム権限は承認後すぐに変わることをご認識ください。

---

## 承認プロセスの詳細

### ApprovalStatus__c の遷移

| ステータス | 説明 |
|-----------|------|
| `申請中` | 初期値。承認待ちの状態 |
| `承認済み` | 承認完了。トリガーが会員情報・Okta を即時更新 |
| `差戻し` | 承認者が差し戻した。担当者が内容を修正して再申請 |

```apex
// PersonnelChangeTrigger（AfterUpdate）の概要
if (newRecord.ApprovalStatus__c == '承認済み' &&
    oldRecord.ApprovalStatus__c != '承認済み') {

    // Member.OrgUnit__c を更新
    Member__c member = [SELECT Id, OrgUnit__c FROM Member__c
                        WHERE Id = :newRecord.Member__c];
    member.OrgUnit__c = newRecord.ToOrgUnit__c;
    update member;

    // Okta グループを同期
    OktaIntegrationService.syncMemberGroup(newRecord.Member__c,
        newRecord.FromOrgUnit__c, newRecord.ToOrgUnit__c);
}
```

---

## 発表スケジュールバッチ

### PersonnelChangePublisherBatch

```apex
public class PersonnelChangePublisherBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, AnnouncementStatus__c, PublicationDate__c
            FROM PersonnelChange__c
            WHERE AnnouncementStatus__c = '発表予定'
            AND PublicationDate__c <= :DateTime.now()
        ]);
    }

    public void execute(Database.BatchableContext bc,
                        List<PersonnelChange__c> scope) {
        for (PersonnelChange__c pc : scope) {
            pc.AnnouncementStatus__c = '発表済み';
            pc.AnnouncedAt__c = DateTime.now();
        }
        update scope;
        // トリガーが Slack/メール通知を送信
    }

    public void finish(Database.BatchableContext bc) {}

    // 毎時実行スケジュール設定
    public static void scheduleHourly() {
        String cronExp = '0 0 * * * ?'; // 毎時0分に実行
        System.schedule('PersonnelChangePublisher_Hourly',
                        cronExp,
                        new PersonnelChangePublisherBatch());
    }
}
```

### バッチのスケジュール設定

```apex
// 開発者コンソール または 匿名Apex で実行
PersonnelChangePublisherBatch.scheduleHourly();
```

!!! warning "バッチが重複登録されないよう注意"
    `scheduleHourly()` を複数回実行すると同名のスケジュールジョブが重複します。実行前に既存のスケジュールジョブを確認してください。

    ```apex
    // 既存スケジュール確認
    List<CronTrigger> existing = [
        SELECT Id, CronJobDetail.Name, State
        FROM CronTrigger
        WHERE CronJobDetail.Name = 'PersonnelChangePublisher_Hourly'
    ];
    System.debug('既存ジョブ数: ' + existing.size());
    ```

---

## 発表後の通知

`AnnouncementStatus__c` が `発表予定` → `発表済み` に遷移したことをトリガーが検知し、以下の通知を送信します。

| 通知チャネル | 内容 |
|------------|------|
| Slack | 対象組織のチャンネルに異動情報を投稿 |
| メール | 対象会員・関連管理者にメール送信 |

```apex
// トリガー内の通知送信（概要）
if (newRecord.AnnouncementStatus__c == '発表済み' &&
    oldRecord.AnnouncementStatus__c != '発表済み') {

    // Slack 通知
    SlackIntegrationService.postPersonnelChange(newRecord.Id);

    // メール通知
    PersonnelChangeNotificationService.sendEmail(newRecord.Id);
}
```

---

## OrgUnit__c の名称変更管理

組織単位の名称変更は `OrgUnit__c` の直接編集ではなく、`ChangeRequest__c` を介したレビュープロセスで行います。

| 項目API名（OrgUnit__c） | 型 | 説明 |
|----------------------|-----|------|
| `PendingNameChange__c` | Text | 変更後の候補名称（承認前） |
| `ChangeRequestRef__c` | Lookup(ChangeRequest__c) | 関連する変更申請レコード |

### 名称変更フロー

```
1. OrgUnit__c.PendingNameChange__c に新しい名称を入力
2. ChangeRequest__c レコードを作成して ChangeRequestRef__c に紐付け
3. 承認者が ChangeRequest__c を承認
4. トリガーが OrgUnit__c.Name を PendingNameChange__c の値で更新
5. PendingNameChange__c をクリア、ChangeRequestRef__c を null に設定
```

!!! tip "名称変更が必要なケース"
    組織の合併・分割・改称時に使用します。名称変更が適用されると、関連するすべての `Member__c`・`PersonnelChange__c`・`TeamWiki__c` レコードの組織参照が自動的に最新名称を反映します（Lookup 参照のため、Name 変更は自動的に反映されます）。
