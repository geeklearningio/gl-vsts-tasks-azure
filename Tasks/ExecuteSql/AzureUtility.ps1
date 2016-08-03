function Get-AgentStartIPAddress
{
    $endpoint = Get-VstsEndpoint -Name SystemVssConnection
    $credentials = Get-VstsVssCredentials
    
    $agentWorkerModulesPath = "$($env:AGENT_HOMEDIRECTORY)\agent\worker"    

    $SystemNetHttpFormatting = [reflection.assembly]::LoadFrom("$agentWorkerModulesPath\System.Net.Http.Formatting.dll")
    $NewtonsoftJson = [reflection.assembly]::LoadFrom("$agentWorkerModulesPath\Newtonsoft.Json.dll")

    $OnAssemblyResolve = [System.ResolveEventHandler] {
        param($sender, $e)

        if ($e.Name.StartsWith("Newtonsoft.Json"))
        { 
            return $NewtonsoftJson 
        }

        if ($e.Name.StartsWith("System.Net.Http.Formatting"))
        {
            return $SystemNetHttpFormatting
        }

        foreach ($a in [System.AppDomain]::CurrentDomain.GetAssemblies())
        {
            if ($a.FullName -eq $e.Name)
            {
                return $a
            }
        }

        return $null
    }

    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($OnAssemblyResolve)

    [reflection.assembly]::LoadFrom("$agentWorkerModulesPath\Microsoft.TeamFoundation.DistributedTask.Agent.Interfaces.dll")
    [reflection.assembly]::LoadFrom("$agentWorkerModulesPath\Microsoft.VisualStudio.Services.WebApi.dll")
    [reflection.assembly]::LoadFrom("$agentWorkerModulesPath\Microsoft.TeamFoundation.DistributedTask.Agent.Common.dll")
    [reflection.assembly]::LoadFrom("$agentWorkerModulesPath\Microsoft.VisualStudio.Services.Common.dll")
    
    Import-Module "$agentWorkerModulesPath\Modules\Microsoft.TeamFoundation.DistributedTask.Task.Internal\Microsoft.TeamFoundation.DistributedTask.Task.Internal.dll"
    Import-Module "$agentWorkerModulesPath\Modules\Microsoft.TeamFoundation.DistributedTask.Task.Common\Microsoft.TeamFoundation.DistributedTask.Task.Common.dll"
    Import-Module "$agentWorkerModulesPath\Modules\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs.dll"

    $connection = New-Object Microsoft.VisualStudio.Services.WebApi.VssConnection -ArgumentList @($endpoint.Url, $credentials)

    # getting start ip address from dtl service
    Write-Verbose "Getting external ip address by making call to dtl service"
    $startIP = Get-ExternalIpAddress -Connection $connection

    [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($OnAssemblyResolve)

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
