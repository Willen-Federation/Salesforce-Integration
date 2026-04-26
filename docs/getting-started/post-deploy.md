# デプロイ後設定

メタデータのデプロイが完了した後、Salesforce 組織内で手動設定が必要な項目を説明します。これらの設定を行わないと、決済・通知・認証などの主要機能が動作しません。

!!! warning "必須作業"
    このページの設定はすべて **必須** です。設定が完了するまでポータルを本番公開しないでください。

---

## 1. PortalConfiguration__c カスタム設定

PortalConfiguration__c はポータル全体の動作を制御するカスタム設定オブジェクトです。`portalConfigAdmin` LWC 管理画面から設定できます。

### 設定方法

1. Experience Cloud サイト管理者でログイン
2. **Setup → カスタム設定 → PortalConfiguration__c → 管理** を開く
   または、管理者向け LWC コンポーネント **portalConfigAdmin** が配置されたページを開く
3. 以下の項目を設定する

| フィールド名 | 説明 | 例 |
|---|---|---|
| `AnnualFee__c` | 正会員の年会費（円） | `12000` |
| `AssociateFee__c` | 準会員の年会費（円） | `6000` |
| `SupportingFee__c` | 賛助会員の年会費（円） | `30000` |
| `ActivePaymentProvider__c` | 使用する決済プロバイダー | `payjp` / `omise` / `stripe` / `fincode` |
| `SlackNotificationEnabled__c` | Slack 通知の有効化 | `true` / `false` |
| `OktaSsoEnabled__c` | Okta SSO の有効化 | `true` / `false` |
| `SupportEmailAddress__c` | サポート問い合わせの送信先メール | `support@example.com` |

!!! note "設定変更の即時反映"
    PortalConfiguration__c の変更はキャッシュなしで即時反映されます。ただし、決済プロバイダーの切り替えは進行中の決済セッションに影響しないよう、トラフィックが少ない時間帯に行ってください。

---

## 2. Named Credentials の設定

Named Credentials は各外部 API の接続情報を管理します。**Setup → Named Credentials** から設定してください。

### 各 Named Credential の設定手順

**Setup → セキュリティ → Named Credentials → 外部資格情報** の順に開き、各エントリを編集します。

=== "Pay.jp"

    | 項目 | 値 |
    |---|---|
    | **名前** | `PayjpAPI` |
    | **URL** | `https://api.pay.jp` |
    | **認証プロトコル** | パスワード認証（Basic） |
    | **ユーザー名** | Pay.jp の秘密鍵（`sk_live_...` または `sk_test_...`） |
    | **パスワード** | （空欄） |

=== "Omise"

    | 項目 | 値 |
    |---|---|
    | **名前** | `OmiseAPI` |
    | **URL** | `https://api.omise.co` |
    | **認証プロトコル** | パスワード認証（Basic） |
    | **ユーザー名** | Omise の秘密鍵（`skey_...`） |
    | **パスワード** | （空欄） |

=== "Stripe"

    | 項目 | 値 |
    |---|---|
    | **名前** | `StripeAPI` |
    | **URL** | `https://api.stripe.com` |
    | **認証プロトコル** | カスタムヘッダー |
    | **ヘッダー名** | `Authorization` |
    | **ヘッダー値** | `Bearer sk_live_...`（または `sk_test_...`） |

=== "Fincode"

    | 項目 | 値 |
    |---|---|
    | **名前** | `FincodeAPI` |
    | **URL** | `https://api.fincode.jp` |
    | **認証プロトコル** | カスタムヘッダー |
    | **ヘッダー名** | `Authorization` |
    | **ヘッダー値** | `Bearer <Fincode APIキー>` |

=== "Slack"

    | 項目 | 値 |
    |---|---|
    | **名前** | `SlackAPI` |
    | **URL** | `https://slack.com/api` |
    | **認証プロトコル** | カスタムヘッダー |
    | **ヘッダー名** | `Authorization` |
    | **ヘッダー値** | `Bearer xoxb-...`（Bot Token） |

