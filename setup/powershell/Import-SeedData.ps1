#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$ConfigPath = "setup/config/developer-sandbox.example.json"
)

. "$PSScriptRoot\Common.ps1"

Assert-PowerShellVersion
Assert-ModuleInstalled -Name "PnP.PowerShell"

$config = Get-SetupConfig -Path $ConfigPath
Connect-DeveloperPnPOnline -Config $config -Url $config.environment.siteUrl

function Upsert-ListItemFromCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ListTitle,
        [Parameter(Mandatory = $true)]
        [string]$CsvPath,
        [Parameter(Mandatory = $true)]
        [string]$KeyField
    )

    $resolvedCsvPath = Resolve-RepositoryPath -Path $CsvPath
    if (-not (Test-Path -LiteralPath $resolvedCsvPath)) {
        throw "CSV ファイルが見つかりません: $resolvedCsvPath"
    }

    $rows = Import-Csv -LiteralPath $resolvedCsvPath
    foreach ($row in $rows) {
        $keyValue = $row.$KeyField
        if ([string]::IsNullOrWhiteSpace($keyValue)) {
            throw "CSV のキー列 '$KeyField' が空です: $resolvedCsvPath"
        }

        $existingItem = Get-PnPListItem -List $ListTitle -PageSize 200 |
            Where-Object { $_.FieldValues[$KeyField] -eq $keyValue } |
            Select-Object -First 1

        $values = Convert-RowToPnPValues -Row $row
        if ($existingItem) {
            Set-PnPListItem -List $ListTitle -Identity $existingItem.Id -Values $values | Out-Null
            continue
        }

        Add-PnPListItem -List $ListTitle -Values $values | Out-Null
    }
}

Write-Step "送付元許可リストへサンプルデータを投入します"
Upsert-ListItemFromCsv `
    -ListTitle "送付元許可リスト" `
    -CsvPath $config.paths.allowedSendersCsv `
    -KeyField "SenderEmail"

Write-Step "資料マスタへサンプルデータを投入します"
Upsert-ListItemFromCsv `
    -ListTitle "資料マスタ" `
    -CsvPath $config.paths.materialsCsv `
    -KeyField "MaterialId"

Write-Step "サンプルデータ投入が完了しました。"
