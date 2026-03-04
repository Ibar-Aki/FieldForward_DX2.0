# 案B Power Automate実アクション手順書

作成日時: 2026-03-03 23:33:04 +09:00
作成者: Codex + GPT-5

## 1. 文書の目的

本書は、自動化案Bを実装する際に、Power Automate でどのトリガーとアクションを使うかを具体的に整理するものである。フロー設計レビュー、工数見積り、PoC 実装の叩き台に使う。

## 2. 前提

- 共有メールボックスを使う
- SharePoint Online をデータストアとして使う
- 既存 Excel 計算ツールを Excel Online (Business) + Office Scripts で実行する
- 初期は標準コネクタ中心で組む
- 1 日平均件数は 24 件程度

## 3. フロー一覧

| フロー名 | 役割 | 実行タイミング |
| --- | --- | --- |
| F01_メール受付 | メール受信と原本保存 | メール受信時 |
| F02_案件特定 | 送付元から案件候補を引く | F01 の後 |
| F03_自動可否判定 | 自動実行か確認回しかを決める | F02 の後 |
| F04_計算実行 | Excel 計算ツールを実行する | 自動可または承認後 |
| F05_帳票生成 | 結果帳票用データを整える | F04 の後 |
| F06_返信送信 | 添付生成と返信送信 | F05 の後 |
| F07_失敗通知 | 失敗時の通知 | 例外時 |

## 4. フロー F01_メール受付

### トリガー

- `When a new email arrives in a shared mailbox (V2)`

### 推奨設定

| 設定項目 | 推奨値 |
| --- | --- |
| Original Mailbox Address | 専用共有メールアドレス |
| Folder | Inbox |
| Include Attachments | Yes |
| Only with Attachments | Yes |
| Importance | Any |
| Subject Filter | 初期は空欄 |

### アクション順

1. `Initialize variable`
   - `varReceivedAt`
   - `varSourceMail`
   - `varOriginalId`

2. `Condition`
   - 添付が存在するか確認
   - 添付なしなら終了または自動返信

3. `Apply to each`
   - 添付ファイルごとに処理
   - 初期は PDF 以外を除外

4. `Condition`
   - ファイル拡張子が `.pdf` か確認

5. `Create file` (SharePoint)
   - 保存先: `受付原本`
   - ファイル名: `原本ID_元ファイル名`

6. `Update file properties`
   - 原本ID
   - 送信元メール
   - メール受信日時
   - 件名
   - 処理状態=`受付済`

7. `Create item` (SharePoint)
   - `確認キュー`
   - 原本ID
   - キュー状態=`新規`

### 実装メモ

- 初期は 1 メール 1 PDF を原則とし、複数 PDF は確認待ちへ回す方が安全
- 同名ファイル対策として原本IDをファイル名接頭辞に使う

## 5. フロー F02_案件特定

### 起動

- `When an item is created` on `確認キュー`

### アクション順

1. `Get item`
   - `確認キュー` の対象行を取得

2. `Get files (properties only)` または `Get file properties`
   - `受付原本` から送信元メールなどを取得

3. `Get items`
   - `送付元案件マスタ`
   - Filter Query 例: `送付元メール eq 'leader@example.co.jp'`

4. `Condition`
   - 件数 = 1 か

5. 分岐
   - 1件: `Update item` で 案件ID、現場ID、自動判定候補を設定
   - 0件: `確認待ち`
   - 複数件: `確認待ち` + 要確認理由を設定

### 実装メモ

- Filter Query は内部名ベースで書く
- 送付元メール列は小文字化して統一する

## 6. フロー F03_自動可否判定

### 起動

- F02 完了後

### アクション順

1. `Get item`
   - `確認キュー`

2. `Get item`
   - `送付元案件マスタ`

3. `Condition`
   - `自動返信可否 = はい`
   - `確認担当者` が存在
   - `マニュアルセットID`
   - `図面セットID`
   - `ExcelテンプレートID`
   がそろっているか

4. 分岐
   - そろっている: `キュー状態 = 自動実行待ち`
   - そろっていない: `キュー状態 = 確認待ち`

