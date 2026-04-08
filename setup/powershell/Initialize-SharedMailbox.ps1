#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$ConfigPath = "setup/config/developer-sandbox.example.json"
)

. "$PSScriptRoot\Common.ps1"

Assert-PowerShellVersion
Assert-ModuleInstalled -Name "ExchangeOnlineManagement"

$config = Get-SetupConfig -Path $ConfigPath

Import-Module ExchangeOnlineManagement

Write-Step "Exchange Online へ接続します"
Connect-ExchangeOnline -UserPrincipalName $config.tenant.adminUpn -ShowBanner:$false | Out-Null

try {
    $mailboxAddress = $config.mailbox.primarySmtpAddress
    $existingMailbox = Get-EXOMailbox -Identity $mailboxAddress -ErrorAction SilentlyContinue

    if (-not $existingMailbox) {
        Write-Step "共有メールボックスを作成します"
        New-Mailbox -Shared `
            -Name $config.mailbox.displayName `
            -DisplayName $config.mailbox.displayName `
            -Alias $config.mailbox.alias `
            -PrimarySmtpAddress $mailboxAddress | Out-Null
    }
    else {
        Write-Step "共有メールボックスは既に存在します"
    }

    foreach ($user in (Get-UniqueUserList -Config $config)) {
        Write-Step ("共有メールボックスの FullAccess 権限を付与します: {0}" -f $user)
        try {
            Add-MailboxPermission `
                -Identity $mailboxAddress `
                -User $user `
                -AccessRights FullAccess `
                -InheritanceType All `
                -AutoMapping:$false `
                -Confirm:$false | Out-Null
        }
        catch {
            if ($_.Exception.Message -notmatch "already" -and $_.Exception.Message -notmatch "ACE") {
                throw
            }
        }
    }

    foreach ($user in @($config.groups.operators)) {
        Write-Step ("共有メールボックスの SendAs 権限を付与します: {0}" -f $user)
        try {
            Add-RecipientPermission `
                -Identity $mailboxAddress `
                -Trustee $user `
                -AccessRights SendAs `
                -Confirm:$false | Out-Null
        }
        catch {
            if ($_.Exception.Message -notmatch "already" -and $_.Exception.Message -notmatch "ACE") {
                throw
            }
        }
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false
}

Write-Step "共有メールボックスのセットアップが完了しました。"
