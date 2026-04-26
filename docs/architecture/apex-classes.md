# Apex クラスリファレンス

Willen 会員ポータルで使用するすべての Apex クラスの概要、主要メソッド、設計上の注意点を説明します。

---

## コントローラークラス（with sharing）

すべてのコントローラーは `with sharing` で宣言されており、現在のユーザーの共有ルールとFLSが適用されます。

| クラス名 | 主要メソッド | 説明 |
|---|---|---|
| `MemberRegistrationController` | `registerMember`, `getMemberDetail`, `updateMember` | 会員登録・プロフィール管理 |
| `PaymentController` | `createPayment`, `getPaymentHistory`, `processPayment` | 支払い処理・履歴管理 |
| `DonationController` | `createDonation`, `getDonationHistory` | 寄附登録・履歴管理 |
| `ActivityController` | `createEvent`, `getPublicEvents`, `getUpcomingEvents`, `registerForEvent`, `getParticipantsByEvent`, `getMyRegistrations` | イベント作成・公開・参加登録管理 |
| `SupportInquiryController` | `submitInquiry`, `escalateInquiry`, `respondToInquiry`, `addInternalNote`, `getOverdueSLAInquiries` | サポートチケット管理・SLA追跡 |
| `OrgChartController` | `getOrgUnits` | 組織図データの取得 |
| `ChangeRequestController` | `submitChangeRequest`, `getChangeRequests`, `approveRequest`, `rejectRequest` | 組織変更申請・承認ワークフロー |
| `TeamWikiController` | `getWikisByOrgUnit`, `getWikiPages`, `getWikiPageDetail`, `savePage`, `getPageVersions` | WikiスペースおよびWikiページのCRUD |
| `GeneralMeetingController` | `getUpcomingMeetings`, `getMeetingDetail`, `createMeeting`, `updateMeetingStatus`, `submitAttendanceResponse`, `getResponsesForMeeting`, `sendReminders` | 総会管理・出欠回答・リマインダー送信 |
| `FormBuilderController` | `getAllTemplates`, `getTemplate`, `getFields`, `createTemplate`, `saveFields`, `toggleActive`, `duplicateTemplate` | フォームテンプレートのビルダー操作 |
| `PortalConfigController` | `getPortalConfig`, `savePortalConfig` | ポータル設定の取得・保存 |
| `DocumentGenerationController` | `generateDocument`, `getTemplateList` | ドキュメント生成（PDF等） |

---

## 各コントローラーの詳細

### ActivityController

```apex
public with sharing class ActivityController {

    // 公開イベント一覧（Experience Cloud ゲスト対応）
    @AuraEnabled(cacheable=true)
    public static List<Activity__c> getPublicEvents() { ... }

    // 今後のイベント一覧（内部アプリ向け・全イベント）
    @AuraEnabled(cacheable=true)
    public static List<Activity__c> getUpcomingEvents() { ... }

    // イベント作成（管理者のみ）
    @AuraEnabled
    public static Activity__c createEvent(/* パラメータ */) { ... }

    // 参加登録（定員・締切チェック付き）
    @AuraEnabled
    public static ActivityParticipant__c registerForEvent(
        Id activityId,
        String participantName,
        String participantEmail,
        String organization,
        Boolean isExternalParticipant
    ) { ... }

    // イベントの参加者一覧（管理者向け）
    @AuraEnabled(cacheable=true)
    public static List<ActivityParticipant__c> getParticipantsByEvent(Id activityId) { ... }

    // 自分の参加登録履歴（認証済み会員向け）
    @AuraEnabled(cacheable=true)
    public static List<ActivityParticipant__c> getMyRegistrations() { ... }
}
```

---

### SupportInquiryController

```apex
public with sharing class SupportInquiryController {

    // 問い合わせ送信（SLA自動計算）
    @AuraEnabled
    public static SupportInquiry__c submitInquiry(
        String subject, String body,
        String priority, String inquiryType
    ) { ... }

    // エスカレーション（優先度を高に引き上げ・SLA再計算）
    @AuraEnabled
    public static void escalateInquiry(
        Id inquiryId, Id escalateTo, String reason
    ) { ... }

    // 初回返答記録（FirstResponseDate__c + IsSLAMet__c を設定）
    @AuraEnabled
    public static void respondToInquiry(Id inquiryId, String responseText) { ... }

    // 内部メモ追記（会員には非表示）
    @AuraEnabled
    public static void addInternalNote(Id inquiryId, String note) { ... }

    // SLA期限超過・未解決の問い合わせ取得
    @AuraEnabled(cacheable=true)
    public static List<SupportInquiry__c> getOverdueSLAInquiries() { ... }
}
```

