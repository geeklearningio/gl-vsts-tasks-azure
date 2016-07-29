[CmdletBinding(DefaultParameterSetName = 'None')]
param
(
    [String] [Parameter(Mandatory = $true)]
    $ConnectedServiceName,

    [String] [Parameter(Mandatory = $true)]
    $WebSiteName,

    [String] [Parameter(Mandatory = $false)]
    $Slot
)

Write-Verbose "Entering script StopWebApp.ps1"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebSiteName"
Write-Host "Slot= $Slot"

if ($Slot)
{    
    Write-Host "Stop-AzureWebsiteSlot -Name $WebSiteName -Slot $Slot -Verbose"
    Stop-AzureWebsite -Name "$WebSiteName" -Slot "$Slot" -Verbose
}
else
{
    Write-Host "Stop-AzureWebsiteSlot -Name $WebSiteName -Verbose"
    Stop-AzureWebsite -Name "$WebSiteName" -Verbose    
}

Write-Verbose "Leaving script StopWebApp.ps1"
