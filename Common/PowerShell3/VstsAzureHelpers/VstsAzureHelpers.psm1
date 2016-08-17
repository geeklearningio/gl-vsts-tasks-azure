# Private module-scope variables.
$script:azureModule = $null
$script:azureRMProfileModule = $null

# Override the DebugPreference.
if ($global:DebugPreference -eq 'Continue') {
    Write-Verbose '$OVERRIDING $global:DebugPreference from ''Continue'' to ''SilentlyContinue''.'
    $global:DebugPreference = 'SilentlyContinue'
}

# Import the loc strings.
Import-VstsLocStrings -LiteralPath $PSScriptRoot/module.json

# Dot source the private functions.
. $PSScriptRoot/InitializeFunctions.ps1
. $PSScriptRoot/ImportFunctions.ps1
. $PSScriptRoot/HelperFunctions.ps1
. $PSScriptRoot/FindSqlPackagePath.ps1

function Initialize-Azure {
    [CmdletBinding()]
    param()
    Trace-VstsEnteringInvocation $MyInvocation
    try {
        # Get the inputs.
        $serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Default 'ConnectedServiceName'
        $serviceName = Get-VstsInput -Name $serviceNameInput -Default (Get-VstsInput -Name DeploymentEnvironmentName)
        if (!$serviceName) {
            # Let the task SDK throw an error message if the input isn't defined.
            Get-VstsInput -Name $serviceNameInput -Require
        }

        $endpoint = Get-VstsEndpoint -Name $serviceName -Require
        $storageAccount = Get-VstsInput -Name StorageAccount

        # Determine which modules are preferred.
        $preferredModules = @( )
        if ($endpoint.Auth.Scheme -eq 'ServicePrincipal') {
            $preferredModules += 'AzureRM'
        } elseif ($endpoint.Auth.Scheme -eq 'UserNamePassword') {
            $preferredModules += 'Azure'
            $preferredModules += 'AzureRM'
        } else {
            $preferredModules += 'Azure'
        }

        # Import/initialize the Azure module.
        Import-AzureModule -PreferredModule $preferredModules
        Initialize-AzureSubscription -Endpoint $endpoint -StorageAccount $storageAccount

        # Check the installed Azure Powershell version
        $currentVersion = (Get-Module -Name AzureRM.profile).Version
        Write-Verbose  "Installed Azure PowerShell version: $currentVersion"

        $minimumAzureVersion = New-Object System.Version(0, 9, 9)           
        if (-not ($currentVersion -and $currentVersion -gt $minimumAzureVersion)) {
            throw (Get-VstsLocString -Key AZ_RequiresMinVersion0 -ArgumentList $minimumAzureVersion)
        }
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Get-AgentIPAddress {
    param([String] $startIPAddress,
          [String] $endIPAddress,
          [String] [Parameter(Mandatory = $true)] $ipDetectionMethod)

    [HashTable]$iPAddress = @{}
    if($ipDetectionMethod -eq "IPAddressRange") {
        $iPAddress.StartIPAddress = $startIPAddress
        $iPAddress.EndIPAddress = $endIPAddress
    }
    elseif($ipDetectionMethod -eq "AutoDetect") {
        $iPAddress.StartIPAddress = Get-AgentStartIPAddress
        $iPAddress.EndIPAddress = $IPAddress.StartIPAddress
    }

    return $iPAddress
}

function Add-AzureSqlDatabaseServerFirewallRule {
    param([String] [Parameter(Mandatory = $true)] $startIp,
          [String] [Parameter(Mandatory = $true)] $endIp,
          [String] [Parameter(Mandatory = $true)] $serverName)

    [HashTable]$firewallSettings = @{}
    $firewallRuleName = [System.Guid]::NewGuid().ToString()

    $azureResourceGroupName = Get-AzureSqlDatabaseServerResourceGroupName -serverName $serverName

    try {
        Write-Verbose "[Azure Call] Creating firewall rule $firewallRuleName on Azure SQL Server: $serverName"
        New-AzureRMSqlServerFirewallRule -ResourceGroupName $azureResourceGroupName -StartIPAddress $startIp -EndIPAddress $endIp -ServerName $serverName -FirewallRuleName $firewallRuleName -ErrorAction Stop -Verbose
        Write-Verbose "[Azure Call] Firewall rule $firewallRuleName created on Azure SQL Server: $serverName"
    }
    catch [Hyak.Common.CloudException] {
        $exceptionMessage = $_.Exception.Message.ToString()
        Write-Verbose "ExceptionMessage: $exceptionMessage"

        throw (Get-VstsLocString -Key AZ_InvalidIpAddress)
    }

    $firewallSettings.IsConfigured = $true
    $firewallSettings.RuleName = $firewallRuleName

    return $firewallSettings
}

function Remove-AzureSqlDatabaseServerFirewallRule {
    param([String] [Parameter(Mandatory = $true)] $serverName,
          [String] $firewallRuleName,
          [String] $isFirewallConfigured,
          [String] [Parameter(Mandatory = $true)] $deleteFireWallRule)

    if ($deleteFireWallRule -eq "true" -and $isFirewallConfigured -eq "true") {               
        $azureResourceGroupName = Get-AzureSqlDatabaseServerResourceGroupName -serverName $serverName
        Write-Verbose "[Azure Call] Deleting firewall rule $firewallRuleName on Azure SQL Server: $serverName"
        Remove-AzureRMSqlServerFirewallRule -ResourceGroupName $azureResourceGroupName -ServerName $serverName -FirewallRuleName $firewallRuleName -Force -ErrorAction Stop -Verbose
        Write-Verbose "[Azure Call] Firewall rule $firewallRuleName deleted on Azure SQL Server: $serverName"
    }
}

function Get-AzureSqlDatabaseServerResourceGroupName {
    param([String] [Parameter(Mandatory = $true)] $serverName)

    return Get-ResourceGroupName -resourceName $serverName -resourceType "Microsoft.Sql/servers"
}

function Get-WebAppResourceGroupName {
    param([String] [Parameter(Mandatory = $true)] $webAppName)

    return Get-ResourceGroupName -resourceName $webAppName -resourceType "Microsoft.Web/sites"
}

function Get-SqlPackagePath {
    $sqlPackage = Get-SqlPackageOnTargetMachine 
    return $sqlPackage
}

Export-ModuleMember -Function Initialize-Azure
Export-ModuleMember -Function Get-AgentIPAddress
Export-ModuleMember -Function Add-AzureSqlDatabaseServerFirewallRule
Export-ModuleMember -Function Remove-AzureSqlDatabaseServerFirewallRule
Export-ModuleMember -Function Get-AzureSqlDatabaseServerResourceGroupName
Export-ModuleMember -Function Get-WebAppResourceGroupName
Export-ModuleMember -Function Get-SqlPackagePath
