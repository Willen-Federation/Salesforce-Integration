# インストール・デプロイ手順

このガイドでは、リポジトリのクローンから Salesforce 組織へのデプロイ完了までのステップを説明します。

!!! warning "重要: サンドボックスで先にテストしてください"
    **本番組織へのデプロイを行う前に、必ずサンドボックス環境でデプロイおよびすべての動作確認を実施してください。** メタデータのデプロイは組織の設定を変更するため、本番組織への影響を最小化するために事前検証が不可欠です。

---

## 前提条件の確認

デプロイ前に [前提条件](prerequisites.md) ページのすべての項目を満たしていることを確認してください。

```bash
# Salesforce CLI バージョン確認
sf --version

# Git バージョン確認
git --version
```

---

## ステップ 1: リポジトリのクローン

```bash
git clone https://github.com/your-org/salesforce-integration.git
cd salesforce-integration
```

!!! note "ブランチについて"
    本番デプロイには `main` ブランチを使用してください。機能開発は `feature/*` ブランチで行い、Pull Request を経由して `main` にマージします。

---

## ステップ 2: Salesforce 組織への認証

```bash
sf org login web --alias member-portal-org
```

ブラウザが開き、Salesforce ログイン画面が表示されます。デプロイ対象の組織にシステム管理者でログインしてください。

```bash
# 認証済み組織の一覧確認
sf org list

# 対象組織の詳細確認
sf org display --target-org member-portal-org
```

!!! tip "サンドボックスへの認証"
    サンドボックス組織に認証する場合は、`--instance-url` オプションを追加してください。
    ```bash
    sf org login web --alias member-portal-sandbox \
      --instance-url https://test.salesforce.com
    ```

---

## ステップ 3: メタデータのデプロイ

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org member-portal-org
```

デプロイには組織の状態によって 3〜15 分程度かかります。デプロイ中は進行状況がコンソールに出力されます。

### デプロイオプション

| オプション | 説明 |
|---|---|
| `--dry-run` | 実際のデプロイを行わずに検証のみ実行 |
| `--test-level RunLocalTests` | デプロイ時にローカルテストを実行 |
| `--ignore-conflicts` | コンフリクトを無視してデプロイ（注意して使用） |

```bash
# 検証のみ（推奨: 本番デプロイ前に実行）
sf project deploy validate \
  --source-dir force-app \
  --target-org member-portal-org \
  --test-level RunLocalTests
```

---

## ステップ 4: デプロイ結果の確認

```bash
sf project deploy report
```

すべてのコンポーネントが `Succeeded` になっていることを確認してください。

```bash
# 直近のデプロイ一覧を確認
sf project deploy report --use-most-recent
```

!!! warning "デプロイ失敗時"
    エラーが発生した場合は出力されたエラーメッセージを確認し、原因を修正してから再デプロイしてください。よくある原因:
    
    - Apex コンパイルエラー（依存するカスタムオブジェクト・フィールドが未作成）
    - 権限不足（システム管理者プロファイルでないユーザーでデプロイしようとしている）
    - API バージョンの不一致

---

## ステップ 5: Apex テストの実行

```bash
sf apex run test \
  --target-org member-portal-org \
  --wait 10
```

すべてのテストクラスが合格することを確認してください。コードカバレッジは 75% 以上が必要です（Salesforce 要件）。

```bash
# 特定のテストクラスのみ実行
sf apex run test \
  --target-org member-portal-org \
  --class-names MemberControllerTest,PaymentServiceTest \
  --wait 10

# テスト結果をファイルに出力
sf apex run test \
  --target-org member-portal-org \
  --result-format json \
  --output-dir ./test-results \
  --wait 10
