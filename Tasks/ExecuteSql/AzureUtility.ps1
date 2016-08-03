function Get-AgentStartIPAddress
{
    $connection = Get-VstsEndpoint -Name SystemVssConnection

    # getting start ip address from dtl service
    Write-Verbose "Getting external ip address by making call to dtl service"
    $startIP = Get-ExternalIpAddress -Connection $connection

    return $startIP
}

function Get-AgentIPAddress
{
    param([String] $startIPAddress,
          [String] $endIPAddress,
          [String] [Parameter(Mandatory = $true)] $ipDetectionMethod)

    [HashTable]$IPAddress = @{}
    if($ipDetectionMethod -eq "IPAddressRange")
    {
        $IPAddress.StartIPAddress = $startIPAddress
        $IPAddress.EndIPAddress = $endIPAddress
    }
    elseif($ipDetectionMethod -eq "AutoDetect")
    {
        $IPAddress.StartIPAddress = Get-AgentStartIPAddress
        $IPAddress.EndIPAddress = $IPAddress.StartIPAddress
    }

    return $IPAddress
}

function Get-AzureUtility
{
    $currentVersion =  Get-AzureCmdletsVersion
    Write-Verbose "Installed Azure PowerShell version: $currentVersion"

    $minimumAzureVersion = New-Object System.Version(0, 9, 9)
    $versionCompatible = Get-AzureVersionComparison -AzureVersion $currentVersion -CompareVersion $minimumAzureVersion

    $azureUtilityOldVersion = "AzureUtilityLTE9.8.ps1"
    $azureUtilityNewVersion = "AzureUtilityGTE1.0.ps1"

    if(!$versionCompatible)
    {
        $azureUtilityRequiredVersion = $azureUtilityOldVersion
    }
    else
    {
        $azureUtilityRequiredVersion = $azureUtilityNewVersion
    }

    Write-Verbose "Required AzureUtility: $azureUtilityRequiredVersion"
    return $azureUtilityRequiredVersion
}

function Create-AzureSqlDatabaseServerFirewallRule
{
    param([String] [Parameter(Mandatory = $true)] $startIp,
          [String] [Parameter(Mandatory = $true)] $endIp,
          [String] [Parameter(Mandatory = $true)] $serverName)

    [HashTable]$FirewallSettings = @{}
    $firewallRuleName = [System.Guid]::NewGuid().ToString()

    Create-AzureSqlDatabaseServerFirewallRuleARM -startIPAddress $startIp -endIPAddress $endIp -serverName $serverName -firewallRuleName $firewallRuleName | Out-Null

    $FirewallSettings.IsConfigured = $true
    $FirewallSettings.RuleName = $firewallRuleName

    return $FirewallSettings
}

function Delete-AzureSqlDatabaseServerFirewallRule
{
    param([String] [Parameter(Mandatory = $true)] $serverName,
          [String] $firewallRuleName,
          [String] $isFirewallConfigured,
          [String] [Parameter(Mandatory = $true)] $deleteFireWallRule)

    if ($deleteFireWallRule -eq "true" -and $isFirewallConfigured -eq "true")
    {        
        Delete-AzureSqlDatabaseServerFirewallRuleARM -serverName $serverName -firewallRuleName $firewallRuleName | Out-Null
    }
}
