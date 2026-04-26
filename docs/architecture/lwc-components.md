# LWC コンポーネントリファレンス

Willen 会員ポータルで使用する Lightning Web Components（LWC）の一覧と、各コンポーネントのユーザー操作パターンを説明します。

---

## コンポーネント一覧

| コンポーネント名 | ターゲット | 説明 | 主要プロパティ |
|---|---|---|---|
| `memberPortalDashboard` | lightningCommunity__Page | ポータルホーム画面 | - |
| `memberRegistrationForm` | lightningCommunity__Page | 会員登録フォーム | - |
| `paymentForm` | lightningCommunity__Page | 支払い処理画面 | - |
| `donationForm` | lightningCommunity__Page | 寄附フォーム | - |
| `orgChartViewer` | lightningCommunity__Page | 組織図ビューア | - |
| `changeRequestForm` | lightningCommunity__Page | 組織変更申請フォーム | - |
| `supportInquiryForm` | lightningCommunity__Page | サポート問い合わせフォーム | - |
| `activityEventPortal` | lightningCommunity__Page, AppPage | イベント一覧・参加登録 | `showInternalEvents` (Boolean) |
| `activityRegistration` | lightningCommunity__Page | スタンドアロン参加登録 | - |
| `teamWikiViewer` | lightningCommunity__Page, AppPage | Wiki閲覧・編集 | `orgUnitId` (String) |
| `teamWikiEditor` | lightningCommunity__Page, AppPage | Wikiスタンドアロンエディター | - |
| `generalMeetingForm` | lightningCommunity__Page, AppPage | 総会出欠フォーム | `memberId` (String), `isAdmin` (Boolean) |
| `formBuilderAdmin` | AppPage, Tab | フォームテンプレートビルダー | - |
| `individualNotificationComposer` | AppPage, Tab | 個別通知コンポーザー | - |
| `portalConfigAdmin` | AppPage, Tab | ポータル設定管理画面 | - |
| `donorRegistrationView` | AppPage, Tab | 寄附者一覧管理 | - |

---

## 各コンポーネント詳細

### memberPortalDashboard

**ターゲット:** `lightningCommunity__Page`

ポータルのメインホーム画面。ログインした会員に対して各機能へのナビゲーションカードを表示します。

**ユーザー操作フロー:**
```
ログイン後にポータルホームを表示
    │
    ▼
会員情報サマリー（氏名・所属・会員種別）
    │
    ├── 「支払い履歴」カード → paymentForm へ遷移
    ├── 「問い合わせ」カード → supportInquiryForm へ遷移
    ├── 「イベント」カード → activityEventPortal へ遷移
    ├── 「組織図」カード → orgChartViewer へ遷移
    └── 「総会情報」カード → generalMeetingForm へ遷移
```

---

### memberRegistrationForm

**ターゲット:** `lightningCommunity__Page`

新規会員登録フォーム。会員種別（正会員・賛助会員）を選択して基本情報を入力します。

**ユーザー操作フロー:**
```
会員種別を選択（正会員 / 賛助会員）
    │
    ▼
基本情報入力（氏名・メール・所属組織）
    │
    ▼
MemberRegistrationController.registerMember() 呼び出し
    │
    ├── 成功 → 完了画面表示・確認メール送信
    └── エラー → インラインバリデーションメッセージ
```

---

### paymentForm

**ターゲット:** `lightningCommunity__Page`

年会費・各種費用の支払い画面。決済プロバイダー（Pay.jp / Omise / Stripe / Fincode）を PortalConfiguration__c の設定に基づいて切り替えます。

**ユーザー操作フロー:**
```
支払い金額・種別の確認
    │
    ▼
カード情報入力（各決済プロバイダーの JS SDK を使用）
    │
    ▼
トークン化（カード番号はサーバーに送信しない）
    │
    ▼
PaymentGatewayService.processPayment() 呼び出し
    │
    ├── 成功 → 領収書画面
    └── エラー → 決済エラーメッセージ
```

!!! note "口座振替"
    口座振替を選択した場合、`PaymentGatewayService.getDirectDebitFormUrl()` から申込書URLを取得し、外部ページへリダイレクトします。

---

### donationForm

**ターゲット:** `lightningCommunity__Page`

会員による任意の寄附申込フォーム。金額・支払い方法を選択して手続きします。

**ユーザー操作フロー:**
```
寄附金額を入力（任意の金額 or プリセット金額から選択）
    │
    ▼
支払い方法を選択（カード / 口座振替）
    │
    ▼
DonationController.createDonation() → 支払い処理
    │
    ▼
完了メッセージ + 寄附証明書のダウンロードリンク
```

