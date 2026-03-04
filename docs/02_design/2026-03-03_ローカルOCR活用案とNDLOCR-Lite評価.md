# ローカルOCR活用案とNDLOCR-Lite評価

作成日時: 2026-03-03 23:33:04 +09:00
作成者: Codex + GPT-5

## 1. 結論

- `ローカルOCR / 自作OCRパイプライン` を使うことで、AI Builder のようなページ従量課金を下げる、または避けることは可能である
- ただし、今回の帳票が `現代の業務帳票 PDF`、`結合セルあり`、`項目配置ゆれあり` という前提なら、`NDLOCR-Lite` は主力候補にはしにくい
- 低コストで進めるなら、現実的な候補は `OCRmyPDF + Tesseract` または `PaddleOCR / PP-Structure` をローカル実行し、Power Automate から社内 API を呼ぶ構成である

## 2. なぜ NDLOCR-Lite が本命になりにくいか

NDLOCR-Lite は国立国会図書館が公開した `古典籍 OCR-Lite` であり、公開情報でも対象は `江戸期以前の和古書、清代以前の漢籍` とされている。GPU 不要で軽量という利点はあるが、対象領域が今回の `現代の仕様票 PDF` と大きく異なる。

### この案件との相性

| 観点 | 評価 |
| --- | --- |
| 日本語 OCR | 使える可能性はある |
| 現代業務帳票との相性 | 低い |
| 表構造認識 | 主目的ではない |
| 結合セル、項目抽出 | 主用途とずれる |
| 導入コスト | 低い |
| 業務適合性 | 低〜中 |

### 判断

- 試験的に比較対象に置くことはできる
- ただし本命 OCR として設計を組むのは避けた方がよい

## 3. ローカルOCRで安くする基本方針

### 方向性

- `M365 はオーケストレーション`
- `OCR は社内ローカル実行`
- `既存 Excel は計算エンジン`

と役割分担する

### 処理の流れ

1. 共有メールボックスでメール受信
2. Power Automate が PDF を SharePoint または社内サーバへ渡す
3. 社内 OCR サービスが PDF を処理
4. OCR 結果を JSON で返す
5. Power Automate が送付元マスタと OCR 結果を照合
6. 既存 Excel で計算
7. 現場向け帳票を返信

## 4. ローカルOCR候補

### 案L1: OCRmyPDF + Tesseract

#### 特徴

- PDF を OCR 付き PDF やテキスト化するのに向く
- Tesseract 単体は PDF を直接読めず、OCRmyPDF が PDF パイプラインを補う
- ローカル実行ならページ従量課金は不要

#### 向いている使い方

- 添付 PDF を searchable PDF 化する
- まず全文テキストを取って、送付元マスタやキーワードで補助判定する

#### 弱い点

- 表構造認識やレイアウト理解は強くない
- 項目抽出ロジックを別途自作する必要がある

### 案L2: PaddleOCR / PP-Structure

#### 特徴

- OCR だけでなく、レイアウト解析や表認識の機能がある
- PDF / 画像の文書理解に寄せやすい
- ローカル実行ならページ従量課金は不要

#### 向いている使い方

- 帳票のレイアウトゆれにある程度対応したい
- 表、タイトル、ブロック単位で項目候補を取りたい

#### 弱い点

- AI Builder より自前実装責任が増える
- モデル選定、前処理、後処理、評価設計が必要

### 案L3: NDLOCR-Lite

#### 特徴

- 軽量
- GPU なしでも動かせる

#### 向いている使い方

- 古典籍や縦書き資料など、公開想定に近い用途

#### 弱い点

- 今回の現代業務帳票との適合性が不透明
- 表構造認識と項目抽出用途に対して主戦力にしにくい

## 5. コスト比較の考え方

### AI Builder との違い

- AI Builder は `ページ従量課金`
- ローカルOCRは `初期構築 + サーバ運用 + 保守`

今回の `年6,000件` 規模では、AI Builder の年間追加費用は 5 ページ / 件仮定で約 `2,400ドル + Premium座席費` である。金額だけ見ると極端に高いわけではない。

つまり、ローカルOCRが安くなるかどうかは、

- 社内で保守できるか
- 精度改善コストを吸収できるか
- サーバ運用を既存基盤で吸収できるか

で決まる。

## 6. 年間コストのラフ比較

### 前提

- 年 6,000 件
- 5 ページ / 件
- ローカルサーバは既存の Windows または Linux VM を流用できると仮定
- 人件費は含めない

| 案 | 追加費用の主成分 | 年間追加費用の目安 |
| --- | --- | --- |
| AI Builder 案 | Credits + Premium | 約 2,580 〜 2,760 ドル |
| OCRmyPDF + Tesseract | サーバ、保守、電気代相当 | 0 〜 数百ドル相当 |
| PaddleOCR | サーバ、保守、場合によって GPU | 0 〜 1,500 ドル相当 |
| NDLOCR-Lite | サーバ、保守 | 0 〜 数百ドル相当 |

### 重要な注意

- 上表は `追加ライセンスやインフラの見えるコスト` であり、`精度改善の人件費` は含まない
- 実務では、ローカルOCRは `見える課金は安いが、見えない保守工数は増えやすい`

## 7. 推奨の考え方

### 低コスト重視

- まずは `案B + OCRなし or OCRmyPDF補助`

### 中期的に OCR を安く入れたい

- `PaddleOCR / PP-Structure` を比較検証候補にする

### NDLOCR-Lite の扱い

- 参考比較対象にはできる
- ただし本命候補にはしない

## 8. 実務的な提案

### 提案1

- PoC 第1段階は `送付元マスタ中心`
- OCR は使わないか、OCRmyPDF で検索可能 PDF 化だけ行う

### 提案2

- PoC 第2段階で `PaddleOCR / PP-Structure` を評価する
- AI Builder と同じ 4 項目で精度比較する

### 提案3

- NDLOCR-Lite は机上比較にとどめる
- 実帳票 20〜30 件で試し、明確に優位なら再検討する

## 9. 参考にした公式情報

- NDLラボでは、NDL古典籍OCR-Lite を `江戸期以前の和古書、清代以前の漢籍` 向け軽量 OCR と説明している  
  https://lab.ndl.go.jp/news/2024/2024-11-26/
- NDL古典籍OCR-Lite GitHub リポジトリ  
  https://github.com/ndl-lab/ndlkotenocr-lite
- Tesseract は OCR エンジンであり、PDF を直接入力できず、PDF OCR には OCRmyPDF などの併用が推奨される  
  https://tesseract-ocr.github.io/tessdoc/InputFormats.html
- OCRmyPDF は Tesseract、Ghostscript、qpdf を必要とし、プラグインで OCR エンジン差し替えも可能  
  https://ocrmypdf.readthedocs.io/en/v9.3.0/installation.html  
  https://ocrmypdf.readthedocs.io/en/v16.0.1post1/plugins.html
- PaddleOCR の PP-Structure はレイアウト解析、表認識、PDF / 画像文書理解を対象にしている  
  https://www.paddleocr.ai/main/en/version2.x/ppstructure/overview.html  
  https://www.paddleocr.ai/main/en/version2.x/ppocr/quick_start.html
