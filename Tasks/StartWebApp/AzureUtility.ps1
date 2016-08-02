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
