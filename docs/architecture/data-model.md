# データモデル概要

Willen 会員ポータルで使用するカスタムオブジェクトの全体構成と関係を説明します。

---

## カスタムオブジェクト一覧

| オブジェクト名 | API名 | 共有モデル | 概要 |
|---|---|---|---|
| 会員 | `Member__c` | Private | ポータル会員の基本情報（氏名・メール・種別・ステータス） |
| 支払い | `Payment__c` | Private | 年会費・各種費用の支払い記録 |
| 寄附 | `Donation__c` | Private | 会員からの寄附記録（金額・日付・方法） |
| 活動・イベント | `Activity__c` | Public Read/Write | イベント・活動の定義（公開/非公開・定員・参加費） |
| 活動参加者 | `ActivityParticipant__c` | ControlledByParent | イベント参加者1名1レコード（MasterDetail→Activity__c） |
| 組織単位 | `OrgUnit__c` | Public Read/Write | 部署・チーム等の組織階層 |
| 人事変更 | `PersonnelChange__c` | Private | 異動・昇進・退職等の人事変更記録 |
| 変更申請 | `ChangeRequest__c` | Private | 組織構成変更の申請・承認ワークフロー |
| バッチ通知 | `BatchNotification__c` | Private | バッチ処理による通知ログ |
| サポート問い合わせ | `SupportInquiry__c` | Private | 会員からのサポートチケット・SLA管理 |
| ポータル設定 | `PortalConfiguration__c` | Private | サイト設定・決済キー等の管理者設定（シングルトン） |
| チームWiki | `TeamWiki__c` | Private | 組織単位に紐付くWikiスペース |
| Wikiページ | `WikiPage__c` | ControlledByParent | TeamWiki内の個別ページ（Markdown本文） |
| Wikiページ版 | `WikiPageVersion__c` | ControlledByParent | WikiPageの変更履歴（バージョニング） |
| 個別通知 | `IndividualNotification__c` | Private | 管理者から特定会員への個別メール通知 |
| 総会 | `GeneralMeeting__c` | Public Read/Write | 定期総会・臨時総会の開催情報 |
| フォームテンプレート | `FormTemplate__c` | Public Read/Write | 動的フォームの定義（質問構成） |
| フォームフィールド | `FormField__c` | ControlledByParent | FormTemplate内の個別フィールド定義 |
| フォーム回答 | `FormResponse__c` | Private | 会員によるフォーム回答（MasterDetail→FormTemplate__c） |
| フォームフィールド回答 | `FormFieldResponse__c` | ControlledByParent | 個別フィールドへの回答値 |

---

## 共有モデルの説明

| 共有モデル | 意味 |
|---|---|
| **Private** | レコードオーナーと上位権限ユーザーのみアクセス可。共有ルール・Apexシェアで追加付与 |
| **ControlledByParent** | 親レコードの共有設定を継承。子レコード単独では共有設定不可 |
| **Public Read/Write** | 全内部ユーザーが参照・編集可能 |

---

## オブジェクト関係図

