# 外部連携リファレンス

Willen 会員ポータルが連携する外部サービスの設定・認証方式・実装クラスを説明します。

---

## 連携サービス一覧

| サービス | 用途 | 認証方式 | Named Credential | 実装クラス |
|---|---|---|---|---|
| **Okta** | SAML 2.0 SSO / JIT | SAML + API Token | `OktaAPI` | `OktaIntegrationService` |
| **Slack** | DM・チャンネル通知 | Bot Token (Bearer) | `SlackAPI` | `SlackIntegrationService` |
| **Pay.jp** | クレジットカード決済 | Basic Auth（Secret Key） | `PayjpAPI` | `PayjpCalloutService` |
| **Omise** | クレジットカード決済 | Basic Auth（Secret Key） | `OmiseAPI` | `PaymentGatewayService` |
| **Stripe** | クレジットカード決済 | Bearer Token | `StripeAPI` | `PaymentGatewayService` |
| **Fincode** | クレジットカード決済 | API Key Header | `FincodeAPI` | `PaymentGatewayService` |

---

## 1. Okta（SAML 2.0 + JIT）

### 概要

Okta は SP-Initiated SAML 2.0 で Salesforce Experience Cloud との SSO を実現します。初回ログイン時に JIT（Just-in-Time）プロビジョニングにより Salesforce ユーザーが自動作成されます。

### 認証フロー

```
会員がポータルにアクセス
    │
    ▼
Salesforce（SP）が AuthnRequest を生成
    │
    ▼
Okta（IdP）へリダイレクト
    │
    ▼
会員が Okta でログイン（MFA対応）
    │
    ▼
SAML Assertion を Salesforce へ POST
    │
    ├── ユーザーが存在する → 既存ユーザーでログイン
    └── ユーザーが存在しない → JIT プロビジョニング
            │
            ▼
        Salesforce ユーザーを自動作成
        OktaUserId__c を Member__c に保存
        OktaIntegrationService.processPersonnelChangeInOkta() 呼び出し
```

### Okta グループ同期

```apex
// OktaIntegrationService（@future で非同期実行）
@future(callout=true)
public static void processPersonnelChangeInOkta(
    Id personnelChangeId
) {
    // 1. PersonnelChange__c から変更内容を取得
    // 2. Named Credential 'OktaAPI' を使ってOkta REST APIを呼び出し
    // 3. Oktaグループ（= OrgUnit__c）のメンバーシップを更新
    // 4. Member__c.OktaUserId__c を保存
}
```

!!! info "Okta グループ = OrgUnit__c"
    Okta のグループ（部署・チーム）は `OrgUnit__c` と1対1で対応します。人事変更が発生すると `OktaIntegrationService` が Okta グループメンバーシップを自動更新します。

### Named Credential 設定（OktaAPI）

| 項目 | 値 |
|---|---|
| ラベル | OktaAPI |
| URL | `https://<your-domain>.okta.com/api/v1` |
| 認証プロトコル | Named Principal |
| 認証ヘッダー | `Authorization: SSWS <APIToken>` |

---

## 2. Slack

### 概要

Slack Bot Token を使用して、人事変更の発表通知・バッチ処理結果の通知・管理者への DM 送信を行います。

### 通知チャンネル

| チャンネル | 通知内容 | 送信メソッド |
|---|---|---|
| `#personnel-announcements` | 人事変更の発表通知 | `SlackIntegrationService.notifyPersonnelChange()` |
| バッチ処理チャンネル | バッチ通知 | `BatchNotificationBatch` |
| DM（個人） | 個別メッセージ | `SlackIntegrationService.sendDirectMessage()` |

### 実装

```apex
public with sharing class SlackIntegrationService {

    // 人事変更の発表通知（@future で非同期）
    @future(callout=true)
    public static void notifyPersonnelChange(Id personnelChangeId) {
        // Named Credential 'SlackAPI' を使用
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SlackAPI/chat.postMessage');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // チャンネルとメッセージ本文を設定
    }

    // 特定ユーザーへのDM送信
    @future(callout=true)
    public static void sendDirectMessage(String slackUserId, String message) {
        // Member__c.SlackUserId__c を使用
    }
}
```

### Named Credential 設定（SlackAPI）

| 項目 | 値 |
|---|---|
| ラベル | SlackAPI |
| URL | `https://slack.com/api` |
| 認証プロトコル | Named Principal |
| 認証ヘッダー | `Authorization: Bearer xoxb-<BotToken>` |

---

## 3. Pay.jp

### 概要

Pay.jp は日本国内向けのクレジットカード決済サービスです。`PayjpCalloutService` が Basic 認証（Secret Key）を使用して API を呼び出します。

### 動作モード

| モード | エンドポイント | 使用キー |
|---|---|---|
| テストモード | `https://api.pay.jp/v1` | `sk_test_...` |
| 本番モード | `https://api.pay.jp/v1` | `sk_live_...` |

!!! warning "モード切り替え"
    `PortalConfiguration__c.PayjpMode__c` で `'test'` / `'live'` を切り替えます。本番環境では必ず `'live'` に設定してください。

### 決済フロー

