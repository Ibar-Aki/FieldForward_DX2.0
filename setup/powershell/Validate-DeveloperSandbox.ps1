#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$ConfigPath = "setup/config/developer-sandbox.example.json",
    [switch]$SkipMailboxCheck
)

. "$PSScriptRoot\Common.ps1"

Assert-PowerShellVersion
$config = Get-SetupConfig -Path $ConfigPath

$results = [System.Collections.Generic.List[object]]::new()

Assert-ModuleInstalled -Name "PnP.PowerShell"
Connect-DeveloperPnPOnline -Config $config -Url $config.environment.siteUrl

foreach ($listTitle in @("受付原本", "送付元許可リスト", "資料マスタ", "確認キュー", "返信結果", "計算テンプレート")) {
    $list = Get-PnPList -Identity $listTitle -ErrorAction SilentlyContinue
    $results.Add([pscustomobject]@{
            Check  = "SharePoint: $listTitle"
            Status = if ($list) { "OK" } else { "NG" }
            Detail = if ($list) { "存在します" } else { "見つかりません" }
        })
}

$allowedSenderCount = (Get-PnPListItem -List "送付元許可リスト" -PageSize 200 | Measure-Object).Count
$materialCount = (Get-PnPListItem -List "資料マスタ" -PageSize 200 | Measure-Object).Count

$results.Add([pscustomobject]@{
        Check  = "SeedData: 送付元許可リスト"
        Status = if ($allowedSenderCount -gt 0) { "OK" } else { "NG" }
        Detail = "$allowedSenderCount 件"
    })

$results.Add([pscustomobject]@{
        Check  = "SeedData: 資料マスタ"
        Status = if ($materialCount -gt 0) { "OK" } else { "NG" }
        Detail = "$materialCount 件"
    })

if (-not $SkipMailboxCheck) {
    Assert-ModuleInstalled -Name "ExchangeOnlineManagement"
    Import-Module ExchangeOnlineManagement
    Connect-ExchangeOnline -UserPrincipalName $config.tenant.adminUpn -ShowBanner:$false | Out-Null
    try {
        $mailbox = Get-EXOMailbox -Identity $config.mailbox.primarySmtpAddress -ErrorAction SilentlyContinue
        $results.Add([pscustomobject]@{
                Check  = "Exchange: Shared mailbox"
                Status = if ($mailbox) { "OK" } else { "NG" }
                Detail = if ($mailbox) { $config.mailbox.primarySmtpAddress } else { "共有メールボックスが見つかりません" }
            })
    }
    finally {
        Disconnect-ExchangeOnline -Confirm:$false
    }
}

$results | Format-Table -AutoSize

if ($results.Status -contains "NG") {
    throw "開発用セットアップの検証で NG が見つかりました。"
}
