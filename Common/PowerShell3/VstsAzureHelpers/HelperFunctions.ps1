function Get-AgentStartIPAddress {
    $data = (Invoke-WebRequest -Uri "checkip.dyndns.org" -UseBasicParsing -Verbose).Content

    $ipRegex = "(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))"
    if ($data -Match $ipRegex) {
        $startIP = $Matches.Address
    }
    else {
        throw (Get-VstsLocString -Key AZ_CannotRetrieveExternalIp0 -ArgumentList $data)
    }

    return $startIP
}

function Get-ResourceGroupName {
    param([String] [Parameter(Mandatory = $true)] $resourceName,
          [String] [Parameter(Mandatory = $true)] $resourceType)

    try {
        Write-VstsTaskVerbose -Message "[Azure Call] Getting resource details for resource: $resourceName with resource type: $resourceType"
        $resourceDetails = (Get-AzureRMResource -ErrorAction Stop) | Where-Object { $_.ResourceName -eq $resourceName -and $_.ResourceType -eq $resourceType } -Verbose
        Write-VstsTaskVerbose -Message "[Azure Call] Retrieved resource details successfully for resource: $resourceName with resource type: $resourceType"   
        $resourceGroupName = $resourceDetails.ResourceGroupName  
        Write-VstsTaskVerbose -Message "Resource Group Name for '$resourceName' of type '$resourceType': '$resourceGroupName'."
        return $resourceGroupName
    }
    finally {
        if ([string]::IsNullOrEmpty($resourceGroupName)) {
            throw (Get-VstsLocString -Key AZ_ResourceNotFound0 -ArgumentList $resourceName)
        }
    }
}
