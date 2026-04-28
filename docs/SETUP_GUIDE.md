# MemberPortal セットアップガイド

> このガイドは **Salesforce の操作に慣れていない方** でも読み進められるよう、画面操作を中心に説明しています。
> CLI（コマンド操作）の詳細は末尾の [上級者向け: CLI リファレンス](#上級者向け-cli-リファレンス) を参照してください。

---

## 所要時間の目安

| フェーズ | 作業 | 目安 |
|---|---|---|
| Phase 1 | メタデータのデプロイ | 10〜15 分 |
| Phase 2 | ウィザードによるポータル設定 | 10 分 |
| Phase 3 | Named Credentials の設定 | 5〜10 分 |
| Phase 4 | Experience Cloud の設定 | 10〜15 分 |
| Phase 5 | 権限セットの割り当て | 5 分 |

---

## 目次

1. [前提条件の確認](#1-前提条件の確認)
2. [メタデータのデプロイ（初回のみ）](#2-メタデータのデプロイ初回のみ)
3. [セットアップウィザードで設定する](#3-セットアップウィザードで設定する)
4. [Named Credentials を設定する](#4-named-credentials-を設定する)
5. [Experience Cloud サイトを設定する](#5-experience-cloud-サイトを設定する)
6. [権限セットを割り当てる](#6-権限セットを割り当てる)
7. [スケジューラーの確認](#7-スケジューラーの確認)
8. [動作確認チェックリスト](#8-動作確認チェックリスト)
9. [上級者向け: CLI リファレンス](#上級者向け-cli-リファレンス)

---

## 1. 前提条件の確認

### Salesforce 組織

| 確認項目 | 内容 |
|---|---|
| エディション | Enterprise Edition 以上（Unlimited / Developer も可） |
| Experience Cloud | ライセンスが有効であること |
| My Domain | 設定済みであること |
| API バージョン | v59.0 以上 |

> **Salesforce のエディションを確認する方法**  
> Salesforce にログイン → 右上のユーザーアイコン → 「設定」→ 検索ボックスで「会社情報」と入力 → エディションが表示されます。

### 必要な外部サービスの情報

| サービス | 必要な情報 | 用途 |
|---|---|---|
| **決済プロバイダー** | 公開キー・シークレットキー | 会員からの支払い処理 |
| **Slack** | Bot Token（`xoxb-...`）| 通知（任意） |
| **Okta** | ドメイン URL・API トークン | SSO ログイン（任意） |

---

## 2. メタデータのデプロイ（初回のみ）

> ここでは Salesforce CLI（`sf`）を使います。CLI のインストール方法は [こちら](https://developer.salesforce.com/tools/salesforcecli) を参照してください。

### 手順

**ステップ 1: リポジトリを取得する**

```bash
git clone https://github.com/Willen-Federation/salesforce-integration.git
cd salesforce-integration
```

**ステップ 2: Salesforce 組織にログインする**

```bash
# ブラウザが開きます。デプロイ先の組織にシステム管理者でログインしてください
sf org login web --alias member-portal-org

# サンドボックスの場合
sf org login web --alias member-portal-sandbox \
  --instance-url https://test.salesforce.com
```

**ステップ 3: デプロイを実行する**

```bash
# 【推奨】先に検証だけ行う（実際にはデプロイしない）
sf project deploy validate \
  --source-dir force-app \
  --target-org member-portal-org \
  --test-level RunLocalTests

# 問題なければ実際にデプロイ
sf project deploy start \
  --source-dir force-app \
  --target-org member-portal-org \
  --test-level RunLocalTests
```

デプロイには 3〜15 分程度かかります。

**ステップ 4: デプロイ結果を確認する**

```bash
sf project deploy report --use-most-recent
```

すべてのコンポーネントが `Succeeded` になっていれば完了です。

> **デプロイが失敗した場合**  
> エラーメッセージを確認してください。よくある原因: Apex コンパイルエラー（依存オブジェクトが未作成）、権限不足（システム管理者でない）、API バージョン不一致。

---

## 3. セットアップウィザードで設定する

デプロイが完了したら、Salesforce 画面上のウィザードで設定を行います。ウィザードを使うと、ポータルの基本設定・決済設定・年会費設定などを画面に従って入力するだけで自動的に保存されます。

### ウィザードの起動方法

1. Salesforce にシステム管理者でログイン
2. 画面右上の **アプリケーションランチャー**（格子状のアイコン）をクリック
3. 検索ボックスで「**セットアップウィザード**」と入力
4. 「ポータル 初期セットアップウィザード」タブをクリック

> **タブが表示されない場合**  
> まだ権限セット `MemberPortalAdmin` が割り当てられていない可能性があります。  
> 先に [6. 権限セットを割り当てる](#6-権限セットを割り当てる) を実施してから戻ってきてください。

---

### ウィザード 各ステップの説明

#### ステップ 1: 準備（ようこそ画面）

必要な情報のチェックリストが表示されます。準備ができたら「**次へ**」をクリックしてください。

---

#### ステップ 2: 基本設定

| 入力項目 | 説明 | 例 |
|---|---|---|
| **組織名** ※必須 | メール送信者名・画面タイトルとして表示 | `株式会社○○` |
| **送信元メールアドレス** ※必須 | 会員へのメール通知の送信元 | `noreply@your-org.com` |
| **ポータルの URL** ※必須 | Experience Cloud サイトの URL | `https://your-org.my.site.com/member` |
| Slack 通知を有効にする | ON にすると Slack 設定欄が表示される | — |
| Slack Bot Token | Slack アプリの Bot User OAuth Token | `xoxb-...` |
| サポート通知チャネル ID | 問い合わせ通知を送る Slack チャネル | `C01234ABCDE` |

> **ポータルの URL を確認する方法**  
> Setup → 検索で「デジタルエクスペリエンス」→「すべてのサイト」→ 会員ポータルサイトの URL 欄に表示されます。

> **Slack Bot Token の取得方法**  
> 1. [api.slack.com/apps](https://api.slack.com/apps) → 「Create New App」→「From Scratch」  
> 2. アプリ名を入力してワークスペースを選択  
> 3. 左メニュー「OAuth & Permissions」→「Bot Token Scopes」で `chat:write` を追加  
> 4. ページ上部「Install to Workspace」をクリック  
> 5. 表示された `Bot User OAuth Token（xoxb-...）` をコピー

---

#### ステップ 3: 決済プロバイダー設定

使用する決済プロバイダーをドロップダウンから選択すると、そのプロバイダーの設定欄が表示されます。

| プロバイダー | API キーの確認場所 |
|---|---|
| **GMO あおぞら** | [GMO あおぞら法人向けサイト](https://gmo-aozora.com/business/) から契約後に取得 |
| **Pay.jp** | [Pay.jp ダッシュボード](https://pay.jp/d/apikeys) → 「API」メニュー |
| **Omise** | [Omise ダッシュボード](https://dashboard.omise.co/test/api-keys) → 「API Keys」 |
| **Stripe** | [Stripe ダッシュボード](https://dashboard.stripe.com/apikeys) → 「Developers → API Keys」 |
| **Fincode** | Fincode 管理ダッシュボード → 「API キー」 |

> **テストキーと本番キーの違い**  
> 各プロバイダーには「テスト用」と「本番用」の 2 種類のキーがあります。  
> 本番運用を開始するまでは必ずテスト用キーを使い、「環境」を「テスト」に設定してください。  
> テスト環境では実際の課金は発生しません。

---

#### ステップ 4: 年会費設定

会員種別ごとの年会費を円で入力します。設定しない場合は空欄のまま進んでください（後から変更できます）。

| 会員種別 | 例 |
|---|---|
| 個人会員 | 12,000 円 |
| 法人会員 | 50,000 円 |
| 学生会員 | 3,000 円 |
| 賛助会員 | 30,000 円 |

---

#### ステップ 5: 認証設定（Okta SSO）

Okta を使用しない場合は「**スキップ**」ボタンをクリックしてください。

Okta を使用する場合は「Okta SSO を使用する」にチェックを入れ、以下を入力します。

| 入力項目 | 説明 | 例 |
|---|---|---|
| **Okta ドメイン URL** | Okta 管理コンソールの URL | `https://your-company.okta.com` |
| **Okta API トークン** | SSWS 形式のトークン | `SSWS xxxxxxxx...` |

> **Okta API トークンの取得方法**  
> 1. Okta 管理コンソール（`your-domain.okta.com/admin`）にログイン  
> 2. 左メニュー「Security」→「API」→「Tokens」タブ  
> 3. 「Create Token」をクリックして名前を入力  
> 4. 表示されたトークンをコピー

> **注意**: Okta SSO を有効にするには、このウィザード外でも Salesforce 側・Okta 側の設定が必要です。完了ステップの「Okta SSO の残り設定」を参照してください。

---

#### ステップ 6: 完了画面

設定が保存され、残りの手動設定のガイドが表示されます。  
「**定期支払いスケジューラーを有効化**」ボタンを押すと、スケジューラーがその場で起動します。

---

## 4. Named Credentials を設定する

**Named Credentials（名前付き資格情報）** とは、Salesforce が外部 API（決済サービスや Slack など）に接続するときの認証情報を安全に保管する場所です。

> **なぜ必要なのか**  
> ウィザードで入力した API キーは「設定値」として保存されますが、Salesforce が実際に外部 API を呼び出す際には Named Credentials の認証情報が使われます。  
> この設定が未完了だと、決済処理・Slack 通知・Okta 認証が動作しません。

### 開き方

1. Salesforce 画面右上の **歯車アイコン** → 「Setup」（設定）
2. 左の検索ボックスで「**Named Credentials**」と入力
3. 「セキュリティ → Named Credentials」をクリック
4. 設定したい Named Credential の名前をクリックし、「編集」をクリック

---

### 各 Named Credential の設定値

#### PayjpAPI（Pay.jp を使う場合）

| 項目 | 設定値 |
|---|---|
| 名前 | `PayjpAPI` |
| URL | `https://api.pay.jp/v1` |
| 認証プロトコル | カスタムヘッダー |
| ヘッダー名 | `Authorization` |
| ヘッダー値 | `Basic [シークレットキーを Base64 エンコードした値]` |

> **Base64 エンコードの方法**  
> シークレットキーの後ろにコロン（`:`）を付けた文字列を Base64 エンコードします。  
> 例: `sk_test_xxxx:` → Base64 エンコード → `c2tfdGVzdF94eHh4Og==`  
> Mac/Linux: `echo -n 'sk_test_xxxx:' | base64`

#### OmiseAPI（Omise を使う場合）

| 項目 | 設定値 |
|---|---|
| URL | `https://api.omise.co` |
| 認証プロトコル | パスワード認証（Basic） |
| ユーザー名 | Omise のシークレットキー（`skey_...`） |
| パスワード | （空欄のまま） |

#### StripeAPI（Stripe を使う場合）

| 項目 | 設定値 |
|---|---|
| URL | `https://api.stripe.com` |
| 認証プロトコル | カスタムヘッダー |
| ヘッダー名 | `Authorization` |
| ヘッダー値 | `Bearer sk_live_...`（テスト環境は `sk_test_...`） |

#### FincodeAPI（Fincode を使う場合）

| 項目 | 設定値 |
|---|---|
| URL | `https://api.fincode.jp/v2` |
| 認証プロトコル | カスタムヘッダー |
| ヘッダー名 | `Authorization` |
| ヘッダー値 | `Bearer [Fincode API キー]` |

#### SlackAPI（Slack 通知を使う場合）

| 項目 | 設定値 |
|---|---|
| URL | `https://slack.com/api` |
| 認証プロトコル | カスタムヘッダー |
| ヘッダー名 | `Authorization` |
| ヘッダー値 | `Bearer xoxb-...`（Bot Token） |

#### OktaAPI（Okta SSO を使う場合）

| 項目 | 設定値 |
|---|---|
| URL | `https://[あなたのOktaドメイン].okta.com` |
| 認証プロトコル | カスタムヘッダー |
| ヘッダー名 | `Authorization` |
| ヘッダー値 | `SSWS [Okta API トークン]` |

#### GmoAozoraAPI（GMO あおぞらサンドボックス）

| 項目 | 設定値 |
|---|---|
| URL | `https://api.sandbox.gmo-aozora.com` |
| 認証プロトコル | OAuth 2.0 |

#### GmoAozoraAPI_Prod（GMO あおぞら本番）

| 項目 | 設定値 |
|---|---|
| URL | `https://api.gmo-aozora.com` |
| 認証プロトコル | OAuth 2.0 |

---

## 5. Experience Cloud サイトを設定する

**Experience Cloud** は、Salesforce の「会員向け外部ポータル」機能です。会員が実際にアクセスするサイトの公開・ページ構成を設定します。

### 5-1. サイトを公開する

1. Setup の検索ボックスで「**デジタルエクスペリエンス**」と入力
2. 「デジタルエクスペリエンス → **すべてのサイト**」をクリック
3. 会員ポータルのサイトが一覧に表示されていることを確認
4. ステータスが「**プレビュー**」または「**非公開**」の場合は「**公開**」ボタンをクリック
5. 表示されたサイト URL を控えておく（ウィザードの「ポータルの URL」に使用）

### 5-2. ページにコンポーネントを配置する

1. 「**サイトビルダー**」ボタンをクリック（ビジュアルエディタが開きます）
2. 左上のページ一覧から設定したいページを選択
3. 左側の「コンポーネント」パネルから該当コンポーネントをドラッグ＆ドロップでページに配置
4. 配置が完了したら「**公開**」ボタンをクリック

| ページ名 | 配置するコンポーネント | 説明 |
|---|---|---|
| ログインページ | `portalLogin` | Okta ボタン・メールリンク認証 |
| ホーム | `memberPortalDashboard` | ダッシュボード |
| マイページ | `memberMyPage` | 支払い履歴・定期プラン確認 |
| 支払いフォーム | `paymentForm` | 決済処理 |
| 会員登録 | `memberRegistrationForm` | 新規会員登録フォーム |
| 寄付 | `donationForm` | 寄付フォーム（任意） |
| 組織図 | `orgChartViewer` | 組織図（任意） |
| 活動登録 | `activityRegistration` | 活動登録（任意） |
| 変更申請 | `changeRequestForm` | プロフィール変更申請（任意） |
| サポート問い合わせ | `supportInquiryForm` | 問い合わせフォーム |
| 総会申込 | `generalMeetingForm` | 総会参加申込（任意） |
| チームWiki | `teamWikiViewer` | チーム情報共有（任意） |

### 5-3. ゲストユーザーのアクセス設定

ログインしていない訪問者（ゲストユーザー）には、必要最小限の権限のみ付与します。

1. Setup → デジタルエクスペリエンス → すべてのサイト → [サイト名] → 「**管理**」をクリック
2. 「**メンバー**」タブを開く
3. ゲストユーザープロファイルで `Member__c` オブジェクトへの参照権限が **付与されていない** ことを確認

> **注意**: ゲストユーザーが会員データを参照できてしまうと、個人情報漏洩のリスクがあります。

---

## 6. 権限セットを割り当てる

**権限セット** は、ユーザーに操作権限をまとめて付与する仕組みです。ポータルには 2 種類の権限セットがあります。

| 権限セット名 | 付与するユーザー | 付与される権限 |
|---|---|---|
| `MemberPortalAdmin` | ポータル管理者 | 設定変更・会員管理・請求発行・審査操作 |
| `MemberPortalUser` | 一般会員ユーザー | マイページ参照・支払い実行 |

### 設定手順

1. Setup の検索ボックスで「**権限セット**」と入力 → 「権限セット」をクリック
2. 「**MemberPortalAdmin**」をクリック
3. 「割り当てを管理」→「割り当てを追加」→ 管理者として設定するユーザーを選択 →「割り当て」
4. 同様に「**MemberPortalUser**」→「割り当てを管理」→ 会員ユーザー全員を追加

> **MemberPortalAdmin について**  
> この権限セットを持つユーザーだけが「セットアップウィザード」と「ポータル設定（管理者）」タブを表示・操作できます。  
> Experience Cloud サイト（会員向けページ）には公開しないよう注意してください。

---

## 7. スケジューラーの確認

定期支払いを自動生成するバッチジョブが正しく動作しているか確認します。

### 確認方法

1. Setup の検索ボックスで「**スケジュール済み Apex**」と入力
2. 以下のジョブが表示されていることを確認:

| ジョブ名 | 頻度 | 説明 |
|---|---|---|
| `定期支払い生成` | 毎日 01:00 | 定期支払いプランから Payment を自動生成 |
| `PersonnelChangePublisherBatch` | 毎時間 | 人事異動の予約適用 |

### ジョブが表示されない場合

ウィザードの「完了」ステップの「スケジューラーを有効化」ボタンで `定期支払い生成` ジョブを有効化できます。

`PersonnelChangePublisherBatch` は以下の操作で登録します：

1. Setup → 「**開発者コンソール**」を開く（右上のユーザーアイコン → 開発者コンソール）
2. 「Debug」→「Open Execute Anonymous Window」をクリック
3. 以下のコードを貼り付けて「Execute」ボタンをクリック

```apex
PersonnelChangePublisherBatch.scheduleHourly();
System.debug('スケジュール登録完了');
```

---

## 8. 動作確認チェックリスト

すべての設定が完了したら、以下の項目を順番に確認してください。

### デプロイ確認

- [ ] デプロイ結果でエラーが 0 件であること
- [ ] Apex テストが全クラス合格（カバレッジ 75% 以上）

### 設定確認

- [ ] ウィザード（または「ポータル設定（管理者）」）で組織名・メール・URL が設定済み
- [ ] 使用する決済プロバイダーの API キーが設定済み
- [ ] 使用する Named Credentials の認証情報が設定済み

### 画面・機能確認

- [ ] Experience Cloud サイトが「公開済み」状態
- [ ] ログインページに `portalLogin` コンポーネントが配置済み
- [ ] ホームページに `memberPortalDashboard` が表示される
- [ ] 支払いフォームが表示され、決済プロバイダーが表示される
- [ ] `MemberPortalAdmin` が管理者ユーザーに割り当て済み

### Okta 確認（Okta を使用する場合）

- [ ] Okta 管理コンソールで OIDC アプリが作成済み
- [ ] Salesforce Setup で認証プロバイダー「Okta」が登録済み
- [ ] Experience Cloud のログイン設定で「Okta」が有効
- [ ] テストユーザーで Okta SSO ログインが成功する

### スケジューラー確認

- [ ] 「定期支払い生成」ジョブがスケジュール済み Apex に表示される
- [ ] 「PersonnelChangePublisherBatch」ジョブが表示される

---

## トラブルシューティング

| 症状 | 考えられる原因 | 対処方法 |
|---|---|---|
| 決済処理でエラーが出る | Named Credential の API キーが未設定または誤り | 4章の手順で Named Credential を再設定 |
| Slack 通知が届かない | `SlackBotToken` または Named Credential が無効 | Slack アプリ管理画面でトークンを再発行 |
| Okta でログインできない | Salesforce 認証プロバイダーの設定ミス | URL サフィックス `okta`、登録ハンドラー `OktaOidcRegistrationHandler` を再確認 |
| ウィザードタブが表示されない | `MemberPortalAdmin` 権限セットが未割り当て | 6章の手順で権限セットを割り当て |
| 定期支払いが生成されない | スケジューラーが未登録 | ウィザード完了画面の「スケジューラーを有効化」を押す |
| デプロイが失敗する | Apex コンパイルエラー | エラーログの行番号を確認し、該当 Apex クラスを修正 |

---

## 上級者向け: CLI リファレンス

CLI での操作が必要な場合のコマンド一覧です。

### 認証

```bash
# 本番組織
sf org login web --alias member-portal-org

# サンドボックス
sf org login web --alias member-portal-sandbox \
  --instance-url https://test.salesforce.com

# JWT 認証（CI/CD 用）
sf org login jwt \
  --client-id    "$SF_CONSUMER_KEY" \
  --jwt-key-file server.key \
  --username     "$SF_USERNAME" \
  --alias        production
```

### デプロイ

```bash
# 検証のみ
sf project deploy validate \
  --source-dir force-app \
  --target-org member-portal-org \
  --test-level RunLocalTests

# デプロイ実行
sf project deploy start \
  --source-dir force-app \
  --target-org member-portal-org \
  --test-level RunLocalTests
```

### テスト実行

```bash
# 全テスト
sf apex run test --target-org member-portal-org --wait 10

# 特定クラス
sf apex run test \
  --target-org member-portal-org \
  --class-names PaymentGatewayServiceTest \
  --wait 10
```

### 権限セット割り当て

```bash
sf org assign permset \
  --name MemberPortalAdmin \
  --on-behalf-of admin@example.com \
  --target-org member-portal-org
```

### スケジューラー登録（匿名 Apex）

```bash
sf apex run \
  --target-org member-portal-org \
  --file scripts/apex/schedule-batch.apex
```

`scripts/apex/schedule-batch.apex` の内容:

```apex
PersonnelChangePublisherBatch.scheduleHourly();
System.debug('PersonnelChangePublisherBatch 登録完了');
```

### GitHub Actions: 必要な Secrets

**sandbox 環境**

| Secret 名 | 説明 |
|---|---|
| `SF_JWT_PRIVATE_KEY` | JWT 認証用秘密鍵（PEM 形式） |
| `SF_CONSUMER_KEY_SANDBOX` | Connected App の Consumer Key |
| `SF_USERNAME_SANDBOX` | デプロイ実行ユーザー名 |

**production 環境**

| Secret 名 | 説明 |
|---|---|
| `SF_JWT_PRIVATE_KEY_PROD` | JWT 認証用秘密鍵（本番） |
| `SF_CONSUMER_KEY_PROD` | Connected App の Consumer Key（本番） |
| `SF_USERNAME_PROD` | デプロイ実行ユーザー名（本番） |
