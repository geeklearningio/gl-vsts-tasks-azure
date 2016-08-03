[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {

	# Get inputs.
    $ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName -Require
    $ScriptType = Get-VstsInput -Name ScriptType -Require
    $ScriptPath = Get-VstsInput -Name ScriptPath   
    $Arguments = Get-VstsInput -Name Arguments
    $InlineScript = Get-VstsInput -Name InlineScript
    $ServerName = Get-VstsInput -Name ServerName
    $DatabaseName = Get-VstsInput -Name DatabaseName
    $SqlUsername = Get-VstsInput -Name SqlUsername
    $SqlPassword = Get-VstsInput -Name SqlPassword
    $IpDetectionMethod = Get-VstsInput -Name IpDetectionMethod
    $StartIpAddress = Get-VstsInput -Name StartIpAddress
    $EndIpAddress = Get-VstsInput -Name EndIpAddress
    $DeleteFirewallRule = Get-VstsInput -Name DeleteFirewallRule

    # Import the Task.Common and Task.Internal dll that has all the cmdlets we need for Build
    $agentWorkerModulesPath = "$($env:AGENT_HOMEDIRECTORY)\agent\worker\Modules"
    $agentDistributedTaskInternalModulePath = "$agentWorkerModulesPath\Microsoft.TeamFoundation.DistributedTask.Task.Internal\Microsoft.TeamFoundation.DistributedTask.Task.Internal.dll"
    $agentDistributedTaskCommonModulePath = "$agentWorkerModulesPath\Microsoft.TeamFoundation.DistributedTask.Task.Common\Microsoft.TeamFoundation.DistributedTask.Task.Common.dll"
    $agentDistributedTaskDevTestLabsModulePath = "$agentWorkerModulesPath\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs.dll"
    
    Import-Module $agentDistributedTaskInternalModulePath
    Import-Module $agentDistributedTaskCommonModulePath
    Import-Module agentDistributedTaskDevTestLabsModulePath

	# Initialize Azure.
	Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
	Initialize-Azure

	# Import the loc strings.
	Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json    

	# Load all dependent files for execution
	. $PSScriptRoot/AzureUtility.ps1

    $ErrorActionPreference = 'Stop'

    $ServerName = $ServerName.ToLower()
    $serverFriendlyName = $ServerName.split(".")[0]
    Write-Verbose "Server friendly name is $serverFriendlyName"

    # Getting start and end IP address for agent machine
    $ipAddress = Get-AgentIPAddress -startIPAddress $StartIpAddress -endIPAddress $EndIpAddress -ipDetectionMethod $IpDetectionMethod
    Write-Verbose ($ipAddress | Format-List | Out-String)

    $startIp =$ipAddress.StartIPAddress
    $endIp = $ipAddress.EndIPAddress

    try
    {
        # Importing required version of azure cmdlets according to azureps installed on machine
        $azureUtility = Get-AzureUtility

        Write-Verbose "Loading $azureUtility"
        Import-Module ./$azureUtility -Force

        # Getting connection type (Certificate/UserNamePassword/SPN) used for the task
        $connectionType = Get-ConnectionType -connectedServiceName $ConnectedServiceName

        # creating firewall rule for agent on sql server
        $firewallSettings = Create-AzureSqlDatabaseServerFirewallRule -startIP $startIp -endIP $endIp -serverName $serverFriendlyName -connectionType $connectionType
        Write-Verbose ($firewallSettings | Format-List | Out-String)

        $firewallRuleName = $firewallSettings.RuleName
        $isFirewallConfigured = $firewallSettings.IsConfigured

        Write-Verbose "[Azure Call] Executing SQL query on $DatabaseName"
        
        if ($ScriptType -eq "FilePath") {
            Invoke-Sqlcmd -Query "$InlineScript" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable "$Arguments" -Verbose
        }
        else {
            Invoke-Sqlcmd -InputFile "$ScriptPath" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable "$Arguments" -Verbose
        }

        Write-Verbose "[Azure Call] SQL query executed on $DatabaseName"

    } finally {
        # deleting firewall rule for agent on sql server
        Delete-AzureSqlDatabaseServerFirewallRule -serverName $serverFriendlyName -firewallRuleName $firewallRuleName -connectionType $connectionType `
                                                -isFirewallConfigured $isFirewallConfigured -deleteFireWallRule $DeleteFirewallRule
    }

	Write-Verbose "Completed Azure SQL Execute Query Task"

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
