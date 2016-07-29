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

Write-Verbose "Entering script StartWebApp.ps1"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebSiteName"
Write-Host "Slot= $Slot"

if ($Slot)
{    
    Write-Host "Start-AzureWebsiteSlot -Name $WebSiteName -Slot $Slot -Verbose"
    Start-AzureWebsite -Name "$WebSiteName" -Slot "$Slot" -Verbose
}
else
{
    Write-Host "Start-AzureWebsiteSlot -Name $WebSiteName -Verbose"
    Start-AzureWebsite -Name "$WebSiteName" -Verbose    
}

Write-Verbose "Leaving script StartWebApp.ps1"