```mermaid
erDiagram
    OrgUnit__c {
        string Name
        lookup ParentOrgUnit__c
    }

    Member__c {
        string Name
        lookup OrgUnit__c
        string MemberType__c
        string MemberStatus__c
    }

    PersonnelChange__c {
        lookup Member__c
        lookup FromOrgUnit__c
        lookup ToOrgUnit__c
        date EffectiveDate__c
    }

    TeamWiki__c {
        lookup OrgUnit__c
        string AccessLevel__c
    }

    WikiPage__c {
        masterdetail TeamWiki__c
        string Title__c
        longtext Body__c
    }

    WikiPageVersion__c {
        masterdetail WikiPage__c
        longtext Body__c
        integer VersionNumber__c
    }

    GeneralMeeting__c {
        string Name
        datetime MeetingDatetime__c
        string Status__c
    }

    FormTemplate__c {
        lookup GeneralMeeting__c
        string Name
        boolean IsActive__c
    }

    FormField__c {
        masterdetail FormTemplate__c
        string FieldLabel__c
        string FieldType__c
    }

    FormResponse__c {
        masterdetail FormTemplate__c
        lookup Member__c
    }

    FormFieldResponse__c {
        masterdetail FormResponse__c
        string FieldValue__c
    }

    IndividualNotification__c {
        lookup Member__c
        string Subject__c
        string Status__c
    }

    Activity__c {
        lookup Member__c
        boolean IsPublic__c
        datetime EventStartDatetime__c
        integer MaxParticipants__c
    }

    ActivityParticipant__c {
        masterdetail Activity__c
        lookup Member__c
        string ParticipationStatus__c
    }

    Payment__c {
        lookup Member__c
        currency Amount__c
        string Status__c
    }

    SupportInquiry__c {
        lookup Member__c
        string Priority__c
        datetime SLADeadline__c
    }

    Member__c       }o--||    OrgUnit__c          : "所属"
    PersonnelChange__c }o--||  Member__c           : "対象会員"
    PersonnelChange__c }o--o|  OrgUnit__c          : "異動元 (From)"
    PersonnelChange__c }o--o|  OrgUnit__c          : "異動先 (To)"
    TeamWiki__c     }o--||    OrgUnit__c           : "組織"
    WikiPage__c     }o--||    TeamWiki__c          : "Wiki"
    WikiPageVersion__c }o--|| WikiPage__c          : "ページ"
    FormTemplate__c }o--o|    GeneralMeeting__c    : "総会"
    FormField__c    }o--||    FormTemplate__c      : "テンプレート"
    FormResponse__c }o--||    FormTemplate__c      : "テンプレート"
    FormResponse__c }o--o|    Member__c            : "回答者"
    FormFieldResponse__c }o--|| FormResponse__c    : "回答"
    IndividualNotification__c }o--|| Member__c     : "宛先"
    Activity__c     }o--o|    Member__c            : "作成者"
    ActivityParticipant__c }o--|| Activity__c      : "イベント"
    ActivityParticipant__c }o--o| Member__c        : "参加会員"
    Payment__c      }o--||    Member__c            : "会員"
    SupportInquiry__c }o--o|  Member__c            : "問い合わせ会員"
```

---

## キー関係の詳細

### 会員 - 組織

```
OrgUnit__c (階層構造: 自己参照 ParentOrgUnit__c)
    └── Member__c (多:1 Lookup)
```

会員は1つの組織単位に所属します。組織単位は親子階層を持ちます（部門 > チーム等）。

---

### 人事変更 - 会員・組織

```
PersonnelChange__c
    ├── Member__c (対象者)
    ├── FromOrgUnit__c (異動元)
    └── ToOrgUnit__c  (異動先)
```

異動元・異動先はどちらも `OrgUnit__c` への Lookup です。同一フィールドではなく、それぞれ独立した項目です。

---

### フォーム回答 - 総会

```
GeneralMeeting__c
    └── FormTemplate__c (Lookup)
            ├── FormField__c (ControlledByParent)
            └── FormResponse__c (MasterDetail)
                    └── FormFieldResponse__c (ControlledByParent)
```

!!! note "フォームと総会の関係"
    `FormTemplate__c` は `GeneralMeeting__c` への Lookup（任意）を持ちます。総会の出欠確認フォームとして使用する場合に設定します。汎用フォームとして使う場合は空のままです。

---

### チームWiki - 組織

```
OrgUnit__c
    └── TeamWiki__c (Lookup)
            └── WikiPage__c (ControlledByParent)
                    └── WikiPageVersion__c (ControlledByParent)
```

WikiPage の更新は WikiPageVersion として履歴保存されます。

---

## オブジェクト設計上の注意点

!!! warning "ControlledByParent オブジェクトの共有設定"
    `ActivityParticipant__c`、`WikiPage__c`、`WikiPageVersion__c`、`FormField__c`、`FormFieldResponse__c` は共有モデルが `ControlledByParent` です。これらのオブジェクト単独で共有ルールを設定することはできません。親オブジェクトのアクセス権を変更することで制御します。

!!! tip "PortalConfiguration__c はシングルトン"
    `PortalConfiguration__c` は組織に1レコードのみ存在します。`PortalConfigController.savePortalConfig()` は `SetupOwnerId` を使った upsert で常に同一レコードを更新します。複数レコードを作成しないよう注意してください。
