# 変更履歴

Willen 会員ポータルの変更履歴です。[Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) の形式に従っています。

---

## [3.0.0] — 2025年1月（Phase 3）

Phase 3 では、チームWiki・総会管理・フォームビルダー・個別通知コンポーザー・人事変更スケジューリング機能を追加しました。

### 追加

#### チームWiki

| 追加内容 | 詳細 |
|---|---|
| `TeamWiki__c` カスタムオブジェクト | 組織単位に紐付くWikiスペース（OWD=Private） |
| `WikiPage__c` カスタムオブジェクト | ControlledByParent。Markdown 本文を格納 |
| `WikiPageVersion__c` カスタムオブジェクト | Wikiページのバージョン履歴 |
| `teamWikiViewer` LWC | Wiki閲覧・インライン編集コンポーネント |
| `teamWikiEditor` LWC | スタンドアロンWikiエディター（フルスクリーン） |
| `TeamWikiController` Apex クラス | Wiki CRUD操作（`getWikisByOrgUnit`, `savePage`, `getPageVersions`等） |
| `TeamWikiSharingService` Apex クラス | `without sharing` による Apex 管理共有操作 |
| Wiki共有ルール | 全会員/外部公開/管理者それぞれの共有ルールを設定 |

!!! info "Apex 管理共有"
    `AccessLevel__c = '組織メンバーのみ'` のWikiは `TeamWikiSharingService.grantOrgMemberAccess()` が `TeamWiki__Share` を操作して動的に共有します。

---

#### 総会管理

| 追加内容 | 詳細 |
|---|---|
| `GeneralMeeting__c` カスタムオブジェクト | 定期総会・臨時総会の開催情報 |
| `generalMeetingForm` LWC | 出欠回答フォーム（会員・管理者モード切替） |
| `GeneralMeetingController` Apex クラス | 総会 CRUD・出欠集計・リマインダー送信 |

---

#### フォームビルダー

| 追加内容 | 詳細 |
|---|---|
| `FormTemplate__c` カスタムオブジェクト | 動的フォームの定義（質問構成） |
| `FormField__c` カスタムオブジェクト | ControlledByParent。個別フィールド定義 |
| `FormResponse__c` カスタムオブジェクト | MasterDetail→FormTemplate__c。会員の回答 |
| `FormFieldResponse__c` カスタムオブジェクト | 個別フィールドへの回答値 |
| `formBuilderAdmin` LWC | フォームテンプレートビルダー（管理者専用） |
| `FormBuilderController` Apex クラス | テンプレート CRUD・フィールド保存・複製 |
| FormResponse 自動保存 | 回答送信時に確認メールを自動送信 |

---

#### 個別通知コンポーザー

| 追加内容 | 詳細 |
|---|---|
| `IndividualNotification__c` カスタムオブジェクト | 管理者から会員への個別メール通知 |
| `individualNotificationComposer` LWC | 通知作成・送信予約・下書き保存 UI |
| `IndividualNotificationService` Apex クラス | 通知送信・スケジューリング・プレースホルダー処理 |
| プレースホルダー差し込み | `mergePlaceholders()` による `{!Member.*}` 等の自動置換 |
| テストメール送信 | `sendTestEmail()` で自分のアドレスへの動作確認 |
| プレースホルダーヘルプ | `getPlaceholderHelp()` が利用可能なプレースホルダー一覧を返す |

---

#### 人事変更スケジューリング

| 追加内容 | 詳細 |
|---|---|
| `AnnouncementStatus__c` フィールド（PersonnelChange__c） | `発表予定` / `発表済み` のステータス管理 |
| `PublicationDate__c` フィールド（PersonnelChange__c） | 発表予定日（この日時が到来したら自動発表） |
| `AnnouncedAt__c` フィールド（PersonnelChange__c） | 実際の発表日時 |
| `PersonnelChangePublisherBatch` | 毎時実行のスケジューラ。承認済み・期限到来の人事変更を自動発表 |

```apex
// Phase 3 以降: 以下のコマンドでスケジューラを登録
PersonnelChangePublisherBatch.scheduleHourly();
```

---

## [2.0.0] — 2024年12月（Phase 2）

Phase 2 では、賛助会員対応・複数決済プロバイダー統合・イベント管理・SLAサポートチケット機能を追加しました。

### 追加

#### 賛助会員対応

| 追加内容 | 詳細 |
|---|---|
| 賛助会員（Supporting member type） | `MemberType__c` に `'賛助会員'` を追加 |
| `AnnualFeeSupporting__c` フィールド | `PortalConfiguration__c` に賛助会員年会費フィールドを追加 |
| `donorRegistrationView` LWC | 寄附者一覧管理画面（管理者専用） |

---

