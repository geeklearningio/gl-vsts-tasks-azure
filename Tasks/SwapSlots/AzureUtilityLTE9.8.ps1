# This file implements IAzureUtility for Azure PowerShell version <= 0.9.8

function Get-WebAppRGName
{
    param([String] [Parameter(Mandatory = $true)] $webAppName)

    $ARMSqlServerResourceType =  "Microsoft.Web/sites"
    Switch-AzureMode AzureResourceManager

    try
    {
        Write-Verbose "[Azure Call] Getting resource details for webapp resource: $webAppName with resource type: $ARMSqlServerResourceType"
        $azureWebAppResourceDetails = (Get-AzureResource -ResourceName $webAppName -ErrorAction Stop) | Where-Object { $_.ResourceType -eq $ARMSqlServerResourceType }
        Write-Verbose "[Azure Call] Retrieved resource details successfully for webapp resource: $webAppName with resource type: $ARMSqlServerResourceType"

        $azureResourceGroupName = $azureWebAppResourceDetails.ResourceGroupName
        return $azureWebAppResourceDetails.ResourceGroupName
    }
    finally
    {
        if ([string]::IsNullOrEmpty($azureResourceGroupName))
        {
            Write-Verbose "[Azure Call] Web App: $webAppName not found"

            Throw "Web App: '$webAppName' not found."
        }
    }
}