### 実装メモ

- 初期は厳しめに止める
- 止める理由は必ず `要確認理由` に書く

## 7. フロー F04_計算実行

### 起動

- `When an item is modified`
- 条件: `キュー状態 = 自動実行待ち` または `承認結果 = 実行可`

### アクション順

1. `Get item`
   - `確認キュー`

2. `Get item`
   - `送付元案件マスタ`

3. `Get file content`
   - `計算テンプレート` の Excel 正本または複製元を取得

4. `Copy file`
   - 実行用ブックを案件単位で複製

5. `Run script` (Excel Online (Business))
   - スクリプト例: `setInputAndCalc`
   - 入力: 機種、積載、停止階、昇降行程、案件ID

6. `Run script`
   - スクリプト例: `readOutput`
   - 出力: ブラケット個数、計算実行日時、使用セル値

7. `Update item`
   - `確認キュー` に計算結果を記録
   - `キュー状態 = 返信待ち`

### 実装メモ

- Excel 競合回避のため `Concurrency Control = Off` を推奨
- 1 日 24 件程度なら直列でも十分
- Office Scripts の `Run script` は 1 ユーザー 1,600 回 / 日の制限があるため、1 件 2 回程度なら余裕がある

## 8. フロー F05_帳票生成

### 起動

- `キュー状態 = 返信待ち`

### アクション順

1. `Get item`
   - `確認キュー`

2. `Get item`
   - `送付元案件マスタ`

3. `Get items`
   - `資料マスタ`
   - 案件条件、機種条件、積載条件などで対象を抽出

4. `Select`
   - 添付候補一覧を整形

5. `Create CSV table` または `Populate a Microsoft Word template` 相当の代替構成
   - 初期は Excel 結果シートを結果帳票とみなす方が低コスト

6. `Create file`
   - `返信結果` へ保存

### 実装メモ

- Premium を避けるなら、結果帳票は Excel か既成テンプレートを採用する
- 動的 Word 組版は次段階に回す

## 9. フロー F06_返信送信

### 起動

- F05 完了後

### アクション順

1. `Get item`
   - `確認キュー`

2. `Get files (properties only)`
   - `返信結果` と `資料マスタ` から添付対象を列挙

3. `Get file content`
   - 添付ファイルを取得

4. `Send an email from a shared mailbox (V2)`
   - To: 送付元メール
   - Subject: 固定テンプレート
   - Body: 返信テンプレート
   - Attachments: 結果帳票 + 必要資料

5. `Update item`
   - `確認キュー.キュー状態 = 完了`
   - `返信メール送信日時`

6. `Update file properties`
   - `返信結果.送信結果 = 送信済`

### 実装メモ

- 返信文には「正式指示値であること」「適用版」「問い合わせ先」を入れる
- 添付順序は固定する

## 10. フロー F07_失敗通知

### 起動

- Scope の `Configure run after` で失敗を捕捉

### アクション順

1. `Compose`
   - エラー要約作成

2. `Send an email (V2)`
   - 運用担当グループへ通知

3. `Update item`
   - `確認キュー.キュー状態 = 失敗`
   - `要確認理由 = 失敗内容`

## 11. 推奨 Office Scripts 一覧

| スクリプト名 | 役割 |
| --- | --- |
| `setInputAndCalc` | 入力セルへ値設定し再計算する |
| `readOutput` | 出力セルから結果を読む |
| `clearWorkbookState` | 必要なら実行後に状態を初期化する |

## 12. 実装時の注意

1. `Run script` の 120 秒同期タイムアウトを超えないようにする
2. パラメータは必要最小限にする
3. Flow 所有者を個人にしない
4. SharePoint リスト内部名を固定する
5. 本番用と検証用の共有メールボックスを分ける

## 13. PoC でまず作るべき最小構成

1. F01_メール受付
2. F02_案件特定
3. F04_計算実行
4. F06_返信送信

F05 の帳票生成は最初は Excel 出力をそのまま帳票扱いし、セクション選択型の高度化は次段階とする。
