$ErrorActionPreference = 'Stop'

function Get-AzureUtility
{
    $currentVersion =  (Get-Module -Name AzureRM.profile).Version
    Write-Verbose  "Installed Azure PowerShell version: $currentVersion"

    $minimumAzureVersion = New-Object System.Version(0, 9, 9)
	
    $azureUtilityOldVersion = "AzureUtilityLTE9.8.ps1"
    $azureUtilityNewVersion = "AzureUtilityGTE1.0.ps1"
	
	
    if( $currentVersion -and $currentVersion -gt $minimumAzureVersion )
    {
	    $azureUtilityRequiredVersion = $azureUtilityNewVersion  
    }
    else
    {
	    $azureUtilityRequiredVersion = $azureUtilityOldVersion
    }
	
    Write-Verbose "Required AzureUtility: $azureUtilityRequiredVersion"
    return $azureUtilityRequiredVersion
}

function Get-AzureRMWebAppDetails
{
    param([String][Parameter(Mandatory=$true)] $webAppName)

    Write-Verbose "`t Getting azureRM WebApp:'$webAppName' details."
    $azureRMWebAppDetails = Get-AzureRMWebAppARM -Name $webAppName
    Write-Verbose "`t Got azureRM WebApp:'$webAppName' details."

    Write-Verbose ($azureRMWebAppDetails | Format-List | Out-String)
    return $azureRMWebAppDetails
}

function Get-AzureRMWebAppPublishUrl
{
    param([String][Parameter(Mandatory=$true)] $webAppName,
          [String][Parameter(Mandatory=$true)] $deployToSlotFlag,
          [String][Parameter(Mandatory=$false)] $resourceGroupName,
          [String][Parameter(Mandatory=$false)] $slotName)

    Write-Verbose "`t Getting azureRM WebApp Url for web app :'$webAppName'."
    $AzureRMWebAppPublishUrl = Get-AzureRMWebAppPublishUrlARM -webAppName $WebAppName -deployToSlotFlag $DeployToSlotFlag `
                         -resourceGroupName $ResourceGroupName -slotName $SlotName
    Write-Verbose "`t Got azureRM azureRM WebApp Url for web app :'$webAppName'."

    Write-Verbose ($AzureRMWebAppPublishUrl | Format-List | Out-String)
    return $AzureRMWebAppPublishUrl
}