```

!!! note "テスト実行時間"
    全テストの実行には 5〜10 分程度かかります。`--wait` オプションで待機時間（分）を指定してください。時間内に完了しない場合はジョブ ID が返されるので、`sf apex get test --test-run-id <ID>` で結果を確認できます。

---

## ステップ 6: スケジュールバッチの登録

人事変更予約を自動適用する `PersonnelChangePublisherBatch` を1時間ごとのスケジュールで登録します。Salesforce Setup の **開発者コンソール** または **匿名 Apex 実行** から以下を実行してください。

```apex
// 匿名 Apex: 1時間ごとのスケジュール登録
PersonnelChangePublisherBatch.scheduleHourly();
```

```bash
# Salesforce CLI から匿名 Apex を実行する場合
sf apex run \
  --target-org member-portal-org \
  --file scripts/apex/schedule-batch.apex
```

`scripts/apex/schedule-batch.apex` の内容:

```apex
PersonnelChangePublisherBatch.scheduleHourly();
System.debug('PersonnelChangePublisherBatch が正常にスケジュールされました。');
```

スケジュール登録後は **Setup → スケジュール済み Apex** で `PersonnelChangePublisherBatch` が表示されることを確認してください。

---

## ステップ 7: Experience Cloud サイトの有効化と権限セットの割り当て

### Experience Cloud サイトの有効化

1. **Setup → Experience Cloud サイト** を開く
2. 会員ポータルサイトが一覧に表示されていることを確認
3. ステータスが **「公開済み」** になっていない場合は **「公開」** ボタンをクリック
4. サイト URL を記録しておく（例: `https://your-org.my.site.com/member`）

### 権限セットの割り当て

デプロイ後に以下の権限セットをユーザーに割り当てる必要があります。

| 権限セット | 対象ユーザー |
|---|---|
| `MemberPortalAdmin` | ポータル管理者（設定変更・会員管理権限が必要なユーザー） |
| `MemberPortalUser` | 一般会員ユーザー（Experience Cloud ゲストユーザー以外） |

```bash
# 権限セットの割り当て（CLI から実行）
sf org assign permset \
  --name MemberPortalAdmin \
  --on-behalf-of admin-user@example.com \
  --target-org member-portal-org

sf org assign permset \
  --name MemberPortalUser \
  --on-behalf-of member@example.com \
  --target-org member-portal-org
```

---

## ステップ 8: Named Credentials の設定（デプロイ後必須）

以下の Named Credentials はメタデータとしてデプロイされますが、**実際の認証情報（API キーなど）はデプロイ後に手動で設定する必要があります**。

!!! warning "デプロイ直後は API 連携が無効"
    Named Credentials の認証情報が未設定の状態では、決済処理・Slack 通知・Okta 認証が正常に動作しません。デプロイ後すぐに以下の設定を行ってください。

| Named Credential | エンドポイント | 認証方式 |
|---|---|---|
| `PayjpAPI` | `https://api.pay.jp` | Basic 認証（API キー） |
| `OmiseAPI` | `https://api.omise.co` | Basic 認証（秘密鍵） |
| `StripeAPI` | `https://api.stripe.com` | Bearer Token |
| `FincodeAPI` | `https://api.fincode.jp` | API キー（カスタムヘッダー） |
| `SlackAPI` | `https://slack.com/api` | Bearer Token（Bot Token） |
| `OktaAPI` | `https://<your-domain>.okta.com` | Bearer Token |

Named Credentials の設定手順は **[デプロイ後設定](post-deploy.md)** を参照してください。

---

## デプロイチェックリスト

デプロイ完了後、以下をすべて確認してください。

- [ ] `sf project deploy start` が正常完了（エラー 0 件）
- [ ] `sf apex run test` が全テスト合格（カバレッジ 75% 以上）
- [ ] `PersonnelChangePublisherBatch` のスケジュールが登録済み
- [ ] Experience Cloud サイトが **公開済み** 状態
- [ ] `MemberPortalAdmin` / `MemberPortalUser` 権限セットが適切なユーザーに割り当て済み
- [ ] Named Credentials（PayjpAPI, OmiseAPI, StripeAPI, FincodeAPI, SlackAPI, OktaAPI）の認証情報設定済み

---

## 次のステップ

デプロイが完了したら、[デプロイ後設定](post-deploy.md) に進んで Named Credentials・ポータル設定・共有ルールなどの手動設定を行ってください。