=== "Okta"

    | 項目 | 値 |
    |---|---|
    | **名前** | `OktaAPI` |
    | **URL** | `https://<your-domain>.okta.com` |
    | **認証プロトコル** | カスタムヘッダー |
    | **ヘッダー名** | `Authorization` |
    | **ヘッダー値** | `SSWS <Okta APIトークン>` |

!!! warning "本番用 API キーの管理"
    API キーはソースコードやドキュメントに記載しないでください。Named Credentials として Salesforce 内で安全に管理し、アクセス権を持つ管理者のみが参照できるようにしてください。

---

## 3. リモートサイト設定の確認

**Setup → セキュリティ → リモートサイト設定** を開き、以下のエントリがすべて **有効** になっていることを確認してください。

| リモートサイト名 | URL | 状態 |
|---|---|---|
| `PayjpAPI` | `https://api.pay.jp` | 有効 |
| `OmiseAPI` | `https://api.omise.co` | 有効 |
| `StripeAPI` | `https://api.stripe.com` | 有効 |
| `FincodeAPI` | `https://api.fincode.jp` | 有効 |
| `SlackAPI` | `https://slack.com` | 有効 |

!!! note "メタデータで自動登録"
    上記のリモートサイト設定はデプロイ時にメタデータとして自動登録されます。ただし、カスタムサブドメインを使用している場合（例: Okta のカスタムドメイン）は手動での追加が必要です。

---

## 4. 共有ルールの有効化確認

**Setup → セキュリティ → 共有設定** を開き、以下のオブジェクトの共有ルールが正しく設定されていることを確認してください。

| オブジェクト | 共有ルール名 | 共有の基準 | 共有先 |
|---|---|---|---|
| `Member__c` | `MemberSameTeamShare` | チームが同一 | チームメンバー（読み取り） |
| `TeamWiki__c` | `TeamWikiShare` | チームが同一 | チームメンバー（読み取り/書き込み） |
| `TeamWiki__c` | `TeamWikiAdminShare` | — | MemberPortalAdmin 権限セット（フルアクセス） |

!!! warning "共有ルールが無効な場合"
    共有ルールが無効または削除されている場合、チームWikiが他のチームメンバーに表示されない、または他チームのデータが誤って表示される可能性があります。必ず確認してください。

---

## 5. Okta SAML 設定

Okta との SAML 2.0 連携の詳細な設定手順は、リポジトリ内のドキュメントを参照してください。

```
docs/OKTA_SAML_SETUP.md
```

主な設定ステップ:

1. Okta 管理コンソールで新規 SAML 2.0 アプリケーションを作成
2. Salesforce のエンティティ ID と ACS URL を Okta に設定
3. Salesforce Setup で **ID プロバイダー** として Okta を登録
4. JIT (Just-In-Time) プロビジョニングの属性マッピングを設定
5. テストユーザーで SSO ログインが成功することを確認

!!! tip "JIT プロビジョニング"
    JIT プロビジョニングを有効にすると、Okta で管理されているユーザーが初回 SSO ログイン時に Salesforce にユーザーアカウントが自動作成されます。事前に Salesforce 側のユーザーを作成する手間が省けます。

---

## 6. PersonnelChangePublisherBatch スケジュールの確認

バッチジョブが正しくスケジュールされているか確認します。

### 確認手順

1. **Setup → カスタムコード → スケジュール済み Apex** を開く
2. `PersonnelChangePublisherBatch` が一覧に表示されることを確認
3. **次回実行日時** が現在日時より未来であることを確認
4. **頻度** が **毎時間** になっていることを確認

### 再スケジュールが必要な場合

スケジュール済みジョブ一覧に表示されない場合は、匿名 Apex で再登録してください。

```apex
// まず既存ジョブを削除（存在する場合）
List<CronTrigger> existing = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name = 'PersonnelChangePublisherBatch'
];
for (CronTrigger ct : existing) {
    System.abortJob(ct.Id);
}

// 再スケジュール
PersonnelChangePublisherBatch.scheduleHourly();
System.debug('PersonnelChangePublisherBatch を再スケジュールしました。');
```

