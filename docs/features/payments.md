# 決済機能

会員ポータルにおける年会費・賛助金の決済処理に関する仕様をまとめます。

---

## 対応決済プロバイダー

| プロバイダー | API名 | 対応カードブランド | 備考 |
|------------|-------|-----------------|------|
| Pay.jp | `payjp` | Visa, Mastercard | プライマリプロバイダー |
| Omise | `omise` | Visa, Mastercard, JCB | |
| Stripe | `stripe` | Visa, Mastercard, AMEX, JCB | |
| Fincode | `fincode` | Visa, Mastercard, JCB | |
| 口座振替 | `direct_debit` | — | フォームPDF ダウンロード方式 |

!!! info "プライマリプロバイダー"
    Pay.jp が主要プロバイダーとして設定されています。新規環境セットアップ時は Pay.jp の Named Credential を最初に設定してください。

---

## プロバイダーの選択・切り替え

決済プロバイダーの選択は管理者画面（**`portalConfigAdmin` LWC**）の `PortalConfiguration__c` レコード設定で行います。

| 設定項目（`PortalConfiguration__c`） | 型 | 説明 |
|------------------------------------|----|------|
| `ActivePaymentProvider__c` | Picklist | 有効化するプロバイダー |
| `PayjpMode__c` | Picklist | `テスト` / `本番` |
| `DirectDebitFormUrl__c` | URL | 口座振替申込書のダウンロードURL |
| `AnnualFeeSupporting__c` | Currency | 賛助会員の年会費 |

!!! tip "プロバイダー切り替え手順"
    1. `portalConfigAdmin` LWC を開く（管理者タブ → ポータル設定）
    2. `ActivePaymentProvider__c` で新しいプロバイダーを選択
    3. Named Credential に対応する認証情報が設定されていることを確認
    4. `PayjpMode__c` を `テスト` に設定してサンドボックスで動作確認
    5. 問題がなければ `本番` に切り替え

---

## 決済フロー

```
[会員]
    │
    ▼
paymentForm LWC（Experience Cloud）
    │  ① カード情報入力（Pay.jp JS SDK でトークン化）
    │  ② トークン + 金額を Apex へ送信
    ▼
PaymentGatewayService.processPayment()
    │  ③ ActivePaymentProvider__c に応じてサービス分岐
    ├─── [Pay.jp]  → PayjpCalloutService.createCharge()
    ├─── [Omise]   → OmiseCalloutService.createCharge()
    ├─── [Stripe]  → StripeCalloutService.createCharge()
    └─── [Fincode] → FincodeCalloutService.createCharge()
           │
           ▼  Named Credential 経由で外部API呼び出し
    ④ 決済結果を受け取り Payment__c レコードを作成/更新
    ▼
確認メール送信
```

!!! warning "APIシークレットキーの管理"
    **APIシークレットキーを git にコミットしてはいけません。** すべての認証情報は Salesforce の **Named Credential** に保存し、コードからは Named Credential 名のみで参照してください。

    ```apex
    // 良い例: Named Credential 経由
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:PayJP/v1/charges');

    // 悪い例: ハードコード（絶対禁止）
    // req.setHeader('Authorization', 'Bearer sk_live_XXXX');
    ```

---

## Pay.jp 固有の処理

### パブリックキーの取得

フロントエンド（`paymentForm` LWC）が Pay.jp JS SDK を初期化する際、Apex からパブリックキーを取得します。

```apex
@AuraEnabled(cacheable=true)
public static String getPayjpPublicKey() {
    PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();
    return config.PayjpPublicKey__c;
}
```

### 課金処理（`PayjpCalloutService.createCharge()`）

```apex
public static Map<String, Object> createCharge(
    String token,
    Integer amountYen,
    String description
) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:PayJP/v1/charges');
    req.setMethod('POST');
    req.setBody(
        'token=' + EncodingUtil.urlEncode(token, 'UTF-8') +
        '&amount=' + amountYen +
        '&currency=jpy' +
        '&description=' + EncodingUtil.urlEncode(description, 'UTF-8')
    );
    Http http = new Http();
    HttpResponse res = http.send(req);
    return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
}
```

### テストモード vs. 本番モード

| `PayjpMode__c` | Named Credential | 挙動 |
|----------------|-----------------|------|
| `テスト` | `PayJP_Test` | テスト課金（実際の請求なし） |
| `本番` | `PayJP` | 実課金 |

!!! warning "本番モードへの切り替え"
    `PayjpMode__c` を `本番` に設定すると**実際の課金**が発生します。切り替え前に必ずテストモードで全フローを確認してください。本番環境への適用はリリース直前のみ行ってください。

---

## 口座振替（直接引き落とし）

口座振替を選択した会員には、申込書 PDF のダウンロードリンクが表示されます。

```
会員が「口座振替」を選択
    │
    ▼
paymentForm LWC が DirectDebitFormUrl__c を表示
    │  「申込書をダウンロード」ボタン
    ▼
会員が申込書を印刷・記入・郵送
    │
    ▼
管理者が Payment__c.DirectDebitApplicationSent__c = true に更新
```

!!! note "口座振替レコードの扱い"
    口座振替の場合、`Payment__c` レコードの `PaymentMethod__c = '口座振替'` かつ `PaymentStatus__c = '申込書送付待ち'` で作成されます。管理者が `DirectDebitApplicationSent__c = true` に設定すると `PaymentStatus__c` が `処理中` に遷移します。

---

## Payment__c オブジェクト

### 主要項目一覧

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `PaymentMethod__c` | Picklist | クレジットカード / 口座振替 |
| `PaymentProvider__c` | Picklist | payjp / omise / stripe / fincode / direct_debit |
| `CardBrand__c` | Text | Visa / Mastercard / JCB など（カード決済時） |
| `Amount__c` | Currency | 決済金額（円） |
| `PaymentStatus__c` | Picklist | 未払い / 処理中 / 完了 / 失敗 / 申込書送付待ち |
| `DirectDebitApplicationSent__c` | Checkbox | 口座振替申込書の送付済みフラグ |
| `Member__c` | MasterDetail | 関連会員 |
| `PaymentDate__c` | Date | 決済日 |
| `TransactionId__c` | Text | 外部プロバイダーのトランザクションID |

### PaymentStatus__c の遷移

```
未払い
  │
  ├─── カード決済成功 ──────────────────▶ 完了
  │
  ├─── カード決済失敗 ──────────────────▶ 失敗
  │
  └─── 口座振替選択 ────▶ 申込書送付待ち ──▶ 処理中 ──▶ 完了
```

---

## 賛助会員の年会費

賛助会員（`MemberType__c = '賛助会員'`）の年会費は `PortalConfiguration__c.AnnualFeeSupporting__c` で一元管理されます。

```apex
// 賛助会員の年会費を取得する例
PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();
Decimal annualFee = config.AnnualFeeSupporting__c;
```

!!! tip "年会費の変更"
    `portalConfigAdmin` LWC の「基本設定」タブで `AnnualFeeSupporting__c` を変更できます。変更はその時点以降の新規決済に適用されます。既存の `Payment__c` レコードには影響しません。
