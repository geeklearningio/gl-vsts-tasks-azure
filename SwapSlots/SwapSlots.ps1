[CmdletBinding(DefaultParameterSetName = 'None')]
param
(
    [String] [Parameter(Mandatory = $true)]
    $ConnectedServiceName,

    [String] [Parameter(Mandatory = $true)]
    $WebSiteName,

    [String] [Parameter(Mandatory = $true)]
    $SourceSlot, 

    [String] [Parameter(Mandatory = $true)]
    $DestinationSlot
)

Write-Verbose "Entering script SwapSlots.ps1"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebSiteName"
Write-Host "SourceSlot= $SourceSlot"
Write-Host "DestinationSlot= $DestinationSlot"

Write-Host "Switch-AzureWebsiteSlot -Name $WebSiteName -Slot1 $SourceSlot -Slot2 $DestinationSlot -Force -Verbose"
Switch-AzureWebsiteSlot -Name "$WebSiteName" -Slot1 "$SourceSlot" -Slot2 "$DestinationSlot" -Force -Verbose

Write-Verbose "Leaving script SwapSlots.ps1"
