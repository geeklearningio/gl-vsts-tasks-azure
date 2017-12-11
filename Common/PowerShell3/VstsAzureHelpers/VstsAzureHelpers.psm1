# Private module-scope variables.
$script:azureModule = $null
$script:azureRMProfileModule = $null

# Override the DebugPreference.
if ($global:DebugPreference -eq 'Continue') {
    Write-VstsTaskVerbose -Message '$OVERRIDING $global:DebugPreference from ''Continue'' to ''SilentlyContinue''.'
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
        Write-VstsTaskVerbose -Message  "Installed Azure PowerShell version: $currentVersion"

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

    Write-VstsTaskVerbose -Message "Agent IP Addresses:"
    Write-VstsTaskVerbose -Message " Start IP: $($iPAddress.StartIPAddress)"
    Write-VstsTaskVerbose -Message " End IP: $($iPAddress.EndIPAddress)"

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
        Write-VstsTaskVerbose -Message "[Azure Call] Creating firewall rule $firewallRuleName on Azure SQL Server: $serverName"
        $null = New-AzureRMSqlServerFirewallRule -ResourceGroupName $azureResourceGroupName -StartIPAddress $startIp -EndIPAddress $endIp -ServerName $serverName -FirewallRuleName $firewallRuleName -ErrorAction Stop
        Write-VstsTaskVerbose -Message "[Azure Call] Firewall rule $firewallRuleName created on Azure SQL Server: $serverName"
    }
    catch [Hyak.Common.CloudException] {
        $exceptionMessage = $_.Exception.Message.ToString()
        Write-VstsTaskVerbose -Message "ExceptionMessage: $exceptionMessage"
        throw (Get-VstsLocString -Key AZ_InvalidIpAddress)
    }

    $firewallSettings.IsConfigured = $true
    $firewallSettings.RuleName = $firewallRuleName

    Write-VstsTaskVerbose -Message "Add Azure SQL Database Server Firewall Rule:"
    Write-VstsTaskVerbose -Message " IsConfigured: $($firewallSettings.IsConfigured)"
    Write-VstsTaskVerbose -Message " RuleName: $($firewallSettings.RuleName)"

    return $firewallSettings
}

