# setup

作成日: 2026-04-04 09:35 JST
作成者: Codex (GPT-5)
更新日: 2026-04-04

## 概要

このディレクトリには、FieldForward DX2.0 を少人数の開発者 1〜2 名で試すためのセットアップ資材を置く。
目的は、共有メールボックス、SharePoint、サンプルマスタ、Office Scripts を短時間で用意し、Power Automate の実装にすぐ着手できる状態まで寄せることである。

## 含まれるもの

- `config/developer-sandbox.example.json`
  開発用環境の設定テンプレート
- `powershell/Install-Prerequisites.ps1`
  必要 PowerShell モジュールのインストール
- `powershell/Initialize-SharedMailbox.ps1`
  開発用共有メールボックスの作成と権限付与
- `powershell/Initialize-SharePoint.ps1`
  SharePoint サイト、ライブラリ、リスト、主要列の作成
- `powershell/Import-SeedData.ps1`
  送付元許可リストと資料マスタへのサンプル投入
- `powershell/Validate-DeveloperSandbox.ps1`
  セットアップ後の検証
- `powershell/Bootstrap-DeveloperSandbox.ps1`
  少人数開発向けの一括セットアップ
- `office-scripts/*.ts`
  Excel 計算テンプレートへ登録する Office Scripts
- `samples/*.csv`
  最低限のサンプルデータ

## 使い方

1. `config/developer-sandbox.example.json` を複製し、テナント固有値へ書き換える
2. PowerShell 7.4.6 以上で `powershell/Bootstrap-DeveloperSandbox.ps1` を実行する
3. `office-scripts/` の 3 本を Excel Online の自動化タブへ登録する
4. `docs/03_final/10_少人数開発者向けセットアップガイド_最終版.md` の手順に沿って Power Automate フローを作成する

## 想定する残作業

このセットアップで完了するのは、共有メールボックス、SharePoint の保存先、サンプルマスタ、Excel 自動化の土台までである。
次の作業は M365 テナント上で引き続き必要になる。

- Power Automate `F01` から `F07` の作成
- Excel 正本の入出力セル確定
- 実際の結果帳票テンプレート差し替え
- 返信文面の最終化

## 実行例

```powershell
pwsh -File .\setup\powershell\Bootstrap-DeveloperSandbox.ps1 `
  -ConfigPath .\setup\config\developer-sandbox.example.json
```

共有メールボックスを先に手動で用意している場合は、次のようにメールボックス作成を飛ばせる。

```powershell
pwsh -File .\setup\powershell\Bootstrap-DeveloperSandbox.ps1 `
  -ConfigPath .\setup\config\developer-sandbox.example.json `
  -SkipMailbox
```
