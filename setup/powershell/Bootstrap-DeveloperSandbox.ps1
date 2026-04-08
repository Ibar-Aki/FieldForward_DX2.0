#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$ConfigPath = "setup/config/developer-sandbox.example.json",
    [switch]$SkipMailbox,
    [switch]$SkipSeedData,
    [switch]$SkipValidation
)

. "$PSScriptRoot\Common.ps1"

Assert-PowerShellVersion

Write-Step "前提モジュールを確認します"
& "$PSScriptRoot\Install-Prerequisites.ps1"

if (-not $SkipMailbox) {
    Write-Step "共有メールボックスをセットアップします"
    & "$PSScriptRoot\Initialize-SharedMailbox.ps1" -ConfigPath $ConfigPath
}

Write-Step "SharePoint の開発用環境をセットアップします"
& "$PSScriptRoot\Initialize-SharePoint.ps1" -ConfigPath $ConfigPath

if (-not $SkipSeedData) {
    Write-Step "サンプルデータを投入します"
    & "$PSScriptRoot\Import-SeedData.ps1" -ConfigPath $ConfigPath
}

if (-not $SkipValidation) {
    Write-Step "セットアップ結果を検証します"
    & "$PSScriptRoot\Validate-DeveloperSandbox.ps1" -ConfigPath $ConfigPath -SkipMailboxCheck:$SkipMailbox
}

Write-Step "少人数開発用セットアップが完了しました。次は Office Scripts の登録と Power Automate フロー作成です。"
