# This file implements IAzureUtility for Azure PowerShell version >= 1.0.0

function Get-WebAppRGName
{
    param([String] [Parameter(Mandatory = $true)] $webAppName)

    $ARMSqlServerResourceType =  "Microsoft.Web/sites"

    try
    {
        Write-Verbose "[Azure Call] Getting resource details for webapp resource: $webAppName with resource type: $ARMSqlServerResourceType"
        $azureWebAppResourceDetails = (Get-AzureRmResource -ErrorAction Stop) | Where-Object { $_.ResourceType -eq $ARMSqlServerResourceType -and $_.ResourceName -eq $webAppName}
        Write-Verbose "[Azure Call] Retrieved resource details successfully for webapp resource: $webAppName with resource type: $ARMSqlServerResourceType"

        $azureResourceGroupName = $azureWebAppResourceDetails.ResourceGroupName
        return $azureWebAppResourceDetails.ResourceGroupName
    }
    finally
    {
        if ([string]::IsNullOrEmpty($azureResourceGroupName))
        {
            Write-Verbose "[Azure Call] Web App: $webAppName not found"

            Throw (Get-VstsLocString -Key "Web App: '{0}' not found." -ArgumentList $webAppName)
        }
    }
}