---

## 7. Experience Cloud ホームページの設定

### ダッシュボードページの設定

1. **Experience Cloud サイトビルダー** を開く
2. ホームページに `memberPortalDashboard` LWC コンポーネントが配置されていることを確認
3. 配置されていない場合: コンポーネントパネルから **memberPortalDashboard** をドラッグ＆ドロップして追加
4. **[公開]** ボタンをクリックしてページを公開

### ゲストユーザープロファイルの設定

1. **Setup → Experience Cloud サイト → [サイト名] → 管理** を開く
2. **[メンバー]** タブでゲストユーザープロファイルが設定されていることを確認
3. ゲストユーザーがアクセスできるオブジェクト（公開フォームなど）の参照権限がプロファイルに設定されていることを確認

!!! warning "ゲストユーザーのアクセス権"
    ゲストユーザー（未ログインユーザー）には最小限の権限のみ付与してください。Member__c オブジェクトへの参照権限をゲストユーザーに与えないよう注意してください。

---

## 設定完了チェックリスト

すべての設定が完了したら、以下のチェックリストを確認してください。

| # | 設定項目 | 確認方法 | 完了 |
|---|---|---|---|
| 1 | PortalConfiguration__c の年会費・プロバイダー設定 | portalConfigAdmin LWC で確認 | ☐ |
| 2 | Named Credential: PayjpAPI | 決済テスト実行 | ☐ |
| 3 | Named Credential: OmiseAPI | 決済テスト実行 | ☐ |
| 4 | Named Credential: StripeAPI | 決済テスト実行 | ☐ |
| 5 | Named Credential: FincodeAPI | 決済テスト実行 | ☐ |
| 6 | Named Credential: SlackAPI | テスト通知送信 | ☐ |
| 7 | Named Credential: OktaAPI | SSO テストログイン | ☐ |
| 8 | リモートサイト設定（全4件）が有効 | Setup で確認 | ☐ |
| 9 | Member__c 共有ルールが有効 | 共有設定画面で確認 | ☐ |
| 10 | TeamWiki__c 共有ルールが有効 | 共有設定画面で確認 | ☐ |
| 11 | Okta SAML 設定・JIT プロビジョニング | テストユーザーで SSO ログイン | ☐ |
| 12 | PersonnelChangePublisherBatch スケジュール登録 | スケジュール済み Apex で確認 | ☐ |
| 13 | memberPortalDashboard LWC の配置と公開 | Experience Cloud サイトで確認 | ☐ |
| 14 | ゲストユーザープロファイルの権限確認 | プロファイル設定で確認 | ☐ |
| 15 | 管理者ユーザーへの MemberPortalAdmin 権限セット割り当て | 権限セット割り当てで確認 | ☐ |

---

## 動作確認テスト

設定完了後、以下の動作確認を実施してください。

```bash
# 1. 匿名 Apex で決済プロバイダー接続確認
sf apex run --target-org member-portal-org --file scripts/apex/test-payment-connection.apex

# 2. Slack 通知テスト
sf apex run --target-org member-portal-org --file scripts/apex/test-slack-notification.apex
```

すべての動作確認が完了したら、ポータルの本番公開を行ってください。

---

## トラブルシューティング

| 症状 | 考えられる原因 | 対処 |
|---|---|---|
| 決済処理が失敗する | Named Credential の API キーが未設定または間違い | Named Credentials を再設定 |
| Slack 通知が届かない | SlackAPI の Bot Token が無効 | Slack アプリ管理画面でトークンを再発行 |
| Okta SSO でログインできない | SAML の設定ミス（ACS URL / エンティティ ID） | OKTA_SAML_SETUP.md を再確認 |
| チームWikiが表示されない | 共有ルールが無効 | Setup → 共有設定で共有ルールを再有効化 |
| バッチが実行されない | スケジュールが登録されていない | 匿名 Apex で `scheduleHourly()` を再実行 |
