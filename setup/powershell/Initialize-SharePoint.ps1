#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$ConfigPath = "setup/config/developer-sandbox.example.json"
)

. "$PSScriptRoot\Common.ps1"

Assert-PowerShellVersion
Assert-ModuleInstalled -Name "PnP.PowerShell"

$config = Get-SetupConfig -Path $ConfigPath

function Ensure-PnPList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Template
    )

    $existing = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Step ("SharePoint リスト/ライブラリは既に存在します: {0}" -f $Title)
        return
    }

    Write-Step ("SharePoint リスト/ライブラリを作成します: {0}" -f $Title)
    New-PnPList -Title $Title -Template $Template -OnQuickLaunch:$true | Out-Null
}

function Ensure-PnPFieldFromXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ListTitle,
        [Parameter(Mandatory = $true)]
        [string]$InternalName,
        [Parameter(Mandatory = $true)]
        [string]$FieldXml
    )

    $existing = Get-PnPField -List $ListTitle -Identity $InternalName -ErrorAction SilentlyContinue
    if ($existing) {
        return
    }

    Add-PnPFieldFromXml -List $ListTitle -FieldXml $FieldXml | Out-Null
}

Write-Step "SharePoint 管理サイトへ接続します"
Connect-DeveloperPnPOnline -Config $config -Url $config.tenant.sharePointAdminUrl

$site = Get-PnPTenantSite -Identity $config.environment.siteUrl -ErrorAction SilentlyContinue
if (-not $site) {
    Write-Step "開発用 SharePoint サイトを作成します"
    New-PnPSite `
        -Type TeamSiteWithoutMicrosoft365Group `
        -Title $config.environment.siteTitle `
        -Url $config.environment.siteUrl `
        -Owner $config.environment.owner `
        -Lcid ([uint32]$config.environment.localeId) `
        -Wait | Out-Null
}
else {
    Write-Step "開発用 SharePoint サイトは既に存在します"
}

Write-Step "開発用 SharePoint サイトへ接続します"
Connect-DeveloperPnPOnline -Config $config -Url $config.environment.siteUrl

Ensure-PnPList -Title "受付原本" -Template "DocumentLibrary"
Ensure-PnPList -Title "送付元許可リスト" -Template "GenericList"
Ensure-PnPList -Title "資料マスタ" -Template "GenericList"
Ensure-PnPList -Title "確認キュー" -Template "GenericList"
Ensure-PnPList -Title "返信結果" -Template "DocumentLibrary"
Ensure-PnPList -Title "計算テンプレート" -Template "DocumentLibrary"

