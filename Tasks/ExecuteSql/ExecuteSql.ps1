[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
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

    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers

    Initialize-Azure
    Initialize-Sqlps

    Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json    

    $ServerName = $ServerName.ToLower()
    $serverFriendlyName = $ServerName.split(".")[0]
    Write-VstsTaskVerbose -Message "Server friendly name is $serverFriendlyName"

    $ipAddress = Get-AgentIPAddress -startIPAddress $StartIpAddress -endIPAddress $EndIpAddress -ipDetectionMethod $IpDetectionMethod
    $firewallSettings = Add-AzureSqlDatabaseServerFirewallRule -startIP $ipAddress.StartIPAddress -endIP $ipAddress.EndIPAddress -serverName $serverFriendlyName

    try {
        if ($ScriptType -eq "PredefinedScript") {
            $ScriptType = "FilePath"
            $ScriptPath = "$PSScriptRoot\SqlPredefinedScripts\$PredefinedScript.sql"
        }

        $variableParameter = @()
        if ($Variables) {
            $variableParameter = ($Variables -split '[\r\n]') |? {$_}
        }

        $workingFolder = Split-Path $ScriptPath
        $workingFolderVariable = @("WorkingFolder=$workingFolder")
        if ($variableParameter -isnot [system.array]) {
            $variableParameter = @($variableParameter)
        }

        $variableParameter = $variableParameter + $workingFolderVariable

        if ($ScriptType -eq "FilePath") {
            Write-VstsTaskVerbose -Message "[Azure Call] Executing SQL query $ScriptPath on $DatabaseName with variables $variableParameter"
            Invoke-Sqlcmd -InputFile "$ScriptPath" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable $variableParameter -ErrorAction Stop -Verbose
        }
        else {
            Write-VstsTaskVerbose -Message "[Azure Call] Executing inline SQL query on $DatabaseName with variables $variableParameter"
            Invoke-Sqlcmd -Query "$InlineScript" -Database $DatabaseName -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable $variableParameter -ErrorAction Stop -Verbose
        }

        Write-VstsTaskVerbose -Message "[Azure Call] SQL query executed on $DatabaseName"

    } finally {
        Remove-AzureSqlDatabaseServerFirewallRule -serverName $serverFriendlyName -firewallRuleName $firewallSettings.RuleName -isFirewallConfigured $firewallSettings.IsConfigured -deleteFireWallRule $DeleteFirewallRule
    }
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
