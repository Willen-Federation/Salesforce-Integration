# Willen 会員ポータル

**Salesforce Experience Cloud ベースの会員管理・運営統合プラットフォーム**

---

Willen 会員ポータルは、Salesforce Experience Cloud 上に構築された会員管理システムです。正会員・準会員・賛助会員の三区分に対応した入会/退会フロー、複数決済プロバイダー（Pay.jp / Omise / Stripe / Fincode）との連携、定時総会フォームの電子化、チームWikiによる情報共有、人事変更の予約管理、PlaceFolder 差し込みフィールドを活用した個別通知送信など、会員組織の運営に必要な機能をワンストップで提供します。

<div class="grid cards" markdown>

-   :fontawesome-solid-users: **会員管理**

    ---

    正会員・準会員・賛助会員の入退会、会員情報の編集、会員区分変更申請を管理します。

    [:octicons-arrow-right-24: 機能ガイドへ](features/member-management.md)

-   :fontawesome-solid-credit-card: **支払い・決済**

    ---

    Pay.jp / Omise / Stripe / Fincode を切り替えて年会費決済を処理。領収書自動発行に対応。

    [:octicons-arrow-right-24: 機能ガイドへ](features/payments.md)

-   :fontawesome-solid-file-signature: **総会フォーム**

    ---

    定時総会・臨時総会の出欠確認フォームをオンラインで配布・集計します。

    [:octicons-arrow-right-24: 機能ガイドへ](features/general-meeting.md)

-   :fontawesome-solid-table-list: **フォームビルダー**

    ---

    管理者がノーコードでカスタムフォームを作成し、会員向けに公開できます。

    [:octicons-arrow-right-24: 機能ガイドへ](features/form-builder.md)

-   :fontawesome-solid-book-open: **チームWiki**

    ---

    チーム単位でナレッジベースを管理。共有範囲は共有ルールで制御します。

    [:octicons-arrow-right-24: 機能ガイドへ](features/team-wiki.md)

-   :fontawesome-solid-calendar-days: **人事変更予約**

    ---

    役員・担当者の変更を予約し、`PersonnelChangePublisherBatch` が自動適用します。

    [:octicons-arrow-right-24: 機能ガイドへ](features/personnel-change.md)

-   :fontawesome-solid-bell: **個別通知**

    ---

    PlaceFolder 差し込みフィールドを使ったパーソナライズ通知をメール・Slack で送信。

    [:octicons-arrow-right-24: 機能ガイドへ](features/notifications.md)

-   :fontawesome-solid-headset: **サポート問い合わせ**

    ---

    会員からの問い合わせを Case オブジェクトで受け付け、対応状況をトラッキングします。

    [:octicons-arrow-right-24: 機能ガイドへ](features/support-inquiry.md)

-   :fontawesome-solid-calendar-check: **活動・イベント管理**

    ---

    勉強会・交流イベントの告知、参加登録、出欠管理を一元化します。

    [:octicons-arrow-right-24: 機能ガイドへ](features/activity-events.md)

</div>

---

## クイックスタート

まずはこちらのページから始めてください。

| ステップ | ドキュメント |
|---|---|
| 1. 環境要件の確認 | [前提条件](getting-started/prerequisites.md) |
| 2. デプロイ手順 | [インストール](getting-started/installation.md) |
| 3. デプロイ後設定 | [デプロイ後設定](getting-started/post-deploy.md) |
| 4. データ構造の把握 | [データモデル](architecture/data-model.md) |

---

## 技術スタック

<div class="grid" markdown>

<div markdown>

| コンポーネント | バージョン / 詳細 |
|---|---|
| **Salesforce API** | v59.0 |
| **フロントエンド** | Lightning Web Components (LWC) |
| **バックエンド** | Apex (同期 / 非同期バッチ) |
| **ポータル基盤** | Salesforce Experience Cloud |
| **ID プロバイダー** | Okta (SAML 2.0 / JIT プロビジョニング) |
| **チャット連携** | Slack (Bot Token / Incoming Webhook) |
| **決済プロバイダー** | Pay.jp / Omise / Stripe / Fincode |

</div>

</div>

---

## ドキュメント構成

```
docs/
├── index.md                    # このページ
├── getting-started/
│   ├── prerequisites.md        # 前提条件
│   ├── installation.md         # インストール・デプロイ手順
│   └── post-deploy.md          # デプロイ後手動設定
├── features/                   # 機能ガイド（各機能の操作説明）
├── architecture/               # 設計ドキュメント（データモデル・Apex・LWC）
├── administration/             # 管理者向けガイド
└── reference/                  # 差し込みフィールド一覧・変更履歴
```

!!! tip "最初に読むべきページ"
    新規メンバーは **[前提条件](getting-started/prerequisites.md)** → **[インストール](getting-started/installation.md)** → **[デプロイ後設定](getting-started/post-deploy.md)** の順に読み進めてください。システム管理者は **[データモデル](architecture/data-model.md)** および **[セキュリティモデル](architecture/security.md)** も必ず確認してください。
