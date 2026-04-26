# フォームビルダー

管理者が再利用可能なフォームテンプレートを作成・管理するためのツールです。

---

## 概要

フォームビルダーは、総会の出欠確認・委任状・議決権行使・アンケートなど、さまざまな用途のフォームを動的に定義する管理ツールです。

!!! info "対象ユーザー"
    フォームビルダー（`formBuilderAdmin` LWC）は**管理者専用**です。AppPage または Tab のターゲットとして配置され、ポータルユーザーからはアクセスできません。

---

## コンポーネント

| コンポーネント | 種別 | 配置ターゲット | 用途 |
|--------------|------|-------------|------|
| `formBuilderAdmin` | LWC | AppPage / Tab | テンプレートの作成・編集・管理 |

---

## データモデル

```
FormTemplate__c（テンプレート）
    │
    └─── FormField__c（フィールド定義、MasterDetail）
              ・SortOrder__c で並び順を制御
              ・各フィールドにフィールド種別・ラベル・必須フラグを設定
```

### FormTemplate__c 主要項目

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `Name` | Text | テンプレート名 |
| `FormType__c` | Picklist | フォーム種別（下記参照） |
| `Description__c` | Text | 説明・用途 |
| `Deadline__c` | DateTime | 回答期限 |
| `AuthRequired__c` | Checkbox | 認証必須（ログインユーザーのみ回答可） |
| `SaveToRecord__c` | Checkbox | 回答を関連レコードに保存するか |
| `SendConfirmationEmail__c` | Checkbox | 送信後に確認メールを送るか |
| `IsActive__c` | Checkbox | 有効フラグ（無効化すると新規回答を受け付けない） |
| `AssignedToUser__c` | Lookup(User) | 担当者（タスク管理用） |

### フォーム種別（FormType__c）

| 値 | 説明 |
|----|------|
| `出欠確認` | 総会の出欠確認フォーム |
| `委任状` | 議決権の委任状フォーム |
| `議決権行使` | 書面による議決権行使フォーム |
| `アンケート` | 一般的なアンケート |
| `参加申込` | イベント・セミナーの参加申込 |
| `カスタム` | 上記に該当しない独自フォーム |

---

## フィールド種別（FormField__c）

### FormField__c 主要項目

| 項目API名 | 型 | 説明 |
|-----------|-----|------|
| `FieldType__c` | Picklist | フィールド種別 |
| `FieldLabel__c` | Text | 表示ラベル |
| `ApiKey__c` | Text | 機械可読キー（`FieldAnswersJson__c` のキーとして使用） |
| `IsRequired__c` | Checkbox | 必須フラグ |
| `SortOrder__c` | Number | 表示順 |
| `PicklistOptions__c` | LongTextArea | 選択肢（1行1オプション） |
| `HelpText__c` | Text | ヘルプテキスト |
| `DefaultValue__c` | Text | デフォルト値 |
| `FormTemplate__c` | MasterDetail | 親テンプレート |

### 利用可能なフィールド種別

| `FieldType__c` | 表示名 | 説明 |
|---------------|--------|------|
| `text` | テキスト | 1行テキスト入力 |
| `textarea` | テキストエリア | 複数行テキスト入力 |
| `select_single` | 選択（単一） | ラジオボタン / ドロップダウン |
| `select_multi` | 選択（複数） | チェックボックスグループ |
| `checkbox` | チェックボックス | 単一チェックボックス |
| `date` | 日付 | 日付ピッカー |
| `number` | 数値 | 数値入力 |
| `email` | メールアドレス | メール形式バリデーション付き |
| `signature` | 署名 | 手書き署名キャプチャ |
| `section` | セクション区切り | 見出し・区切り線（回答項目ではない） |

!!! tip "選択肢の入力方法"
    `select_single` / `select_multi` フィールドの選択肢は `PicklistOptions__c` に**1行1オプション**で入力します。

    ```
    賛成
    反対
    棄権
    ```

    上記のように入力すると、3つの選択肢（賛成・反対・棄権）が生成されます。

---

## テンプレートの作成手順

