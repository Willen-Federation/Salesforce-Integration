# デプロイ・セットアップ手順

## 前提条件
- Salesforce CLI (`sf`) インストール済み
- Experience Cloud ライセンス有効
- Okta 組織管理者権限
- Slack ワークスペース管理者権限

---

## 1. SFDX プロジェクトのデプロイ

```bash
# 1. Salesforce組織へ認証
sf org login web --alias member-portal-org

# 2. メタデータを組織へデプロイ
sf project deploy start --source-dir force-app --target-org member-portal-org

# 3. デプロイ結果の確認
sf project deploy report
```

---

## 2. デプロイ後の手動設定

### 2-1. ポータル設定（カスタム設定）
`設定 → カスタム設定 → ポータル設定 → 管理 → 新規` で初期値を入力。
詳細は `docs/OKTA_SAML_SETUP.md` を参照。

### 2-2. Named Credential のエンドポイント・認証情報を更新
- **OktaAPI**: ドメインURL と SSWS APIトークンを設定
- **SlackAPI**: Bot Token（`xoxb-...`）を Authorizationヘッダーに設定

### 2-3. Okta SAML SSO 設定
`設定 → ID → シングルサインオン設定 → 新規` で Okta をIdPとして登録。
詳細は `docs/OKTA_SAML_SETUP.md` を参照。

### 2-4. Experience Cloud サイトの有効化
1. `設定 → デジタルエクスペリエンス → すべてのサイト`
2. **会員ポータル** → **公開** をクリック
3. サイトビルダーでLWCコンポーネントをページに配置

### 2-5. ページレイアウト（サイトビルダーでの配置）
| ページ | 配置コンポーネント |
|---|---|
| ホーム | `memberPortalDashboard` |
| 会員登録 | `memberRegistrationForm` |
| 支払い | `paymentForm` |
| 寄付 | `donationForm` |
| 組織図 | `orgChartViewer` |
| 活動登録 | `activityRegistration` |
| 変更申請 | `changeRequestForm` |
| お問い合わせ | `supportInquiryForm` |

### 2-6. 権限セットの割り当て
```bash
# 管理者へ割り当て
sf org assign permset --name MemberPortalAdmin --target-org member-portal-org

# 会員ユーザーへ割り当て（Experienceユーザー）
sf org assign permset --name MemberPortalUser --target-org member-portal-org
```

### 2-7. バッチ通知スケジューラーの有効化
`設定 → Apex スケジュール` で `BatchNotificationBatch` を毎時実行に設定。

---

## 3. 承認プロセスの設定

`設定 → プロセスの自動化 → 承認プロセス → 変更申請__c → 新規` で
変更申請の承認プロセスを作成してください。

推奨設定:
- 承認者: 管理者ロールのユーザー
- 通知メール: Salesforce 標準のメールテンプレートを使用

---

## 4. 動作確認チェックリスト

- [ ] 会員登録申請 → 確認メール受信
- [ ] 管理者承認 → 承認通知メール受信
- [ ] 支払い → 領収書PDF発行（`/apex/PortalReceiptPage?id=xxxxx`）
- [ ] 寄付 → 寄付領収書PDF発行（`/apex/DonationReceiptPage?id=xxxxx&type=donation`）
- [ ] 人事異動承認 → Slackチャンネルへ通知
- [ ] お問い合わせ送信 → 自動返信メール + Slack通知
- [ ] Okta SSO でポータルへログイン
- [ ] バッチ通知 → メール + Slack DMへ送信
