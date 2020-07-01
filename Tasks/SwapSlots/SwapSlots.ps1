[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {

    # Get inputs.
    $WebAppName = Get-VstsInput -Name WebAppName -Require
    $SourceSlot = Get-VstsInput -Name SourceSlot -Require
    $DestinationSlot = Get-VstsInput -Name DestinationSlot -Require
    $DestinationUrl = Get-VstsInput -Name DestinationUrl

    # Initialize Azure.
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Initialize-Azure

    # Import the loc strings.
    Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json

    $resourceGroupName = Get-WebAppResourceGroupName -webAppName $WebAppName
    $parametersObject = @{targetSlot = "$DestinationSlot" }
    if ($SourceSlot -eq "production") {
        $resourceName = "$WebAppName"
        $resourceType = "Microsoft.Web/sites"
    }
    else {
        $resourceName = "$WebAppName/$SourceSlot"
        $resourceType = "Microsoft.Web/sites/slots"
    }

    Write-VstsTaskVerbose -Message "[Azure Call] Swapping slot: $resourceName with resource type: $resourceType to $DestinationSlot"
    $result = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType $resourceType -ResourceName $resourceName -Action slotsswap -Parameters $parametersObject -ApiVersion 2015-07-01 -Force -Verbose
    Write-VstsTaskVerbose -Message "[Azure Call] Slot swapped: $resourceName with resource type: $resourceType to $DestinationSlot"

    $scheme = "http"
    $hostName = $result.Properties.HostNames[0]
    foreach ($hostNameSslState in $result.Properties.HostNameSslStates) {
        if ($hostName -eq $hostNameSslState.Name) {
            if (-not $hostNameSslState.SslState -eq 0) {
                $scheme = "https"
            }

            break
        }
    }

    $destinationUrlValue = "${scheme}://$hostName"

    Write-Host (Get-VstsLocString -Key "WebappslotsuccessfullyswappedatUrl0" -ArgumentList $destinationUrlValue)

    # Set ouput variable with $destinationUrl
    if (-not [string]::IsNullOrEmpty($DestinationUrl)) {
        if ([string]::IsNullOrEmpty($destinationUrl)) {
            Throw (Get-VstsLocString -Key "Unabletoretrievewebapppublishurlforwebapp0" -ArgumentList $webAppName)
        }

        Set-VstsTaskVariable -Name $DestinationUrl -Value $destinationUrlValue
    }
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