```
フロントエンド（paymentForm LWC）
    │ Pay.jp JS SDK でカードをトークン化
    ▼
Apex: PayjpCalloutService.createChargeAsync(token, amount)
    │ @future(callout=true)
    ▼
Named Credential 'PayjpAPI' で POST /v1/charges
    │ Basic Auth: SecretKey:（パスワードなし）
    ▼
Pay.jp がカードに課金 → レスポンスを Payment__c に保存
```

### Named Credential 設定（PayjpAPI）

| 項目 | 値 |
|---|---|
| ラベル | PayjpAPI |
| URL | `https://api.pay.jp/v1` |
| 認証プロトコル | Named Principal |
| 認証 | Password Authentication（Username=SecretKey, Password=空） |

---

## 4. Omise

### 概要

Omise は東南アジア・日本向けの決済サービスです。`PaymentGatewayService.chargeOmise()` から呼び出されます。

```apex
// PaymentGatewayService 内
private static Map<String, Object> chargeOmise(
    Decimal amount, String currency, String token
) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:OmiseAPI/charges');
    req.setMethod('POST');
    // Basic Auth は Named Credential で自動付与
}
```

### Named Credential 設定（OmiseAPI）

| 項目 | 値 |
|---|---|
| ラベル | OmiseAPI |
| URL | `https://api.omise.co` |
| 認証プロトコル | Named Principal |
| 認証 | Password Authentication（Username=SecretKey, Password=空） |

---

## 5. Stripe

### 概要

Stripe はグローバル対応の決済サービスです。`PaymentGatewayService.chargeStripe()` から呼び出されます。

```apex
private static Map<String, Object> chargeStripe(
    Decimal amount, String currency, String token
) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:StripeAPI/v1/payment_intents');
    req.setMethod('POST');
    // Bearer Token は Named Credential で自動付与
}
```

### Named Credential 設定（StripeAPI）

| 項目 | 値 |
|---|---|
| ラベル | StripeAPI |
| URL | `https://api.stripe.com` |
| 認証プロトコル | Named Principal |
| 認証 | Bearer Token（Secret Key） |

---

## 6. Fincode

### 概要

Fincode は国内向けの決済サービスです。`PaymentGatewayService.chargeFincode()` から呼び出されます。

```apex
private static Map<String, Object> chargeFincode(
    Decimal amount, String token
) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:FincodeAPI/v1/payments');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    // API Key は Named Credential のカスタムヘッダーで自動付与
}
```

### Named Credential 設定（FincodeAPI）

| 項目 | 値 |
|---|---|
| ラベル | FincodeAPI |
| URL | `https://api.fincode.jp` |
| 認証プロトコル | Named Principal |
| カスタムヘッダー | `Authorization: Bearer <SecretKey>` |

---

## Named Credentials 設定手順

!!! tip "設定手順（全サービス共通）"
    1. **Setup** → **Named Credentials** を開く
    2. **New** をクリック
    3. 上記の各サービス設定値を入力
    4. **Save** をクリック
    5. Apex コードの `callout:<NamedCredentialName>` で使用可能になる

```
Setup → Named Credentials → New
    ├── Label: PayjpAPI
    ├── Name: PayjpAPI（API名 = Apex で使用する名前）
    ├── URL: https://api.pay.jp/v1
    ├── Identity Type: Named Principal
    └── Authentication Protocol: Password Authentication
            ├── Username: sk_live_xxxxxxxxxxxx（またはsk_test_...）
            └── Password:（空白のまま）
```

---

## Remote Site Settings

外部 API を呼び出すには、該当のエンドポイントを Remote Site Settings に登録する必要があります。

| サイト名 | エンドポイント URL | Active |
|---|---|---|
| `OktaAPI` | `https://<your-domain>.okta.com` | 有効 |
| `SlackAPI` | `https://slack.com` | 有効 |
| `PayjpAPI` | `https://api.pay.jp` | 有効 |
| `OmiseAPI` | `https://api.omise.co` | 有効 |
| `StripeAPI` | `https://api.stripe.com` | 有効 |
| `FincodeAPI` | `https://api.fincode.jp` | 有効 |

!!! warning "Remote Site Settings の設定漏れ"
    Named Credentials を設定しても Remote Site Settings が設定されていない場合、Apex コールアウトは `System.CalloutException: Unauthorized endpoint` で失敗します。Named Credentials の設定と合わせて必ず登録してください。

```
Setup → Remote Site Settings → New Remote Site
    ├── Remote Site Name: PayjpAPI
    ├── Remote Site URL: https://api.pay.jp
    └── Active: ✓
```

---

## 決済プロバイダーのルーティング

`PaymentGatewayService.processPayment()` は `PortalConfiguration__c` の設定に基づいて決済プロバイダーを自動選択します。

```apex
public static Map<String, Object> processPayment(
    String provider, Decimal amount,
    String currency, String token
) {
    switch on provider {
        when 'payjp'   { return chargePayjp(amount, currency, token); }
        when 'omise'   { return chargeOmise(amount, currency, token); }
        when 'stripe'  { return chargeStripe(amount, currency, token); }
        when 'fincode' { return chargeFincode(amount, token); }
        when else      { throw new IllegalArgumentException('Unknown provider: ' + provider); }
    }
}
```

!!! info "決済プロバイダーの切り替え"
    使用する決済プロバイダーは `portalConfigAdmin` LWC から変更できます。変更後は `paymentForm` LWC が新しいプロバイダーの JS SDK を動的にロードします。
