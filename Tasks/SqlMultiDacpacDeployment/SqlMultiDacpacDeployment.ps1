[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
    $DacpacFiles = Get-VstsInput -Name DacpacFiles -Require
    $AdditionalArguments = Get-VstsInput -Name AdditionalArguments
    $ServerName = Get-VstsInput -Name ServerName -Require
    $DatabaseName = Get-VstsInput -Name DatabaseName -Require
    $SqlUsername = Get-VstsInput -Name SqlUsername
    $SqlPassword = Get-VstsInput -Name SqlPassword
    $PublishProfile = Get-VstsInput -Name PublishProfile
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

    $dacpacFilePaths = Find-VstsFiles -LegacyPattern $DacpacFiles -Verbose

    if (!$dacpacFilePaths) {
        throw (Get-VstsLocString -Key "No files were found to deploy with search pattern {0}" -ArgumentList $DacpacFiles)
    }

    $publishProfilePath = ""
    if ([string]::IsNullOrWhitespace($PublishProfile) -eq $false -and $PublishProfile -ne $env:SYSTEM_DEFAULTWORKINGDIRECTORY -and $PublishProfile -ne [String]::Concat($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "\")) {
        $publishProfilePath = Find-VstsFiles -LegacyPattern $PublishProfile
        if ($publishProfilePath -is [system.array]) {
            throw (Get-VstsLocString -Key "Found more than one file to deploy with search pattern {0}. There can be only one." -ArgumentList $PublishProfile)
        }
        elseif (!$publishProfilePath) {
            throw (Get-VstsLocString -Key "No files were found to deploy with search pattern {0}" -ArgumentList $PublishProfile)
        }
    }

    if ($dacpacFilePaths -isnot [System.Array]) {
        $dacpacFilePaths = @($dacpacFilePaths)
    }

    $dacFilesWithVersion = Get-DacpacVersions -dacpacFilePaths $dacpacFilePaths

    $ipAddress = Get-AgentIPAddress -startIPAddress $StartIpAddress -endIPAddress $EndIpAddress -ipDetectionMethod $IpDetectionMethod
    $firewallSettings = Add-AzureSqlDatabaseServerFirewallRule -startIP $ipAddress.StartIPAddress -endIP $ipAddress.EndIPAddress -serverName $serverFriendlyName

    try {
        $variableParameter = @("DatabaseName='$DatabaseName'")
        Write-VstsTaskVerbose -Message "[SQL Call] Retrieving $DatabaseName DAC Version Number..."
        $databaseVersion = [Version]((Invoke-Sqlcmd -InputFile "$PSScriptRoot\SqlScripts\GetDatabaseVersion.sql" -Database "master" -ServerInstance $ServerName -EncryptConnection -Username $SqlUsername -Password $SqlPassword -Variable $variableParameter -ErrorAction Stop -Verbose).DatabaseVersion)
        Write-VstsTaskVerbose -Message "[SQL Call] $DatabaseName DAC Version Number retrieved: $databaseVersion"

        $dacFilesToDeploy = $dacFilesWithVersion.GetEnumerator() | Where-Object {$_.Name -gt $databaseVersion}
        if ($dacFilesToDeploy.Count -eq 0) {
            Write-VstsTaskWarning -Message "Nothing to deploy, the database version ($databaseVersion) is up to date"
        }
        else {
            $sqlPackagePath = Get-SqlPackagePath

            # Always register Data-Tier Application (as this task needs to retrieve later the database version number)
            if (-not ($AdditionalArguments -like "*RegisterDataTierApplication*")) {
                $AdditionalArguments += " /p:RegisterDataTierApplication=True"
            }

            foreach ($dacFileToDeploy in $dacFilesToDeploy) {
                Write-Host "Deploying Version: $($dacFileToDeploy.Name)"

                $scriptArguments = Get-SqlPackageCommandArguments -dacpacFile $dacFileToDeploy.Value -serverName $ServerName -databaseName $DatabaseName `
                                                                -sqlUsername $SqlUsername -sqlPassword $SqlPassword -publishProfile $publishProfilePath -additionalArguments $AdditionalArguments

                $scriptArgumentsToBeLogged = Get-SqlPackageCommandArguments -dacpacFile $dacFileToDeploy.Value -serverName $ServerName -databaseName $DatabaseName `
                                                                -sqlUsername $SqlUsername -sqlPassword $SqlPassword -publishProfile $publishProfilePath -additionalArguments $AdditionalArguments -isOutputSecure

                Send-ExecuteCommand -command $sqlPackagePath -arguments $scriptArguments -secureArguments $scriptArgumentsToBeLogged
                
                Write-Host "Version $($dacFileToDeploy.Name) deployed" 
            }
        }
    } finally {
        Remove-AzureSqlDatabaseServerFirewallRule -serverName $serverFriendlyName -firewallRuleName $firewallSettings.RuleName -isFirewallConfigured $firewallSettings.IsConfigured -deleteFireWallRule $DeleteFirewallRule
    }
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
