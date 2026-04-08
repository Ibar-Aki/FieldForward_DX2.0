Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

$script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ("==> {0}" -f $Message) -ForegroundColor Cyan
}

function Resolve-RepositoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot $Path))
}

function Get-SetupConfig {
    param(
        [string]$Path = "setup/config/developer-sandbox.example.json"
    )

    $fullPath = Resolve-RepositoryPath -Path $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "設定ファイルが見つかりません: $fullPath"
    }

    $config = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json -AsHashtable
    $config["__ConfigPath"] = $fullPath
    return $config
}

function Assert-PowerShellVersion {
    param(
        [Version]$MinimumVersion = [Version]"7.4.6"
    )

    if ($PSVersionTable.PSVersion -lt $MinimumVersion) {
        throw "PowerShell $MinimumVersion 以上が必要です。現在: $($PSVersionTable.PSVersion)"
    }
}

function Assert-ModuleInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "PowerShell モジュール '$Name' が見つかりません。Install-Prerequisites.ps1 を先に実行してください。"
    }
}

function Get-UniqueUserList {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $users = @()
    foreach ($groupName in @("operators", "developers", "technicalOwners")) {
        if ($Config.groups.ContainsKey($groupName)) {
            $users += @($Config.groups[$groupName])
        }
    }

    return $users | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
}

function Connect-DeveloperPnPOnline {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    Assert-ModuleInstalled -Name "PnP.PowerShell"
    if ([string]::IsNullOrWhiteSpace($Config.tenant.pnpClientId)) {
        throw "tenant.pnpClientId が未設定です。PnP PowerShell 用の Entra ID アプリの Client ID を設定してください。"
    }

    Connect-PnPOnline -Url $Url -ClientId $Config.tenant.pnpClientId -Interactive -PersistLogin | Out-Null
}

function Convert-CsvValue {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value -or $Value -eq "") {
        return $null
    }

    if ($Value -match "^(true|false)$") {
        return [System.Boolean]::Parse($Value)
    }

    if ($Value -match "^-?\d+$") {
        return [int]$Value
    }

    if ($Value -match "^-?\d+\.\d+$") {
        return [double]$Value
    }

    $dateValue = $null
    if ([datetime]::TryParse($Value, [ref]$dateValue)) {
        return $dateValue
    }

    return $Value
}

function Convert-RowToPnPValues {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Row
    )

    $values = @{}
    foreach ($property in $Row.PSObject.Properties) {
        $converted = Convert-CsvValue -Value ([string]$property.Value)
        if ($null -ne $converted) {
            $values[$property.Name] = $converted
        }
    }

    return $values
}
