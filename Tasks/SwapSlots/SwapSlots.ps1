[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try{

	# Get inputs.
    $ConnectedServiceNameSelector = Get-VstsInput -Name ConnectedServiceNameSelector -Require
    $ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName
    $ConnectedServiceNameARM = Get-VstsInput -Name ConnectedServiceNameARM
    $WebAppName = Get-VstsInput -Name WebAppName
    $WebAppNameARM = Get-VstsInput -Name WebAppNameARM
    $SourceSlot = Get-VstsInput -Name SourceSlot -Require
    $DestinationSlot = Get-VstsInput -Name DestinationSlot -Require
    $WebAppUri = Get-VstsInput -Name WebAppUri

	# Initialize Azure.
	Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
	Initialize-Azure

	# Import the loc strings.
	Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json

    if ($ConnectedServiceNameSelector -eq "ConnectedServiceNameARM")
    {
        $ConnectedServiceName = $ConnectedServiceNameARM
        $WebAppName = $WebAppNameARM
    }

    if ([string]::IsNullOrEmpty($WebAppName))
    {
		Throw (Get-VstsLocString -Key "Invalidwebappprovided")
	}

	# Load all dependent files for execution
	. $PSScriptRoot/AzureUtility.ps1

	# Importing required version of azure cmdlets according to azureps installed on machine
	$azureUtility = Get-AzureUtility

	Write-Verbose  "Loading $azureUtility"
	. $PSScriptRoot/$azureUtility -Force

    $webAppDetails = Get-AzureRMWebAppDetails -webAppName $WebAppName

    $resourceGroupName = Get-WebAppRGName -webAppName $WebAppName
    $parametersObject = @{targetSlot  = "$DestinationSlot"}
    Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Web/sites/slots -ResourceName "$WebAppName/$SourceSlot" -Action slotsswap -Parameters $parametersObject -ApiVersion 2015-07-01

    $resourceGroupName = Get-WebAppRGName -webAppName $WebAppName
    $deployToSlotFlag = $true
    if ($DestinationSlot -eq "production")
    {
        $deployToSlotFlag = $false
    }

    # Get azure webapp hosted url
    $azureWebsitePublishURL = Get-AzureRMWebAppPublishUrl -webAppName $WebAppName -deployToSlotFlag $deployToSlotFlag `
                                                                            -resourceGroupName $resourceGroupName -slotName $DestinationSlot

    # Publish azure webApp url
    Write-Host (Get-VstsLocString -Key "WebappslotsuccessfullyswappedatUrl0" -ArgumentList $azureWebsitePublishURL)

    # Set ouput vairable with azureWebsitePublishUrl
    if (-not [string]::IsNullOrEmpty($WebAppUri))
    {
        if ([string]::IsNullOrEmpty($azureWebsitePublishURL))
        {
            Throw (Get-VstsLocString -Key "Unabletoretrievewebapppublishurlforwebapp0" -ArgumentList $webAppName)
        }

        Set-VstsTaskVariable -Name $WebAppUri -Value $azureWebsitePublishURL
    }

	Write-Verbose "Completed Azure Web App Slots Swapping Task"

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
