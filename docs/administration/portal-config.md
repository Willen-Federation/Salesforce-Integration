# ポータル設定管理（portalConfigAdmin）

`portalConfigAdmin` LWC は、会員ポータルの動作に関わる全設定を一元管理する管理者向け画面です。

---

## アクセス方法

| 項目 | 内容 |
|---|---|
| **コンポーネント名** | `portalConfigAdmin` |
| **ターゲット** | AppPage / Tab |
| **必要な権限セット** | `MemberPortalAdmin` |
| **場所** | Salesforce 内部アプリ → 「ポータル設定」タブ |

!!! warning "管理者専用"
    このタブは `MemberPortalAdmin` 権限セットを持つユーザーのみが表示・編集できます。Experience Cloud には公開しないでください。

---

## 設定セクション

### 基本設定

ポータル全体の基本情報を設定します。

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `SiteName__c` | サイト名 | ポータルのタイトル（ヘッダーに表示） |
| `AnnualFee__c` | 正会員 年会費（円） | 正会員の年間会費金額 |
| `AnnualFeeSupporting__c` | 賛助会員 年会費（円） | 賛助会員の年間会費金額 |

---

### Okta 設定

Okta SAML / API 連携に必要な設定です。

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `OktaClientId__c` | クライアント ID | Okta アプリケーションのクライアント ID |
| `OktaClientSecret__c` | クライアントシークレット | パスワード入力（マスク表示） |
| `OktaDomain__c` | Okta ドメイン | 例: `willen.okta.com` |

---

### 決済設定（Pay.jp）

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `PayjpMode__c` | 動作モード | `test` / `live` |
| `PayjpPublicKey__c` | パブリックキー | JS SDK でカードトークン化に使用（`pk_test_...` / `pk_live_...`） |
| `PayjpSecretKey__c` | シークレットキー | パスワード入力（マスク表示）（`sk_test_...` / `sk_live_...`） |

!!! warning "テストモードと本番モード"
    `PayjpMode__c = 'test'` の場合、テスト用カード番号（`4242 4242 4242 4242` 等）のみ受け付けます。本番リリース前に必ず `'live'` に切り替えてください。

---

### 決済設定（Omise）

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `OmiseMode__c` | 動作モード | `test` / `live` |
| `OmisePublicKey__c` | パブリックキー | JS SDK 用（`pkey_test_...` / `pkey_...`） |
| `OmiseSecretKey__c` | シークレットキー | パスワード入力（マスク表示） |

---

### 決済設定（Stripe）

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `StripeMode__c` | 動作モード | `test` / `live` |
| `StripePublicKey__c` | パブリッシャブルキー | JS SDK 用（`pk_test_...` / `pk_live_...`） |
| `StripeSecretKey__c` | シークレットキー | パスワード入力（マスク表示） |

---

### 決済設定（Fincode）

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `FincodeMode__c` | 動作モード | `test` / `live` |
| `FincodeShopId__c` | ショップ ID | Fincode ダッシュボードで確認 |
| `FincodePublicKey__c` | パブリックキー | JS SDK 用 |
| `FincodeSecretKey__c` | シークレットキー | パスワード入力（マスク表示） |

---

### 口座振替設定

| フィールド API名 | 設定項目 | 説明 |
|---|---|---|
| `DirectDebitFormUrl__c` | 口座振替申込書 URL | 外部の申込書 PDF または Web フォームの URL |

会員が「口座振替」を選択した場合、このURLへリダイレクトされます。

---

## 全フィールド一覧

| フィールド API名 | 型 | 説明 |
|---|---|---|
| `AnnualFee__c` | Currency | 正会員年会費 |
| `AnnualFeeSupporting__c` | Currency | 賛助会員年会費 |
| `PayjpPublicKey__c` | Text | Pay.jp パブリックキー |
| `PayjpSecretKey__c` | Text (Encrypted) | Pay.jp シークレットキー |
| `PayjpMode__c` | Text | Pay.jp モード（test/live） |
| `DirectDebitFormUrl__c` | URL | 口座振替申込書URL |
| `OmisePublicKey__c` | Text | Omise パブリックキー |
| `OmiseSecretKey__c` | Text (Encrypted) | Omise シークレットキー |
| `OmiseMode__c` | Text | Omise モード（test/live） |
| `StripePublicKey__c` | Text | Stripe パブリッシャブルキー |
| `StripeSecretKey__c` | Text (Encrypted) | Stripe シークレットキー |
| `StripeMode__c` | Text | Stripe モード（test/live） |
| `FincodeShopId__c` | Text | Fincode ショップID |
| `FincodePublicKey__c` | Text | Fincode パブリックキー |
| `FincodeSecretKey__c` | Text (Encrypted) | Fincode シークレットキー |
| `FincodeMode__c` | Text | Fincode モード（test/live） |
| `OktaClientId__c` | Text | Okta クライアントID |
| `OktaClientSecret__c` | Text (Encrypted) | Okta クライアントシークレット |
| `OktaDomain__c` | Text | Okta ドメイン |