---

### orgChartViewer

**ターゲット:** `lightningCommunity__Page`

インタラクティブな組織図ビューア。

**ユーザー操作フロー:**
```
OrgChartController.getOrgUnits() でツリーデータ取得
    │
    ▼
階層ツリー形式で組織を表示
    │
    ├── 組織ノードをクリック → 所属メンバー一覧を展開
    └── 会員名をクリック → 会員詳細モーダル表示
```

---

### changeRequestForm

**ターゲット:** `lightningCommunity__Page`

組織構成変更（異動・昇進・退職等）の申請フォーム。

**ユーザー操作フロー:**
```
変更種別を選択（異動 / 昇進 / 退職 / 新規配属）
    │
    ▼
対象会員・変更内容・有効日を入力
    │
    ▼
ChangeRequestController.submitChangeRequest() 呼び出し
    │
    ▼
承認ワークフロー開始（WorkflowApprovalService）
    │
    ▼
承認者へメール通知
```

---

### supportInquiryForm

**ターゲット:** `lightningCommunity__Page`

会員がサポートチケットを送信するフォーム。管理者モードではエスカレーション・内部メモ機能が使用可能です。

**ユーザー操作フロー（会員）:**
```
件名・問い合わせ種別・本文を入力
    │
    ▼
優先度を選択（高 / 中 / 低）
    │
    ▼
SupportInquiryController.submitInquiry() 呼び出し
    │
    ▼
SLADeadline__c が自動計算・設定される
    │
    ▼
送信完了メッセージ（チケット番号表示）
```

**追加機能（管理者）:**
```
チケット一覧 → 詳細を開く
    │
    ├── 「返答する」→ respondToInquiry() → IsSLAMet__c 更新
    ├── 「エスカレーション」→ escalateInquiry() → 優先度引き上げ
    └── 「内部メモ追加」→ addInternalNote() → タイムスタンプ付き追記
```

---

### activityEventPortal

**ターゲット:** `lightningCommunity__Page`, `AppPage`

イベント一覧のカードグリッド表示と登録フォームを統合したコンポーネント。

```html
<!-- showInternalEvents プロパティで表示対象を切り替え -->
<c-activity-event-portal show-internal-events="false"></c-activity-event-portal>
```

| プロパティ | 型 | デフォルト | 説明 |
|---|---|---|---|
| `showInternalEvents` | Boolean | `false` | `true` = 全イベント; `false` = 公開イベントのみ |

**ユーザー操作フロー（会員・ゲスト）:**
```
カードグリッドにイベント一覧表示
    │
    ▼
カードをクリック → イベント詳細スライドアウト
（開催日時・定員残数・参加費・オンラインURL）
    │
    ▼
「申し込む」ボタン → 登録フォーム表示
（氏名・メールアドレス・所属組織）
    │
    ▼
registerForEvent() 呼び出し → 定員・締切チェック
    │
    ├── 成功 → 完了トースト
    └── エラー（定員超過/期限切れ） → エラートースト
```

**管理者のイベント作成:**
```
「＋ イベントを作成」ボタン（管理者のみ表示）
    │
    ▼
モーダルフォーム（タイトル・日時・定員・公開設定）
    │
    ▼
ActivityController.createEvent() → カードグリッド更新
```

---

### activityRegistration

**ターゲット:** `lightningCommunity__Page`

スタンドアロンの参加登録コンポーネント。Experience Cloud の専用イベント詳細ページから直接呼び出されます。

**ユーザー操作フロー:**
```
URL パラメータでイベントIDを受け取る
    │
    ▼
イベント詳細を表示（ActivityController.getPublicEvents()）
    │
    ▼
参加者情報を入力して登録
```

---

### teamWikiViewer

**ターゲット:** `lightningCommunity__Page`, `AppPage`

Wiki ページの閲覧とインライン編集を行うコンポーネント。

| プロパティ | 型 | 説明 |
|---|---|---|
| `orgUnitId` | String | 表示する組織単位のID。指定なしの場合は全Wikiを表示 |

**ユーザー操作フロー:**
```
左サイドバー: Wikiスペース一覧（組織別）
    │
    ▼
Wikiをクリック → ページ一覧表示
    │
    ▼
ページをクリック → Markdown レンダリング表示
    │
    ├── 「編集」ボタン（編集権限あり）→ インラインエディター起動
    │       │
    │       ▼
    │   TeamWikiController.savePage() → WikiPageVersion__c を保存
    │
    └── 「変更履歴」タブ → getPageVersions() → バージョン一覧
```