#### 決済機能強化

| 追加内容 | 詳細 |
|---|---|
| Pay.jp 決済対応 | `PayjpCalloutService`（Basic Auth、テスト/本番モード切替） |
| Omise 決済対応 | `PaymentGatewayService.chargeOmise()` |
| Stripe 決済対応 | `PaymentGatewayService.chargeStripe()` |
| Fincode 決済対応 | `PaymentGatewayService.chargeFincode()` |
| `PaymentGatewayService` | プロバイダーを動的にルーティングする統合サービス |
| 口座振替申込書ダウンロード | `DirectDebitFormUrl__c` から外部フォームURLへリダイレクト |

---

#### ポータル設定管理

| 追加内容 | 詳細 |
|---|---|
| `PortalConfiguration__c` カスタムオブジェクト | 決済キー・Okta設定・年会費を一元管理 |
| `portalConfigAdmin` LWC | 管理者向け設定 UI（AppPage/Tab） |
| `PortalConfigController` Apex クラス | `getPortalConfig`, `savePortalConfig`（SetupOwnerId upsert） |

---

#### イベント・活動管理

| 追加内容 | 詳細 |
|---|---|
| `Activity__c` カスタムオブジェクト | イベント定義（公開/非公開・定員・参加費） |
| `ActivityParticipant__c` カスタムオブジェクト | ControlledByParent。参加者1名1レコード |
| `activityEventPortal` LWC | イベントカードグリッド・参加登録（Experience Cloud + 内部アプリ対応） |
| `activityRegistration` LWC | スタンドアロン参加登録コンポーネント |
| `ActivityController` Apex クラス | イベント作成・公開・参加登録・定員管理 |

---

#### サポートチケット・SLA管理

| 追加内容 | 詳細 |
|---|---|
| `SupportInquiry__c` カスタムオブジェクト | SLA追跡・エスカレーション対応の問い合わせ管理 |
| `supportInquiryForm` LWC | 会員向けチケット送信 + 管理者向けSLA管理 UI |
| `SupportInquiryController` Apex クラス | `submitInquiry`, `escalateInquiry`, `respondToInquiry`, `addInternalNote`, `getOverdueSLAInquiries` |
| SLA自動計算 | 優先度（高=4h, 中=24h, 低=72h）から `SLADeadline__c` を自動設定 |
| エスカレーション機能 | 優先度を高に引き上げ・SLA再計算・担当者設定 |

---

## [1.0.0] — 2024年6月（Phase 1）

初回リリース。会員管理・組織図・人事変更・Okta/Slack 連携の基盤を構築しました。

### 追加

#### コアオブジェクト

| 追加内容 | 詳細 |
|---|---|
| `Member__c` カスタムオブジェクト | 会員の基本情報（OWD=Private） |
| `Payment__c` カスタムオブジェクト | 年会費・支払い記録 |
| `OrgUnit__c` カスタムオブジェクト | 部署・チームの組織階層（自己参照） |
| `PersonnelChange__c` カスタムオブジェクト | 異動・昇進・退職等の人事変更記録 |
| `ChangeRequest__c` カスタムオブジェクト | 組織変更申請の承認ワークフロー |

---

#### LWC コンポーネント（初期セット）

| コンポーネント | 説明 |
|---|---|
| `memberPortalDashboard` | ポータルホーム画面 |
| `memberRegistrationForm` | 会員登録フォーム |
| `paymentForm` | 支払い処理画面（Phase 1 は単一プロバイダー） |
| `orgChartViewer` | インタラクティブ組織図 |

---

#### Okta SAML/JIT 連携

| 追加内容 | 詳細 |
|---|---|
| SAML 2.0 SP-Initiated SSO | Salesforce を SP として Okta と連携 |
| JIT プロビジョニング | 初回ログイン時に Salesforce ユーザーを自動作成 |
| `OktaIntegrationService` | Okta グループ同期（`@future(callout=true)`） |
| `OktaUserId__c` フィールド | `Member__c` に Okta の内部ユーザーIDを保存 |

---

#### Slack 通知

| 追加内容 | 詳細 |
|---|---|
| `SlackIntegrationService` | 人事変更通知・DM送信（Bot Token 方式） |
| `SlackUserId__c` フィールド | `Member__c` に Slack の内部ユーザーIDを保存 |
| 人事変更チャンネル通知 | 人事変更確定時に `#personnel-announcements` へ自動投稿 |

---

## バージョン命名規則

| フォーマット | 意味 |
|---|---|
| `X.0.0` | メジャーリリース（Phase 単位の大規模追加） |
| `X.Y.0` | マイナーリリース（機能追加・改善） |
| `X.Y.Z` | パッチリリース（バグ修正・小規模修正） |
