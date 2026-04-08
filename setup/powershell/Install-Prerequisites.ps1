#requires -Version 7.4
[CmdletBinding()]
param(
    [switch]$Force
)

. "$PSScriptRoot\Common.ps1"

Assert-PowerShellVersion

$modules = @(
    "PnP.PowerShell",
    "ExchangeOnlineManagement"
)

foreach ($moduleName in $modules) {
    $installedModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1

    if ($Force -or -not $installedModule) {
        Write-Step "PowerShell モジュールをインストールします: $moduleName"
        Install-Module -Name $moduleName -Scope CurrentUser -AllowClobber -Force
        continue
    }

    Write-Step ("PowerShell モジュールは既に利用可能です: {0} {1}" -f $moduleName, $installedModule.Version)
}

Write-Step "前提モジュールの確認が完了しました。"
