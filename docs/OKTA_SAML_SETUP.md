# Okta SAML + 自動プロビジョニング 設定手順

## 1. Salesforce側 — SAML SSO設定

### 1-1. シングルサインオン設定の作成
1. **設定** → **ID** → **シングルサインオン設定** → **新規**
2. 以下を設定:
   | 項目 | 値 |
   |---|---|
   | 名前 | Okta SAML SSO |
   | API 参照名 | OktaSAMLSSO |
   | 発行者 | `https://your-domain.okta.com` |
   | エンティティID | `https://your-domain.my.salesforce.com` |
   | IdP 証明書 | Okta管理画面からダウンロードした証明書 |
   | ユーザーIDの種類 | フェデレーションID |
   | ユーザーIDの場所 | アサーションのサブジェクトのNameID要素 |

### 1-2. JIT（ジャストインタイム）プロビジョニング設定
1. 上記SAML設定の **「ジャストインタイム(JIT)ユーザープロビジョニング」** を有効化
2. **JIT ハンドラクラス**: `OktaIntegrationService`（本プロジェクトのApexクラス）
3. **SAML属性マッピング**:
   | SAML属性 | Salesforceフィールド |
   |---|---|
   | `email` | Email |
   | `given_name` | FirstName |
   | `family_name` | LastName |
   | `department` | Member__c.Department__c |
   | `orgUnit` | Member__c.OrgUnit__c |

---

## 2. Okta側 — Salesforceアプリ設定

### 2-1. Salesforceアプリの追加
1. Okta管理画面 → **Applications** → **Browse App Catalog**
2. 「Salesforce.com」を検索して追加

### 2-2. SAML設定
| 項目 | 値 |
|---|---|
| Single sign-on URL | `https://your-domain.my.salesforce.com/` |
| Audience URI (SP Entity ID) | `https://your-domain.my.salesforce.com` |
| Name ID format | EmailAddress |
| Application username | Email |

### 2-3. 属性ステートメント（SAML Attributes）
| 名前 | 値 |
|---|---|
| `email` | `user.email` |
| `given_name` | `user.firstName` |
| `family_name` | `user.lastName` |
| `department` | `user.department` |
| `orgUnit` | `user.customAttribute_orgUnit` |

### 2-4. SCIMプロビジョニング設定
1. **Provisioning** タブ → **Configure API Integration** を有効化
2. **SCIM Base URL**: `https://your-domain.my.salesforce.com/services/scim/v2`
3. **OAuth Bearer Token**: Salesforce Connected App のアクセストークン
4. 以下を有効化:
   - Push New Users ✅
   - Push Profile Updates ✅
   - Deactivate Users ✅（退会処理との連動）

---

## 3. Named Credential の更新

デプロイ後、以下を手動で更新してください。

### OktaAPI
- **設定** → **セキュリティ** → **Named Credential** → `OktaAPI`
- エンドポイント: `https://your-domain.okta.com`
- 認証ヘッダー: `Authorization: SSWS {APIトークン}`

### SlackAPI
- エンドポイント: `https://slack.com/api`
- 認証ヘッダー: `Authorization: Bearer {Botトークン（xoxb-...）}`

---

## 4. カスタム設定（PortalConfiguration__c）の初期値

**設定** → **カスタム設定** → **ポータル設定** → **管理** → **新規**

| フィールド | 設定値 |
|---|---|
| 組織名 | 貴団体名 |
| 送信元メールアドレス | noreply@your-domain.jp |
| サポートSlackチャンネルID | C0XXXXXXXXX（Slack管理画面で確認） |
| OktaドメインURL | https://your-domain.okta.com |
| ポータルベースURL | https://your-domain.my.site.com/member-portal |
| 個人会員年会費 | 10000 |
| 法人会員年会費 | 50000 |
| 学生会員年会費 | 3000 |
| 寄付機能を有効化 | ✅ |
| Slack通知を有効化 | ✅ |
