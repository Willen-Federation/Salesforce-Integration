# Salesforce Integration — MemberPortal

Salesforce DX プロジェクト。API v59.0 / package: MemberPortal。

## セットアップ

すべての設定は **ポータル設定（管理者）** ページ（`portalConfigAdmin` LWC）から行う。コードや CLI 操作は不要。

| 設定項目 | 場所 |
|---|---|
| 決済プロバイダー API キー (Pay.jp / Omise / Stripe / Fincode) | ポータル設定 > 各プロバイダーセクション |
| 手数料ルール（決済手段別・カテゴリ別・全体） | ポータル設定 > 手数料ルール管理 |
| 定期支払いスケジューラー ON/OFF | ポータル設定 > 定期支払いスケジューラー |
| 定期支払いプラン作成 | ポータル設定 > 定期支払いプラン管理 |
| 入金後審査（承認/却下） | ポータル設定 > 入金後審査管理 |

### Experience Cloud マイページ配置

Experience Cloud (Community) のページビルダーで `memberMyPage` コンポーネントを配置するだけで、ログイン済み会員が自分の支払い履歴・ステータス・定期プランを確認できる。

## 主要コンポーネント構成

```
portalConfigAdmin          管理者設定ポータル（APIキー・スケジューラー等）
├─ feeRuleAdmin            手数料ルール管理
├─ recurringPaymentAdmin   定期支払いプラン管理
└─ paymentReviewAdmin      入金後審査（承認/却下）

memberMyPage               会員マイページ（Experience Cloud 用）
└─ paymentTimeline         支払いステータス時系列

paymentForm                会員の支払い処理（VF iframe 経由）
invoiceCreationAdmin       管理者の請求発行フォーム
```

## 主要 Apex クラス

| クラス | 役割 |
|---|---|
| `PaymentController` | 支払い CRUD・即時通知 |
| `PaymentFeeRuleController` | 手数料ルール計算 |
| `PaymentReviewService` | 入金後審査ワークフロー |
| `PaymentStatusHistoryService` | ステータス変更履歴記録 |
| `RecurringPaymentScheduler` | 定期支払い自動生成（Schedulable） |
| `PortalMemberController` | マイページ API（Experience Cloud 向け） |
| `PortalSchedulerController` | スケジューラー ON/OFF 管理 |
| `PaymentGatewayService` | Pay.jp / Omise / Stripe チャージ処理 |
| `EmailNotificationService` | メール通知（全種別） |
| `SlackIntegrationService` | Slack 通知 |
