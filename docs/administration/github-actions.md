# GitHub Actions CI/CD セットアップ

## ワークフロー一覧

| ワークフロー | トリガー | 目的 |
|---|---|---|
| `pr-validate.yml` | PR オープン・更新 | メタデータ検証 + Apex テスト + 静的チェック |
| `deploy-sandbox.yml` | main へのプッシュ | サンドボックスへの自動デプロイ |
| `deploy-production.yml` | 手動 (workflow_dispatch) | 本番デプロイ（ドライラン対応） |
| `docs.yml` | docs/ 変更 / main プッシュ | MkDocs ビルド検証 + GitHub Pages デプロイ |

---

## 事前準備: Salesforce 接続アプリケーション (JWT 認証)

GitHub Actions は **JWT Bearer フロー** を使って Salesforce 組織に対して無人認証します。  
ブラウザ操作なしでデプロイできます。

### 1. 秘密鍵ペアの生成

```bash
# 秘密鍵と自己署名証明書を生成
openssl genrsa -out server.key 2048
openssl req -new -x509 -key server.key -out server.crt -days 3650 \
  -subj "/C=JP/ST=Tokyo/O=Willen/CN=MemberPortal-CI"
```

### 2. Salesforce で接続アプリケーションを作成

1. `設定 → アプリケーションマネージャ → 新規接続アプリケーション`
2. **OAuth 設定を有効化** にチェック
3. **デジタル署名を使用** にチェックし、`server.crt` をアップロード
4. **選択した OAuth 範囲** に以下を追加:
   - `api` — API へのアクセス
   - `web` — Web ブラウザを使用した Salesforce へのアクセス
   - `refresh_token, offline_access`
5. 保存後、**コンシューマ鍵** をコピーしておく

### 3. 接続アプリケーションのポリシー設定

`管理 → 接続アプリケーション → [作成したアプリ] → ポリシーを編集`:

- **OAuth ポリシー**: 許可されているユーザー → **管理者が承認したユーザーは事前承認済み**
- 承認済みプロファイルまたは権限セットにデプロイユーザーを追加

---

## GitHub Secrets の設定

`リポジトリ → Settings → Secrets and variables → Actions → New repository secret`

### サンドボックス用

| Secret 名 | 値 |
|---|---|
| `SF_JWT_PRIVATE_KEY` | `server.key` の内容（`-----BEGIN RSA PRIVATE KEY-----` 含む全文） |
| `SF_CONSUMER_KEY_SANDBOX` | 接続アプリケーションのコンシューマ鍵 |
| `SF_USERNAME_SANDBOX` | サンドボックスのデプロイユーザー名（例: `deploy@willen.jp.uat`） |

### 本番用（追加で設定）

| Secret 名 | 値 |
|---|---|
| `SF_JWT_PRIVATE_KEY_PROD` | 本番用秘密鍵（別キーペアを推奨） |
| `SF_CONSUMER_KEY_PROD` | 本番接続アプリケーションのコンシューマ鍵 |
| `SF_USERNAME_PROD` | 本番デプロイユーザー名（例: `deploy@willen.jp`） |

!!! warning "秘密鍵の取り扱い"
    `server.key` は **絶対に git にコミットしないこと**。  
    `.gitignore` に `*.key` を追加してください。  
    GitHub Secrets に貼り付け後、ローカルファイルは削除してください。

!!! tip "サンドボックスと本番で別キーを使う理由"
    接続アプリケーションを環境ごとに分けると、本番キーが漏洩してもサンドボックスへの影響にとどめられます。

---

## GitHub Environments の設定（推奨）

本番デプロイには **承認者** を設定することを強く推奨します。

1. `リポジトリ → Settings → Environments → New environment`
2. 名前: `production`
3. **Required reviewers** に承認者（管理者）を追加
4. **Wait timer**: 必要であれば待機時間を設定

これにより `deploy-production.yml` の実行時に承認者の確認が必要になります。

同様に `sandbox` environment も作成し、サンドボックス用 Secrets をそこに移動することを推奨。

---

## GitHub Pages の設定（docs.yml 用）

1. `リポジトリ → Settings → Pages`
2. **Source**: `Deploy from a branch`
3. **Branch**: `gh-pages` / `/ (root)`
4. 保存

`docs.yml` が main にマージされるたびに `gh-pages` ブランチが更新され、  
`https://Willen-Federation.github.io/Salesforce-Integration/` でドキュメントが公開されます。

---

## ワークフロー動作確認

### PR バリデーションのテスト

```bash
# テスト用ブランチを作成して PR を出す
git checkout -b test/ci-check
echo "# test" >> docs/index.md
git add . && git commit -m "test: CI check"
git push origin test/ci-check
gh pr create --title "test: CI check" --body "CI テスト用"
```

### 手動デプロイの実行

```bash
# GitHub CLI でワークフローを手動実行
gh workflow run deploy-sandbox.yml \
  --repo Willen-Federation/Salesforce-Integration \
  --field test_level=RunLocalTests

# 本番デプロイ（ドライラン）
gh workflow run deploy-production.yml \
  --repo Willen-Federation/Salesforce-Integration \
  --field confirm=deploy \
  --field test_level=RunLocalTests \
  --field dry_run=true
```

### ジョブ状態の確認

```bash
# 最近のワークフロー実行一覧
gh run list --repo Willen-Federation/Salesforce-Integration

# 特定の実行の詳細
gh run view <run-id> --repo Willen-Federation/Salesforce-Integration
```

---

## Secrets が未設定の場合の挙動

`pr-validate.yml` の Salesforce 検証ジョブは、リポジトリ変数 `SKIP_SF_VALIDATION` を `true` に設定することでスキップできます。  
`Settings → Variables → Actions → New repository variable`

これにより、Secrets 未設定の段階でも docs ビルドと静的チェックだけ先に動かせます。
