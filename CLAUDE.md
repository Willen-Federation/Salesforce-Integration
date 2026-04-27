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
| 一括通知配信（CSV テンプレート） | ポータル設定 > 一括通知配信 |

### Experience Cloud マイページ配置

Experience Cloud (Community) のページビルダーで `memberMyPage` コンポーネントを配置するだけで、ログイン済み会員が自分の支払い履歴・ステータス・定期プランを確認できる。

ログインページには `portalLogin` コンポーネントを配置する。Okta OIDC が設定済みの場合は「Okta でログイン」ボタンが表示される。

### Okta OIDC 設定手順（管理者作業・1回のみ）

1. **Okta 側**: アプリ統合を作成 → OIDC Web Application → Sign-in redirect URI に `https://<your-sf-domain>/services/auth/sso/okta` を登録
2. **Salesforce 設定 > ID > 認証プロバイダー > 新規 > OpenID Connect**
   - URL サフィックス: `okta`
   - コンシューマーキー/シークレット: Okta の Client ID / Secret
   - 承認エンドポイント: `https://<okta-domain>/oauth2/default/v1/authorize`
   - トークンエンドポイント: `https://<okta-domain>/oauth2/default/v1/token`
   - ユーザー情報エンドポイント: `https://<okta-domain>/oauth2/default/v1/userinfo`
   - デフォルトスコープ: `openid profile email`
   - 登録ハンドラー: `OktaOidcRegistrationHandler`
3. **ポータル設定** > Okta設定 セクション に OktaドメインURL と API トークンを入力
4. Experience Cloud > Administration > Login & Registration で認証プロバイダー `okta` を有効化

## 主要コンポーネント構成

```
portalConfigAdmin          管理者設定ポータル（APIキー・スケジューラー等）
├─ feeRuleAdmin            手数料ルール管理
├─ recurringPaymentAdmin   定期支払いプラン管理
├─ paymentReviewAdmin      入金後審査（承認/却下）
└─ bulkNotificationAdmin   一括通知配信（CSV テンプレート方式）

portalLogin                ポータルログインページ（Okta OIDC + メールリンク）

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
| `BulkNotificationController` | 一括通知 CSV 生成・パース・送信 |
| `OktaLoginController` | ポータルログイン設定・セッション確認 |
| `OktaOidcRegistrationHandler` | Okta OIDC ユーザー登録/更新ハンドラー |