---

## savePortalConfig() の動作

```apex
@AuraEnabled
public static PortalConfiguration__c savePortalConfig(
    Map<String, Object> configData
) {
    // SetupOwnerId（組織ID）をキーにして Upsert
    // → 常に1レコードのみ存在する「シングルトン」パターン
    PortalConfiguration__c config = new PortalConfiguration__c(
        SetupOwnerId = UserInfo.getOrganizationId()
    );

    // configData の各フィールドを動的に設定
    // ...

    upsert config SetupOwnerId;
    return config;
}
```

!!! info "シングルトン設計"
    `PortalConfiguration__c` は組織に1レコードだけ存在します。`SetupOwnerId`（= 組織ID）を外部キーとした upsert により、保存するたびに同じレコードが更新されます。

---

## 設定画面のレイアウト

```
┌─────────────────────────────────────────────┐
│ ポータル設定                                 │
├─────────────────────────────────────────────┤
│ ▼ 基本設定                                   │
│   サイト名: [Willen 会員ポータル            ]│
│   正会員 年会費: [¥12,000                  ]│
│   賛助会員 年会費: [¥6,000                 ]│
├─────────────────────────────────────────────┤
│ ▼ Okta 設定                                  │
│   クライアントID: [0oa...                   ]│
│   クライアントシークレット: [••••••••••••••]│
│   Oktaドメイン: [willen.okta.com           ]│
├─────────────────────────────────────────────┤
│ ▼ Pay.jp 設定                                │
│   モード: [● テスト  ○ 本番]                │
│   パブリックキー: [pk_test_...             ]│
│   シークレットキー: [••••••••••••••••••••••]│
├─────────────────────────────────────────────┤
│ ▼ Omise / Stripe / Fincode 設定（折りたたみ）│
├─────────────────────────────────────────────┤
│ ▼ 口座振替設定                               │
│   申込書URL: [https://...                  ]│
├─────────────────────────────────────────────┤
│                         [キャンセル] [保存]  │
└─────────────────────────────────────────────┘
```

---

## セキュリティに関する注意事項

!!! danger "シークレットキーの保存について"
    シークレットキー（`*SecretKey__c` フィールド）は Salesforce のカスタムフィールドに保存されます。Salesforce はデータを保存時に暗号化しますが、Salesforce Platform Encryption（Shield）を有効化していない場合、Salesforce サポートによる復号は理論上可能です。

    **最高セキュリティが必要な場合は Named Credentials を使用してください。**

    | アプローチ | セキュリティレベル | 運用性 |
    |---|---|---|
    | `PortalConfiguration__c` に保存（現状） | 中（Salesforce 標準暗号化） | 高（UI から変更可） |
    | Named Credentials に保存 | 高（Salesforce 管理暗号化） | 低（Setup から変更） |
    | Platform Encryption（Shield）+ カスタムフィールド | 最高 | 高 |

!!! tip "シークレットキーの運用ルール"
    - 本番用シークレットキーは MemberPortalAdmin ユーザーのみが参照・変更できる
    - テスト用と本番用のキーを混在させない
    - 定期的にキーをローテーションし、古いキーは即時無効化する
    - キーのローテーション後は `savePortalConfig()` で新しいキーを保存する

---

## 設定変更後の確認手順

```
1. PortalConfiguration__c の保存を確認
   → Developer Console > Query Editor
   SELECT PayjpMode__c, PayjpPublicKey__c FROM PortalConfiguration__c LIMIT 1

2. paymentForm LWC をリロードしてパブリックキーが更新されているか確認

3. テスト決済を実行してトランザクションが正常に完了するか確認

4. 本番モードへの切り替えは営業時間中に実施する
```