function Remove-AzureSqlDatabaseServerFirewallRule {
    param([String] [Parameter(Mandatory = $true)] $serverName,
          [String] $firewallRuleName,
          [String] $isFirewallConfigured,
          [String] [Parameter(Mandatory = $true)] $deleteFireWallRule)

    if ($deleteFireWallRule -eq "true" -and $isFirewallConfigured -eq "true") {               
        $azureResourceGroupName = Get-AzureSqlDatabaseServerResourceGroupName -serverName $serverName
        Write-VstsTaskVerbose -Message "[Azure Call] Deleting firewall rule $firewallRuleName on Azure SQL Server: $serverName"
        $null = Remove-AzureRMSqlServerFirewallRule -ResourceGroupName $azureResourceGroupName -ServerName $serverName -FirewallRuleName $firewallRuleName -Force -ErrorAction Stop
        Write-VstsTaskVerbose -Message "[Azure Call] Firewall rule $firewallRuleName deleted on Azure SQL Server: $serverName"
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
    Write-VstsTaskVerbose -Message "SqlPackage Path: '$sqlPackage'"
    return $sqlPackage
}

function Get-DacpacVersions {
    param([System.Array] [Parameter(Mandatory = $true)] $dacpacFilePaths)

    $dotnetVersion = [Environment]::Version            
    if (!($dotnetVersion.Major -ge 4 -and $dotnetversion.Build -ge 30319)) {            
        throw (Get-VstsLocString -Key "You have not Microsoft .Net Framework 4.5 installed on build agent.")          
    }

    Add-Type -As System.IO.Compression.FileSystem
    $dacpacFileExtension = ".dacpac"
    $dacFilesWithVersion = @{}

    foreach ($dacpacFilePath in $dacpacFilePaths) {
        if ([System.IO.Path]::GetExtension($dacpacFilePath) -ne $dacpacFileExtension) {
            throw (Get-VstsLocString -Key "Invalid Dacpac file '{0}' provided" -ArgumentList $dacpacFilePath)
        }

        $dacMetadataXml = $null
        $dacVersion = $null

        $zip = [IO.Compression.ZipFile]::OpenRead($dacpacFilePath)
        $zip.Entries | Where-Object { $_.Name.EndsWith("DacMetadata.xml") } | ForEach-Object {
            $memoryStream = New-Object System.IO.MemoryStream
            $file = $_.Open()
            $file.CopyTo($memoryStream)
            $file.Dispose()
            $memoryStream.Position = 0
            $reader = New-Object System.IO.StreamReader($memoryStream)
            $dacMetadataXml = $reader.ReadToEnd()
            $reader.Dispose()
            $memoryStream.Dispose()
        }

        $zip.Dispose() 
        
        if ($dacMetadataXml -ne $null) {
            $dacVersion = Select-Xml -XPath "//dac:DacType/dac:Version" -Content $dacMetadataXml -Namespace @{ dac = "http://schemas.microsoft.com/sqlserver/dac/Serialization/2012/02" }        
            $dacFilesWithVersion.Add([Version]($dacVersion.ToString()), $dacpacFilePath)
        }
        else {
            throw (Get-VstsLocString -Key "Invalid Dacpac file '{0}' provided" -ArgumentList $dacpacFile)
        }
    }

    $dacFilesWithVersion = $dacFilesWithVersion.GetEnumerator() | Sort-Object Name
    Write-VstsTaskVerbose -Message "DACPAC files with version:"
    foreach ($dacFileWithVersion in $dacFilesWithVersion) {
        Write-VstsTaskVerbose -Message " Version: $($dacFileWithVersion.Name) Path: $($dacFileWithVersion.Value)"
    }

    return $dacFilesWithVersion
}

function Send-ExecuteCommand {
    param([String][Parameter(Mandatory=$true)] $command,
          [String][Parameter(Mandatory=$true)] $arguments,
          [String][Parameter(Mandatory=$true)] $secureArguments)

    $errorActionPreferenceRestore = $ErrorActionPreference
    $ErrorActionPreference="SilentlyContinue"

    $errout = $stdout = ""

    $arguments = $arguments.Replace(';', '`;')

    Write-VstsTaskVerbose -Message "[CMD Call] Executing: & `"$command`" $secureArguments 2>''"
    $null = Invoke-Expression "& `"$command`" $arguments 2>''" -ErrorVariable errout -OutVariable stdout
    Write-VstsTaskVerbose -Message "[CMD Call] Executed"

    $ErrorActionPreference = $errorActionPreferenceRestore

    foreach ($out in $stdout) {
        Write-VstsTaskVerbose -Message $out
    }

    if ($LastExitCode -gt 0) {
        foreach ($out in $errout) {
            Write-VstsTaskError -Message $out                        
        }

        throw $errout[0].Exception
    }
}

function Get-SqlPackageCommandArguments {
    param([String] $dacpacFile,
          [String] $serverName,
          [String] $databaseName,
          [String] $sqlUsername,
          [String] $sqlPassword,
          [String] $connectionString,
          [String] $publishProfile,
          [String] $additionalArguments,
          [switch] $isOutputSecure)

    $ErrorActionPreference = 'Stop'
    $SqlPackageOptions = @{
        SourceFile = "/SourceFile:"; 
        Action = "/Action:"; 
        TargetServerName = "/TargetServerName:";
        TargetDatabaseName = "/TargetDatabaseName:";
        TargetUser = "/TargetUser:";
        TargetPassword = "/TargetPassword:";
        TargetConnectionString = "/TargetConnectionString:";
        Profile = "/Profile:";
    }

    $dacpacFileExtension = ".dacpac"
    if ([System.IO.Path]::GetExtension($dacpacFile) -ne $dacpacFileExtension) {
        throw (Get-VstsLocString -Key "Invalid Dacpac file '{0}' provided" -ArgumentList $dacpacFile)
    }

    $sqlPackageArguments = @($SqlPackageOptions.SourceFile + "`"$dacpacFile`"")
    $sqlPackageArguments += @($SqlPackageOptions.Action + "Publish")
    $sqlPackageArguments += @($SqlPackageOptions.TargetServerName + "`"$serverName`"")
    if ($databaseName) {
        $sqlPackageArguments += @($SqlPackageOptions.TargetDatabaseName + "`"$databaseName`"")
    }

    if ($sqlUsername) {
        $sqlPackageArguments += @($SqlPackageOptions.TargetUser + "`"$sqlUsername`"")
        if (-not($sqlPassword)) {
            throw (Get-VstsLocString -Key "No password specified for the SQL User: '{0}'" -ArgumentList $sqlUserName)
        }

        if ($isOutputSecure) {
            $sqlPassword = "********"
        }
        else {
            $sqlPassword = $sqlPassword.Replace('"', '\"')
        }
        
        $sqlPackageArguments += @($SqlPackageOptions.TargetPassword + "`"$sqlPassword`"")
    }

    if ($publishProfile) {
        if([System.IO.Path]::GetExtension($publishProfile) -ne ".xml") {
            throw (Get-VstsLocString -Key "Invalid Publish Profile '{0}' provided" -ArgumentList $publishProfile)
        }

        $sqlPackageArguments += @($SqlPackageOptions.Profile + "`"$publishProfile`"")
    }

    $sqlPackageArguments += @("$additionalArguments")
    $scriptArgument = ($sqlPackageArguments -join " ")

    return $scriptArgument
}

function Initialize-Sqlps {
    [CmdletBinding()]
    param()
    
    Trace-VstsEnteringInvocation $MyInvocation
    
    try {
        # pushd and popd to avoid import from changing the current directory (ref: http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
        # 3>&1 puts warning stream to standard output stream (see https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
        # out-null blocks that output, so we don't see the annoying warnings described here: https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/ 
        Push-Location

        $sqlModule = Get-Module -ListAvailable | where -Property Name -eq SqlServer
        $sqlps = Get-Module -ListAvailable | where -Property Name -eq sqlps

        if ($sqlps) {
            Import-Module -Name sqlps -Global -PassThru -Cmdlet Invoke-Sqlcmd 3>&1 | Out-Null
            Write-VstsTaskVerbose -Message "SQLPS Module Imported"
        } else {
            if(!$sqlModule) {
                Install-module -Name SqlServer -Scope CurrentUser -Force
            }
    
            Import-Module -Name SqlServer -Global -PassThru -Cmdlet Invoke-Sqlcmd 3>&1 | Out-Null
            Write-VstsTaskVerbose -Message "SqlServer Module Imported"
        }

        Pop-Location
    }
    finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Get-SqlServerFriendlyName {
    param([String] [Parameter(Mandatory = $true)] $serverName)

    $serverName = $serverName.ToLower()
    if (-not $serverName.Contains(".database.windows.net")){
        Write-VstsTaskWarning -Message "Bad task configuration: the ServerName parameter should be given with an Azure SQL Server name, like FabrikamSQL.database.windows.net,1433 or FabrikamSQL.database.windows.net"
    }

    $serverFriendlyName = $serverName.split(".")[0]
    Write-VstsTaskVerbose -Message "Server friendly name is $serverFriendlyName" 

    return $serverFriendlyName
}

Export-ModuleMember -Function Initialize-Azure
Export-ModuleMember -Function Get-AgentIPAddress
Export-ModuleMember -Function Add-AzureSqlDatabaseServerFirewallRule
Export-ModuleMember -Function Remove-AzureSqlDatabaseServerFirewallRule
Export-ModuleMember -Function Get-AzureSqlDatabaseServerResourceGroupName
Export-ModuleMember -Function Get-WebAppResourceGroupName
Export-ModuleMember -Function Get-SqlPackagePath
Export-ModuleMember -Function Get-DacpacVersions
Export-ModuleMember -Function Send-ExecuteCommand
Export-ModuleMember -Function Get-SqlPackageCommandArguments
Export-ModuleMember -Function Initialize-Sqlps
Export-ModuleMember -Function Get-SqlServerFriendlyName