$fields = @(
    @{
        List = "受付原本"
        Name = "SourceId"
        Xml  = "<Field Type='Text' Name='SourceId' StaticName='SourceId' DisplayName='原本ID' Group='FieldForward' Required='TRUE' Indexed='TRUE' />"
    },
    @{
        List = "受付原本"
        Name = "EmailReceivedAt"
        Xml  = "<Field Type='DateTime' Name='EmailReceivedAt' StaticName='EmailReceivedAt' DisplayName='メール受信日時' Group='FieldForward' Required='TRUE' Format='DateTime' FriendlyDisplayFormat='Disabled' />"
    },
    @{
        List = "受付原本"
        Name = "SenderEmail"
        Xml  = "<Field Type='Text' Name='SenderEmail' StaticName='SenderEmail' DisplayName='送信元メール' Group='FieldForward' Required='TRUE' Indexed='TRUE' />"
    },
    @{
        List = "受付原本"
        Name = "MailSubject"
        Xml  = "<Field Type='Text' Name='MailSubject' StaticName='MailSubject' DisplayName='件名' Group='FieldForward' Required='TRUE' />"
    },
    @{
        List = "受付原本"
        Name = "AttachmentFileName"
        Xml  = "<Field Type='Text' Name='AttachmentFileName' StaticName='AttachmentFileName' DisplayName='添付ファイル名' Group='FieldForward' Required='TRUE' />"
    },
    @{
        List = "受付原本"
        Name = "ProcessingStatus"
        Xml  = "<Field Type='Choice' Name='ProcessingStatus' StaticName='ProcessingStatus' DisplayName='処理状態' Group='FieldForward' Required='TRUE'><CHOICES><CHOICE>受付済</CHOICE><CHOICE>解析中</CHOICE><CHOICE>確認待ち</CHOICE><CHOICE>完了</CHOICE><CHOICE>失敗</CHOICE></CHOICES><Default>受付済</Default></Field>"
    },
    @{
        List = "受付原本"
        Name = "RetryCount"
        Xml  = "<Field Type='Number' Name='RetryCount' StaticName='RetryCount' DisplayName='再処理回数' Group='FieldForward' Required='TRUE' Decimals='0'><Default>0</Default></Field>"
    },
    @{
        List = "送付元許可リスト"
        Name = "SenderEmail"
        Xml  = "<Field Type='Text' Name='SenderEmail' StaticName='SenderEmail' DisplayName='送付元メール' Group='FieldForward' Required='TRUE' Indexed='TRUE' EnforceUniqueValues='TRUE' />"
    },
    @{
        List = "送付元許可リスト"
        Name = "AffiliationType"
        Xml  = "<Field Type='Choice' Name='AffiliationType' StaticName='AffiliationType' DisplayName='所属区分' Group='FieldForward'><CHOICES><CHOICE>施工会社</CHOICE><CHOICE>協力会社</CHOICE><CHOICE>共用アドレス</CHOICE><CHOICE>開発検証</CHOICE></CHOICES></Field>"
    },
    @{
        List = "送付元許可リスト"
        Name = "IsAccepted"
        Xml  = "<Field Type='Boolean' Name='IsAccepted' StaticName='IsAccepted' DisplayName='受付許可' Group='FieldForward'><Default>1</Default></Field>"
    },
    @{
        List = "送付元許可リスト"
        Name = "AllowAutoReply"
        Xml  = "<Field Type='Boolean' Name='AllowAutoReply' StaticName='AllowAutoReply' DisplayName='自動返信可否' Group='FieldForward'><Default>1</Default></Field>"
    },
    @{
        List = "送付元許可リスト"
        Name = "AllowDelegateSend"
        Xml  = "<Field Type='Boolean' Name='AllowDelegateSend' StaticName='AllowDelegateSend' DisplayName='代理送信許可' Group='FieldForward'><Default>1</Default></Field>"
    },
    @{
        List = "送付元許可リスト"
        Name = "AllowForwardedMail"
        Xml  = "<Field Type='Boolean' Name='AllowForwardedMail' StaticName='AllowForwardedMail' DisplayName='転送メール許可' Group='FieldForward'><Default>1</Default></Field>"
    },
    @{
        List = "送付元許可リスト"
        Name = "DefaultProjectCandidate"
        Xml  = "<Field Type='Text' Name='DefaultProjectCandidate' StaticName='DefaultProjectCandidate' DisplayName='既定案件候補' Group='FieldForward' />"
    },
    @{
        List = "送付元許可リスト"
        Name = "ReviewAssignee"
        Xml  = "<Field Type='User' Name='ReviewAssignee' StaticName='ReviewAssignee' DisplayName='確認担当者' Group='FieldForward' UserSelectionMode='PeopleOnly' />"
    },
    @{
        List = "送付元許可リスト"
        Name = "EffectiveStartDate"
        Xml  = "<Field Type='DateTime' Name='EffectiveStartDate' StaticName='EffectiveStartDate' DisplayName='有効開始日' Group='FieldForward' Format='DateOnly' />"
    },
    @{
        List = "送付元許可リスト"
        Name = "EffectiveEndDate"
        Xml  = "<Field Type='DateTime' Name='EffectiveEndDate' StaticName='EffectiveEndDate' DisplayName='有効終了日' Group='FieldForward' Format='DateOnly' />"
    },
    @{
        List = "資料マスタ"
        Name = "MaterialId"
        Xml  = "<Field Type='Text' Name='MaterialId' StaticName='MaterialId' DisplayName='資料ID' Group='FieldForward' Required='TRUE' Indexed='TRUE' EnforceUniqueValues='TRUE' />"
    },
    @{
        List = "資料マスタ"
        Name = "MaterialType"
        Xml  = "<Field Type='Choice' Name='MaterialType' StaticName='MaterialType' DisplayName='資料種別' Group='FieldForward'><CHOICES><CHOICE>共通マニュアル</CHOICE><CHOICE>共通図面</CHOICE><CHOICE>現場専用図面</CHOICE><CHOICE>結果帳票テンプレート</CHOICE></CHOICES></Field>"
    },
    @{
        List = "資料マスタ"
        Name = "VersionLabel"
        Xml  = "<Field Type='Text' Name='VersionLabel' StaticName='VersionLabel' DisplayName='版' Group='FieldForward' Required='TRUE' />"
    },
    @{
        List = "資料マスタ"
        Name = "ApprovalStatus"
        Xml  = "<Field Type='Choice' Name='ApprovalStatus' StaticName='ApprovalStatus' DisplayName='承認状態' Group='FieldForward'><CHOICES><CHOICE>承認済み</CHOICE><CHOICE>確認中</CHOICE><CHOICE>ドラフト</CHOICE></CHOICES><Default>承認済み</Default></Field>"
    },
    @{
        List = "資料マスタ"
        Name = "IsReturnTarget"
        Xml  = "<Field Type='Boolean' Name='IsReturnTarget' StaticName='IsReturnTarget' DisplayName='返却対象フラグ' Group='FieldForward'><Default>1</Default></Field>"
    },
    @{
        List = "資料マスタ"
        Name = "ConditionKey"
        Xml  = "<Field Type='Text' Name='ConditionKey' StaticName='ConditionKey' DisplayName='条件キー' Group='FieldForward' />"
    },
    @{
        List = "資料マスタ"
        Name = "SourceUrl"
        Xml  = "<Field Type='Text' Name='SourceUrl' StaticName='SourceUrl' DisplayName='格納先URL' Group='FieldForward' />"
    },
    @{
        List = "資料マスタ"
        Name = "NotesEx"
        Xml  = "<Field Type='Note' Name='NotesEx' StaticName='NotesEx' DisplayName='備考' Group='FieldForward' NumLines='6' RichText='FALSE' />"
    },
    @{
        List = "確認キュー"
        Name = "QueueId"
        Xml  = "<Field Type='Text' Name='QueueId' StaticName='QueueId' DisplayName='キューID' Group='FieldForward' Required='TRUE' Indexed='TRUE' EnforceUniqueValues='TRUE' />"
    },
    @{
        List = "確認キュー"
        Name = "SourceId"
        Xml  = "<Field Type='Text' Name='SourceId' StaticName='SourceId' DisplayName='原本ID' Group='FieldForward' Required='TRUE' Indexed='TRUE' />"
    },
    @{
        List = "確認キュー"
        Name = "ProjectId"
        Xml  = "<Field Type='Text' Name='ProjectId' StaticName='ProjectId' DisplayName='案件ID' Group='FieldForward' />"
    },
    @{
        List = "確認キュー"
        Name = "QueueStatus"
        Xml  = "<Field Type='Choice' Name='QueueStatus' StaticName='QueueStatus' DisplayName='キュー状態' Group='FieldForward' Required='TRUE'><CHOICES><CHOICE>新規</CHOICE><CHOICE>自動実行待ち</CHOICE><CHOICE>確認待ち</CHOICE><CHOICE>確認中</CHOICE><CHOICE>返信待ち</CHOICE><CHOICE>完了</CHOICE><CHOICE>失敗</CHOICE></CHOICES><Default>新規</Default></Field>"
    },
    @{
        List = "確認キュー"
        Name = "AutoDecision"
        Xml  = "<Field Type='Choice' Name='AutoDecision' StaticName='AutoDecision' DisplayName='自動判定結果' Group='FieldForward'><CHOICES><CHOICE>自動可</CHOICE><CHOICE>確認要</CHOICE><CHOICE>停止</CHOICE></CHOICES><Default>確認要</Default></Field>"
    },
    @{
        List = "確認キュー"
        Name = "ReviewReason"
        Xml  = "<Field Type='Note' Name='ReviewReason' StaticName='ReviewReason' DisplayName='要確認理由' Group='FieldForward' NumLines='6' RichText='FALSE' />"
    },
    @{
        List = "確認キュー"
        Name = "OverrideMachineType"
        Xml  = "<Field Type='Text' Name='OverrideMachineType' StaticName='OverrideMachineType' DisplayName='補正_機種' Group='FieldForward' />"
    },
    @{
        List = "確認キュー"
        Name = "OverrideLoadCapacity"
        Xml  = "<Field Type='Number' Name='OverrideLoadCapacity' StaticName='OverrideLoadCapacity' DisplayName='補正_積載' Group='FieldForward' Decimals='0' />"
    },
    @{
        List = "確認キュー"
        Name = "OverrideStopCount"
        Xml  = "<Field Type='Number' Name='OverrideStopCount' StaticName='OverrideStopCount' DisplayName='補正_停止階' Group='FieldForward' Decimals='0' />"
    },
    @{
        List = "確認キュー"
        Name = "OverrideTravelHeight"
        Xml  = "<Field Type='Number' Name='OverrideTravelHeight' StaticName='OverrideTravelHeight' DisplayName='補正_昇降行程' Group='FieldForward' Decimals='2' />"
    },
    @{
        List = "確認キュー"
        Name = "ApprovalResult"
        Xml  = "<Field Type='Choice' Name='ApprovalResult' StaticName='ApprovalResult' DisplayName='承認結果' Group='FieldForward'><CHOICES><CHOICE>実行可</CHOICE><CHOICE>差戻し</CHOICE><CHOICE>却下</CHOICE></CHOICES></Field>"
    },
    @{
        List = "確認キュー"
        Name = "ReplySentAt"
        Xml  = "<Field Type='DateTime' Name='ReplySentAt' StaticName='ReplySentAt' DisplayName='返信メール送信日時' Group='FieldForward' Format='DateTime' FriendlyDisplayFormat='Disabled' />"
    },
    @{
        List = "返信結果"
        Name = "ResultId"
        Xml  = "<Field Type='Text' Name='ResultId' StaticName='ResultId' DisplayName='返信ID' Group='FieldForward' Required='TRUE' Indexed='TRUE' />"
    },
    @{
        List = "返信結果"
        Name = "QueueId"
        Xml  = "<Field Type='Text' Name='QueueId' StaticName='QueueId' DisplayName='キューID' Group='FieldForward' Required='TRUE' Indexed='TRUE' />"
    },
    @{
        List = "返信結果"
        Name = "SentAt"
        Xml  = "<Field Type='DateTime' Name='SentAt' StaticName='SentAt' DisplayName='送信日時' Group='FieldForward' Format='DateTime' FriendlyDisplayFormat='Disabled' />"
    },
    @{
        List = "返信結果"
        Name = "RuleVersion"
        Xml  = "<Field Type='Text' Name='RuleVersion' StaticName='RuleVersion' DisplayName='適用ルール版' Group='FieldForward' />"
    },
    @{
        List = "返信結果"
        Name = "MaterialVersionSnapshot"
        Xml  = "<Field Type='Note' Name='MaterialVersionSnapshot' StaticName='MaterialVersionSnapshot' DisplayName='資料版スナップショット' Group='FieldForward' NumLines='6' RichText='FALSE' />"
    },
    @{
        List = "計算テンプレート"
        Name = "TemplateId"
        Xml  = "<Field Type='Text' Name='TemplateId' StaticName='TemplateId' DisplayName='テンプレートID' Group='FieldForward' Required='TRUE' Indexed='TRUE' />"
    },
    @{
        List = "計算テンプレート"
        Name = "TemplateType"
        Xml  = "<Field Type='Choice' Name='TemplateType' StaticName='TemplateType' DisplayName='テンプレート種別' Group='FieldForward'><CHOICES><CHOICE>計算正本</CHOICE><CHOICE>検証用複製元</CHOICE></CHOICES><Default>計算正本</Default></Field>"
    },
    @{
        List = "計算テンプレート"
        Name = "InputMappingVersion"
        Xml  = "<Field Type='Text' Name='InputMappingVersion' StaticName='InputMappingVersion' DisplayName='入力マッピング版' Group='FieldForward' />"
    },
    @{
        List = "計算テンプレート"
        Name = "OutputMappingVersion"
        Xml  = "<Field Type='Text' Name='OutputMappingVersion' StaticName='OutputMappingVersion' DisplayName='出力マッピング版' Group='FieldForward' />"
    },
    @{
        List = "計算テンプレート"
        Name = "IsActive"
        Xml  = "<Field Type='Boolean' Name='IsActive' StaticName='IsActive' DisplayName='有効フラグ' Group='FieldForward'><Default>1</Default></Field>"
    }
)

foreach ($field in $fields) {
    Ensure-PnPFieldFromXml -ListTitle $field.List -InternalName $field.Name -FieldXml $field.Xml
}

Write-Step "SharePoint の開発用セットアップが完了しました。"
