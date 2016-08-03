[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
    # Get inputs.
    $ScriptType = Get-VstsInput -Name ScriptType -Require
    $ScriptPath = Get-VstsInput -Name ScriptPath
    $PredefinedScript = Get-VstsInput -Name PredefinedScript   
    $Variables = Get-VstsInput -Name Variables    
    $InlineScript = Get-VstsInput -Name InlineScript
    $ServerName = Get-VstsInput -Name ServerName -Require
    $DatabaseName = Get-VstsInput -Name DatabaseName -Require
    $SqlUsername = Get-VstsInput -Name SqlUsername -Require
    $SqlPassword = Get-VstsInput -Name SqlPassword -Require
    $IpDetectionMethod = Get-VstsInput -Name IpDetectionMethod -Require
    $StartIpAddress = Get-VstsInput -Name StartIpAddress
    $EndIpAddress = Get-VstsInput -Name EndIpAddress
    $DeleteFirewallRule = Get-VstsInput -Name DeleteFirewallRule -Require

    # Initialize Azure.
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers
    Initialize-Azure

    # Import SQL Powershell cmdlets.
    Import-Module sqlps

    # Import the loc strings.
    Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json    

    $ServerName = $ServerName.ToLower()
    $serverFriendlyName = $ServerName.split(".")[0]
    Write-Verbose "Server friendly name is $serverFriendlyName"

    # Getting start and end IP address for agent machine.
    $ipAddress = Get-AgentIPAddress -startIPAddress $StartIpAddress -endIPAddress $EndIpAddress -ipDetectionMethod $IpDetectionMethod
    Write-Verbose ($ipAddress | Format-List | Out-String)

    try {
        # Creating firewall rule for agent on SQL server.
        $firewallSettings = Add-AzureSqlDatabaseServerFirewallRule -startIP $ipAddress.StartIPAddress -endIP $ipAddress.EndIPAddress -serverName $serverFriendlyName
        Write-Verbose ($firewallSettings | Format-List | Out-String)

        $firewallRuleName = $firewallSettings.RuleName
        $isFirewallConfigured = $firewallSettings.IsConfigured
            
        $variableParameter = @()
        if ($Variables) {
            $variableParameter = ($Variables -split '[\r\n]') |? {$_}
            Write-Verbose "Variable Parameters: $variableParameter"
        }

        Write-Verbose "[Azure Call] Executing SQL query on $DatabaseName"

        if ($ScriptType -eq "FilePath") {
            Invoke-Sqlcmd -InputFile "$ScriptPath" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable $variableParameter -ErrorAction Stop -Verbose
        }
        elseif ($ScriptType -eq "InlineScript") {
            Invoke-Sqlcmd -Query "$InlineScript" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable $variableParameter -ErrorAction Stop -Verbose
        }
        else {     
            $workingFolderVariable = @("WorkingFolder='$PSScriptRoot\SqlPredefinedScripts'")
            if ($variableParameter -isnot [system.array]) {
                $variableParameter = @($variableParameter)
            }

            $variableParameter = $variableParameter + $workingFolderVariable
            Invoke-Sqlcmd -InputFile "$PSScriptRoot\SqlPredefinedScripts\$PredefinedScript.sql" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable $variableParameter -ErrorAction Stop -Verbose            
        }

        Write-Verbose "[Azure Call] SQL query executed on $DatabaseName"

    } finally {
        Remove-AzureSqlDatabaseServerFirewallRule -serverName $serverFriendlyName -firewallRuleName $firewallRuleName -isFirewallConfigured $isFirewallConfigured -deleteFireWallRule $DeleteFirewallRule
    }

    Write-Verbose "Completed Azure SQL Execute Query Task"
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