---

### teamWikiEditor

**ターゲット:** `lightningCommunity__Page`, `AppPage`

Wikiページの専用スタンドアロンエディター（フルスクリーン編集向け）。

**ユーザー操作フロー:**
```
Markdownエディター（左）・プレビュー（右）の分割ビュー
    │
    ▼
保存ボタン → TeamWikiController.savePage()
    │
    ▼
バージョン履歴に自動保存 + teamWikiViewer へ戻る
```

---

### generalMeetingForm

**ターゲット:** `lightningCommunity__Page`, `AppPage`

総会の出欠回答フォーム。管理者モードでは回答集計・リマインダー送信が可能です。

| プロパティ | 型 | 説明 |
|---|---|---|
| `memberId` | String | 回答する会員のID |
| `isAdmin` | Boolean | `true` = 管理者モード（回答集計・リマインダー機能有効） |

**ユーザー操作フロー（会員）:**
```
総会一覧から対象を選択
    │
    ▼
出欠選択（出席 / 欠席 / 委任状提出）
    │
    ▼
FormBuilderController で構成したフォームフィールドへ入力
    │
    ▼
GeneralMeetingController.submitAttendanceResponse()
    │
    ▼
完了メッセージ + 確認メール送信
```

**管理者モード（isAdmin=true）:**
```
回答集計グラフ表示（出席 / 欠席 / 委任 の内訳）
    │
    ├── 「リマインダー送信」→ sendReminders() → 未回答者にメール
    └── 回答一覧のエクスポート（CSV）
```

---

### formBuilderAdmin

**ターゲット:** `AppPage`, `Tab`（管理者専用）

動的フォームのテンプレートを作成・管理する管理者向けビルダー。

!!! warning "MemberPortalAdmin 専用"
    このコンポーネントは `MemberPortalAdmin` 権限セットを持つユーザーのみが使用できます。

**ユーザー操作フロー:**
```
テンプレート一覧 → 「新規作成」または既存を選択
    │
    ▼
フィールドを追加（テキスト / 選択肢 / 日付 / チェックボックス）
    │
    ▼
ドラッグ&ドロップで並び替え
    │
    ▼
FormBuilderController.saveFields() → フィールド定義を保存
    │
    ├── 「有効化」→ toggleActive(true) → 会員が回答可能に
    └── 「複製」→ duplicateTemplate() → 別名で保存
```

---

### individualNotificationComposer

**ターゲット:** `AppPage`, `Tab`（管理者専用）

管理者が特定の会員または会員グループへ個別メール通知を送信するコンポーザー。

**ユーザー操作フロー:**
```
テンプレートを選択 or 本文を直接入力
    │
    ▼
プレースホルダー挿入ボタン（{!Member.Name} 等）
    │
    ▼
宛先の会員を選択（個人 / フィルター条件）
    │
    ├── 「テストメール送信」→ sendTestEmail() → 自分のアドレスへ送信
    ├── 「下書き保存」→ saveDraft()
    ├── 「送信予約」→ scheduleNotification(scheduledAt)
    └── 「即時送信」→ createAndSend()
```

---

### portalConfigAdmin

**ターゲット:** `AppPage`, `Tab`（管理者専用）

ポータル全体の設定（決済キー・Okta設定・年会費等）を管理する画面。詳細は [ポータル設定](../administration/portal-config.md) を参照してください。

---

### donorRegistrationView

**ターゲット:** `AppPage`, `Tab`（管理者専用）

寄附者の一覧と詳細を管理する管理者向けビュー。

**ユーザー操作フロー:**
```
寄附者一覧テーブル（氏名・金額・日付・支払い状況）
    │
    ▼
行をクリック → 寄附詳細スライドアウト
    │
    ├── 支払い状況を更新
    └── 寄附証明書を再発行
```

---

## デプロイ時の注意事項

!!! tip "Experience Cloud コンポーネントの表示設定"
    `lightningCommunity__Page` をターゲットに持つコンポーネントは、Experience Cloud Builder で各ページのコンポーネントパネルに表示されます。適切なプロパティを Experience Builder の設定パネルから設定してください。

!!! warning "AppPage/Tab ターゲットは内部 Salesforce アプリ専用"
    `formBuilderAdmin`、`individualNotificationComposer`、`portalConfigAdmin`、`donorRegistrationView` は `AppPage`/`Tab` ターゲットのみです。これらは Experience Cloud には公開しないでください。