```
1. formBuilderAdmin LWC を開く
    │
    ▼
2. [新規テンプレート] ボタンをクリック
    │
    ▼
3. 基本情報を入力
    │  ・テンプレート名（Name）
    │  ・フォーム種別（FormType__c）
    │  ・説明（Description__c）
    │  ・回答期限（Deadline__c）
    │  ・認証必須（AuthRequired__c）
    │  ・レコード保存（SaveToRecord__c）
    │  ・確認メール送信（SendConfirmationEmail__c）
    ▼
4. フィールドを追加
    │  ① [フィールド追加] ボタン
    │  ② フィールド種別を選択
    │  ③ ラベル・ApiKey・必須フラグを設定
    │  ④ 選択系フィールドは PicklistOptions__c に選択肢を入力
    │  ⑤ ドラッグ＆ドロップで並び替え（SortOrder__c が自動更新）
    ▼
5. [保存] ボタンをクリック
    │  → saveFields() が実行され、FormField__c が一括保存される
    ▼
6. IsActive__c = true に設定して公開
```

!!! warning "saveFields() の実装について"
    `saveFields()` は既存の `FormField__c` をすべて**削除してから再挿入**する delete-and-reinsert 方式で実装されています。これにより `SortOrder__c` の整合性を保証しています。フィールドの `Id` が変わるため、保存前に取得した `FormField__c` の `Id` を保持したままにしないよう注意してください。

    ```apex
    public static void saveFields(Id templateId, List<FormField__c> fields) {
        // 既存フィールドを全削除
        delete [SELECT Id FROM FormField__c WHERE FormTemplate__c = :templateId];
        // 新しい順序で再挿入
        for (Integer i = 0; i < fields.size(); i++) {
            fields[i].SortOrder__c = i + 1;
            fields[i].FormTemplate__c = templateId;
            fields[i].Id = null; // 新規挿入
        }
        insert fields;
    }
    ```

---

## テンプレートの複製

昨年の総会フォームを再利用する場合など、既存テンプレートを複製できます。

```
テンプレート一覧から [複製] ボタンをクリック
    │
    ▼
FormTemplate__c を新規作成（Name に「（コピー）」を付加）
    │
    ▼
元テンプレートの全 FormField__c を複製して新テンプレートに紐付け
    │
    ▼
複製されたテンプレートの編集画面を開く
```

!!! tip "複製後の作業"
    複製後は以下の項目を必ず確認・更新してください。

    - `Name`（テンプレート名）— 年度を更新
    - `Deadline__c`（回答期限）— 今年の日程に変更
    - `IsActive__c`（有効フラグ）— 適切なタイミングで `true` に設定

---

## 有効化・無効化

| 操作 | `IsActive__c` の値 | 挙動 |
|------|------------------|------|
| 有効化 | `true` | 新規回答の受け付け開始 |
| 無効化 | `false` | 新規回答を受け付けない（既存回答は保持） |

!!! note "注意"
    無効化（`IsActive__c = false`）は、フォームを非公開にするものです。既に送信された `FormResponse__c` レコードには影響しません。

---

## ApiKey__c と FieldAnswersJson__c

`FormField__c.ApiKey__c` は `FormResponse__c.FieldAnswersJson__c` のキーとして使用される機械可読識別子です。

### FieldAnswersJson__c の形式例

```json
{
  "company_name": "株式会社サンプル",
  "department": "経営企画部",
  "attendance_type": "対面参加",
  "dietary_restrictions": ["アレルギーなし"],
  "remarks": "駐車場の利用を希望します"
}
```

!!! info "ApiKey__c の命名規則"
    `ApiKey__c` はアルファベット小文字、数字、アンダースコアのみで構成してください。スペースや日本語は使用しないでください。

    - 良い例: `company_name`, `attendance_type`, `remarks`
    - 悪い例: `会社名`, `Company Name`, `attendance-type`

---

## 担当者アサイン（AssignedToUser__c）

`FormTemplate__c.AssignedToUser__c` を設定することで、フォームの管理担当者を指定できます。

| 用途 | 説明 |
|------|------|
| タスク管理 | 誰がこのフォームの管理責任を持つかを明示 |
| 通知 | 回答数が閾値を超えた場合の通知先として利用（将来拡張） |
| 権限管理 | 現時点では閲覧権限の制御には使用しない |