---

### TeamWikiController

```apex
public with sharing class TeamWikiController {

    // 組織単位に紐付くWikiスペース一覧
    @AuraEnabled(cacheable=true)
    public static List<TeamWiki__c> getWikisByOrgUnit(Id orgUnitId) { ... }

    // WikiスペースのページリストA
    @AuraEnabled(cacheable=true)
    public static List<WikiPage__c> getWikiPages(Id wikiId) { ... }

    // Wikiページ詳細（本文 + メタデータ）
    @AuraEnabled(cacheable=true)
    public static WikiPage__c getWikiPageDetail(Id pageId) { ... }

    // ページ保存（新規作成 or 更新 + バージョン履歴保存）
    @AuraEnabled
    public static WikiPage__c savePage(
        Id wikiId, Id pageId,
        String title, String body
    ) { ... }

    // ページの変更履歴取得
    @AuraEnabled(cacheable=true)
    public static List<WikiPageVersion__c> getPageVersions(Id pageId) { ... }
}
```

---

### GeneralMeetingController

```apex
public with sharing class GeneralMeetingController {

    @AuraEnabled(cacheable=true)
    public static List<GeneralMeeting__c> getUpcomingMeetings() { ... }

    @AuraEnabled(cacheable=true)
    public static GeneralMeeting__c getMeetingDetail(Id meetingId) { ... }

    @AuraEnabled
    public static GeneralMeeting__c createMeeting(/* パラメータ */) { ... }

    @AuraEnabled
    public static void updateMeetingStatus(Id meetingId, String status) { ... }

    // 会員が出欠回答を送信
    @AuraEnabled
    public static FormResponse__c submitAttendanceResponse(
        Id meetingId,
        Map<String, Object> fieldResponses
    ) { ... }

    // 総会に対する全回答取得（管理者向け）
    @AuraEnabled(cacheable=true)
    public static List<FormResponse__c> getResponsesForMeeting(Id meetingId) { ... }

    // リマインダーメール送信
    @AuraEnabled
    public static void sendReminders(Id meetingId) { ... }
}
```

---

### FormBuilderController

```apex
public with sharing class FormBuilderController {

    @AuraEnabled(cacheable=true)
    public static List<FormTemplate__c> getAllTemplates() { ... }

    @AuraEnabled(cacheable=true)
    public static FormTemplate__c getTemplate(Id templateId) { ... }

    @AuraEnabled(cacheable=true)
    public static List<FormField__c> getFields(Id templateId) { ... }

    @AuraEnabled
    public static FormTemplate__c createTemplate(String name, String description) { ... }

    // フィールド定義を一括保存（upsert）
    @AuraEnabled
    public static void saveFields(Id templateId, List<Map<String, Object>> fields) { ... }

    // テンプレートの有効/無効切り替え
    @AuraEnabled
    public static void toggleActive(Id templateId, Boolean isActive) { ... }

    // テンプレートの複製（フィールド含む）
    @AuraEnabled
    public static FormTemplate__c duplicateTemplate(Id templateId) { ... }
}
```

---

## サービスクラス

| クラス名 | with/without sharing | 主要メソッド | 説明 |
|---|---|---|---|
| `PayjpCalloutService` | with sharing | `createChargeAsync` (@future), `createCharge`, `getPayjpPublicKey` | Pay.jp API連携（Basic Auth） |
| `PaymentGatewayService` | with sharing | `processPayment`, `getDirectDebitFormUrl`, `chargeOmise`, `chargeStripe`, `chargeFincode` | 決済プロバイダーのルーティング |
| `OktaIntegrationService` | with sharing | `processPersonnelChangeInOkta` (@future) | Okta グループ同期 |
| `SlackIntegrationService` | with sharing | `notifyPersonnelChange` (@future), `sendDirectMessage` | Slack DM・チャンネル通知 |
| `EmailNotificationService` | with sharing | `sendPersonnelChangeNotification` | 人事変更メール通知 |
| `IndividualNotificationService` | with sharing | `createAndSend`, `saveDraft`, `scheduleNotification`, `sendNotification` (@future+callout), `sendTestEmail`, `mergePlaceholders`, `getPlaceholderHelp`, `getRecentNotifications` | 個別メール通知・プレースホルダー差し込み |
| `TeamWikiSharingService` | **without sharing** | `grantOrgMemberAccess` (@future), `recalculateSharing` | Wiki Apex 管理共有の操作 |
| `WorkflowApprovalService` | with sharing | `submitForApproval`, `approve`, `reject` | 変更申請承認ワークフロー |

