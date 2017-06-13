[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
    # Get inputs.
    $ServerName = Get-VstsInput -Name ServerName -Require
    $SourceDatabaseName = Get-VstsInput -Name SourceDatabaseName -Require
    $TargetDatabaseName = Get-VstsInput -Name TargetDatabaseName -Require

    # Initialize Azure.
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers
    Initialize-Azure

    # Import SQL Azure Powershell cmdlets.
    Import-Module AzureRM.Sql

    # Import the loc strings.
    Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json    

    $serverFriendlyName = Get-SqlServerFriendlyName -serverName $ServerName

    $resourceGroupName = Get-AzureSqlDatabaseServerResourceGroupName -serverName $serverFriendlyName

    Write-VstsTaskVerbose -Message "[Azure Call] Getting Azure SQL Database details for target $TargetDatabaseName"
    $targetDatabase = Get-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverFriendlyName -DatabaseName $TargetDatabaseName -ErrorAction SilentlyContinue -Verbose

    if ($targetDatabase) {
        Write-VstsTaskVerbose -Message "[Azure Call] Azure SQL Database details got for target $TargetDatabaseName :"
        Write-VstsTaskVerbose -Message ($targetDatabase | Format-List | Out-String)

        Write-VstsTaskVerbose -Message "[Azure Call] Azure SQL Database $TargetDatabaseName exists: removing it!"
        Remove-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverFriendlyName -DatabaseName $TargetDatabaseName -Force -ErrorAction Stop -Verbose
        Write-VstsTaskVerbose -Message "[Azure Call] Azure SQL Database $TargetDatabaseName removed"
    }
    else {
        Write-VstsTaskVerbose -Message "[Azure Call] Target Azure SQL Database $TargetDatabaseName does not exists. Continuing..."
    }

    Write-VstsTaskVerbose -Message "[Azure Call] Getting Azure SQL Database details for source $SourceDatabaseName"
    $sourceDatabase = Get-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverFriendlyName -DatabaseName $SourceDatabaseName
    Write-VstsTaskVerbose -Message "[Azure Call] Azure SQL Database details got for source $SourceDatabaseName :"
    Write-VstsTaskVerbose -Message ($sourceDatabase | Format-List | Out-String)

    $date = (Get-Date).AddMinutes(-1)

    if ([string]::IsNullOrEmpty($sourceDatabase.ElasticPoolName)) {
        Write-VstsTaskVerbose -Message "[Azure Call] Restoring Azure SQL Database $SourceDatabaseName to $TargetDatabaseName (Edition $($sourceDatabase.Edition) $($sourceDatabase.CurrentServiceObjectiveName))"

        Restore-AzureRmSqlDatabase -FromPointInTimeBackup -PointInTime $date -ResourceGroupName $sourceDatabase.ResourceGroupName `
            -ServerName $serverFriendlyName -TargetDatabaseName $TargetDatabaseName -ResourceId $sourceDatabase.ResourceID `
            -Edition $sourceDatabase.Edition -ServiceObjectiveName $sourceDatabase.CurrentServiceObjectiveName -ErrorAction Stop -Verbose

        Write-VstsTaskVerbose -Message "[Azure Call] Azure SQL Database $SourceDatabaseName restored to $TargetDatabaseName (Edition $($sourceDatabase.Edition) $($sourceDatabase.CurrentServiceObjectiveName))"
    }
    else {
        Write-VstsTaskVerbose -Message "[Azure Call] Restoring Azure SQL Database $SourceDatabaseName to $TargetDatabaseName (ElasticPool $($sourceDatabase.ElasticPoolName))"

        Restore-AzureRmSqlDatabase -FromPointInTimeBackup -PointInTime $date -ResourceGroupName $sourceDatabase.ResourceGroupName `
            -ServerName $serverFriendlyName -TargetDatabaseName $TargetDatabaseName -ResourceId $sourceDatabase.ResourceID `
            -ElasticPoolName $sourceDatabase.ElasticPoolName -ErrorAction Stop -Verbose

        Write-VstsTaskVerbose -Message "[Azure Call] Azure SQL Database $SourceDatabaseName restored to $TargetDatabaseName (ElasticPool $($sourceDatabase.ElasticPoolName))"
    }

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}