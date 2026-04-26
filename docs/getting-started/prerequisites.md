# 前提条件

会員ポータルをデプロイ・運用するために必要な環境・アカウント・ツールの一覧です。作業を開始する前に、すべての項目を満たしていることを確認してください。

---

## Salesforce 組織要件

| 要件 | 詳細 |
|---|---|
| **エディション** | Enterprise Edition 以上（Unlimited / Developer も可） |
| **アドオン** | Experience Cloud ライセンス（必須） |
| **API アクセス** | 組織設定で API アクセスが有効になっていること |
| **Salesforce API バージョン** | v59.0 以上 |
| **My Domain** | 設定済みであること（Experience Cloud 必須） |

!!! warning "Enterprise Edition 未満の場合"
    Professional Edition では Apex の外部からの呼び出しや一部の共有ルール設定に制限があります。必ず Enterprise Edition 以上の組織を使用してください。

!!! note "Developer Edition について"
    機能検証目的であれば Developer Edition でも動作しますが、Experience Cloud のライセンス制限によりユーザー数が限られます。本番運用には使用しないでください。

### Experience Cloud の確認方法

Salesforce Setup にログインし、**[Experience Cloud サイト]** メニューが表示されることを確認してください。表示されない場合は Salesforce サポートに Experience Cloud ライセンスの追加を依頼してください。

---

## 必須 CLI ツール

### Salesforce CLI (`sf`) v2+

```bash
# インストール確認
sf --version
# 期待する出力例: @salesforce/cli/2.x.x ...

# インストール方法（macOS Homebrew）
brew install sf

# インストール方法（npm）
npm install -g @salesforce/cli
```

!!! tip "旧バージョン (`sfdx`) からの移行"
    旧来の `sfdx` コマンドは `sf` コマンドに統合されました。`sfdx` が引き続き動作する場合でも、本プロジェクトのすべてのコマンドは `sf` (v2系) を前提として記述しています。

### Git

```bash
# バージョン確認
git --version
# 期待する出力例: git version 2.x.x
```

Git 2.30 以上を推奨します。macOS の場合は `brew install git` でインストールできます。

---

## 外部サービスアカウント

以下の外部サービスのアカウント・権限が必要です。本番デプロイ前にすべてのサービスでアカウントが有効であることを確認してください。

| サービス | 必要な権限・情報 |
|---|---|
| **Okta** | SAML IdP 管理者権限、アプリケーション作成権限、JIT プロビジョニング設定権限 |
| **Slack** | ワークスペース管理者権限、Bot Token (`xoxb-...`)、Incoming Webhook URL |
| **Pay.jp** | API キー（公開鍵・秘密鍵）— 決済プロバイダーとして Pay.jp を使用する場合 |
| **Omise** | 公開鍵・秘密鍵 — Omise を使用する場合 |
| **Stripe** | シークレットキー (`sk_...`) — Stripe を使用する場合 |
| **Fincode** | API キー — Fincode を使用する場合 |

!!! note "決済プロバイダーの選択"
    Pay.jp / Omise / Stripe / Fincode のいずれか **1つ以上** が必要です。複数を同時に有効化することも可能ですが、通常は1組織につき1プロバイダーを使用します。どのプロバイダーを使用するかは `PortalConfiguration__c` カスタム設定で切り替えます。

!!! warning "テスト環境での API キー"
    各決済プロバイダーにはテスト用 API キーと本番用 API キーが存在します。サンドボックスデプロイ時は必ずテスト用 API キーを使用し、本番用キーをサンドボックスに設定しないでください。

---

## Salesforce 組織内の権限

| 権限 | 詳細 |
|---|---|
| **プロファイル** | デプロイ作業者は対象組織でシステム管理者プロファイルを持つこと |
| **API 有効化** | システム管理者プロファイルで「API の有効化」が ON になっていること |
| **Apex 実行** | 匿名 Apex を実行できる権限（システム管理者には付与済み） |

---

## Node.js について

!!! info "Node.js は不要"
    本プロジェクトは純粋な SFDX メタデータプロジェクトです。LWC のビルドに Node.js は不要で、Salesforce CLI が直接デプロイを処理します。フロントエンドのビルドステップは存在しません。

---

## バージョン対応表

| コンポーネント | 最低バージョン | 推奨バージョン | 備考 |
|---|---|---|---|
| Salesforce API | 59.0 | 59.0 | `sfdx-project.json` で指定済み |
| Salesforce CLI (`sf`) | 2.0.0 | 最新安定版 | `sf --version` で確認 |
| Git | 2.30.0 | 最新安定版 | — |
| MkDocs Material | 9.5.0 | 最新安定版 | ドキュメントビルド用 |
| Python | 3.9 | 3.11+ | MkDocs 実行用（ドキュメントのみ） |

---

## ネットワーク要件

デプロイ環境から以下のエンドポイントへの HTTPS アクセスが必要です。

| エンドポイント | 用途 |
|---|---|
| `*.salesforce.com` | Salesforce 組織への接続 |
| `*.force.com` | Experience Cloud サイト |
| `api.pay.jp` | Pay.jp 決済 API |
| `api.omise.co` | Omise 決済 API |
| `api.stripe.com` | Stripe 決済 API |
| `api.fincode.jp` | Fincode 決済 API |
| `slack.com` | Slack API |
| `*.okta.com` | Okta SAML / API |

!!! tip "プロキシ環境の場合"
    社内プロキシを経由する環境では、Salesforce CLI の HTTP_PROXY / HTTPS_PROXY 環境変数を設定してください。詳細は Salesforce CLI 公式ドキュメントを参照してください。

---

## 次のステップ

前提条件がすべて満たされたら、[インストール](installation.md) に進んでください。