---

### PayjpCalloutService

```apex
public with sharing class PayjpCalloutService {

    // 非同期決済処理（Callout を @future で実行）
    @future(callout=true)
    public static void createChargeAsync(
        String amount, String currency,
        String cardToken, Id paymentId
    ) { ... }

    // 同期決済処理（同一トランザクション内で使用）
    public static Map<String, Object> createCharge(
        String amount, String currency, String cardToken
    ) { ... }

    // PortalConfiguration__c からパブリックキーを取得
    public static String getPayjpPublicKey() { ... }
}
```

!!! info "@future(callout=true) の制約"
    `createChargeAsync` は DML 後のコールアウトに使用します。同一トランザクションで DML とコールアウトを行う場合は必ず `@future` を使用してください。

---

### IndividualNotificationService

```apex
public with sharing class IndividualNotificationService {

    // 通知を作成して即時送信
    public static void createAndSend(
        Id memberId, String subject, String body,
        Id relatedObjectId, String relatedObjectType
    ) { ... }

    // 下書き保存
    public static IndividualNotification__c saveDraft(/* ... */) { ... }

    // 指定日時に送信予約
    public static void scheduleNotification(Id notificationId, Datetime scheduledAt) { ... }

    // メール送信（@future + callout）
    @future(callout=true)
    public static void sendNotification(Id notificationId) { ... }

    // テストメール送信（指定アドレスへ）
    public static void sendTestEmail(Id templateId, String toAddress) { ... }

    // プレースホルダー差し込み処理
    public static String mergePlaceholders(
        String template, Id memberId,
        Id relatedObjectId, String relatedObjectType
    ) { ... }

    // 利用可能なプレースホルダー一覧を返す
    public static List<Map<String, String>> getPlaceholderHelp() { ... }

    // 最近の通知履歴を取得
    public static List<IndividualNotification__c> getRecentNotifications(Integer limitCount) { ... }
}
```

---

## バッチ・スケジューラクラス

| クラス名 | インターフェース | バッチサイズ | スケジュール |
|---|---|---|---|
| `BatchNotificationBatch` | Batchable, Schedulable | 200 | 設定可変 |
| `PersonnelChangePublisherBatch` | Batchable, Schedulable, AllowsCallouts | **20** | 毎時0分（`0 0 * * * ?`） |

### PersonnelChangePublisherBatch

```apex
public class PersonnelChangePublisherBatch
    implements Database.Batchable<SObject>,
               Database.Schedulable,
               Database.AllowsCallouts {

    // バッチサイズ: 20（Callout を含むため小さく設定）
    public static void scheduleHourly() {
        System.schedule(
            'PersonnelChangePublisherBatch',
            '0 0 * * * ?',
            new PersonnelChangePublisherBatch()
        );
    }

    // クエリ: 発表予定 + 発表日到来 + 承認済み
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Member__c, AnnouncementStatus__c, PublicationDate__c
            FROM   PersonnelChange__c
            WHERE  AnnouncementStatus__c = '発表予定'
              AND  PublicationDate__c    <= :Datetime.now()
              AND  ApprovalStatus__c    = '承認済み'
            WITH SECURITY_ENFORCED
        ]);
    }

    public void execute(Database.BatchableContext bc,
                        List<PersonnelChange__c> scope) {
        // 1. Slack通知送信
        // 2. メール通知送信
        // 3. AnnouncementStatus__c = '発表済み', AnnouncedAt__c = now() に更新
    }
}
```

!!! warning "AllowsCallouts と バッチサイズ"
    `AllowsCallouts` を実装したバッチはバッチサイズを小さく設定する必要があります（推奨: 10〜20）。1 execute 呼び出しあたりの Callout 上限は 100 回です。

---

## クラス設計ガイドライン

!!! tip "コントローラーの共通ルール"
    1. 必ず `with sharing` で宣言する
    2. すべての SOQL に `WITH SECURITY_ENFORCED` を付与する
    3. `@AuraEnabled` メソッドは `try-catch` で例外を `AuraHandledException` に変換する
    4. DML 後のコールアウトは `@future(callout=true)` に委譲する

```apex
// 推奨パターン
@AuraEnabled
public static MyObject__c doSomething(String param) {
    try {
        // ビジネスロジック
        MyObject__c record = new MyObject__c(Field__c = param);
        insert record;
        return record;
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
```

!!! warning "without sharing は TeamWikiSharingService のみ"
    `without sharing` は Apex 管理共有（`__Share` オブジェクト操作）が必要な `TeamWikiSharingService` のみで使用します。他のクラスへの適用は禁止です。
