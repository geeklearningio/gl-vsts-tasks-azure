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

    $ServerName = $ServerName.ToLower()
    $serverFriendlyName = $ServerName.split(".")[0]
    Write-Verbose "Server friendly name is $serverFriendlyName"

    $resourceGroupName = Get-AzureSqlDatabaseServerResourceGroupName -serverName $serverFriendlyName

    Write-Verbose "[Azure Call] Getting Azure SQL Database details for target $TargetDatabaseName"
    $targetDatabase = Get-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverFriendlyName -DatabaseName $TargetDatabaseName -ErrorAction Stop -Verbose
    Write-Verbose "[Azure Call] Azure SQL Database details got for target $TargetDatabaseName :"
    Write-Verbose ($targetDatabase | Format-List | Out-String)

    if ($targetDatabase){
        Write-Verbose "[Azure Call] Azure SQL Database $TargetDatabaseName exists: removing it!"
        Remove-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverFriendlyName -DatabaseName $TargetDatabaseName -Force -ErrorAction Stop -Verbose
        Write-Verbose "[Azure Call] Azure SQL Database $TargetDatabaseName removed"
    }

    Write-Verbose "[Azure Call] Getting Azure SQL Database details for source $SourceDatabaseName"
    $sourceDatabase = Get-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverFriendlyName -DatabaseName $SourceDatabaseName
    Write-Verbose "[Azure Call] Azure SQL Database details got for source $SourceDatabaseName :"
    Write-Verbose ($sourceDatabase | Format-List | Out-String)

    $date = Get-Date

    Write-Verbose "[Azure Call] Restoring Azure SQL Database $SourceDatabaseName to $TargetDatabaseName"
    Restore-AzureRmSqlDatabase -FromPointInTimeBackup -PointInTime $date -ResourceGroupName $sourceDatabase.ResourceGroupName `
        -ServerName $serverFriendlyName -TargetDatabaseName $TargetDatabaseName -ResourceId $sourceDatabase.ResourceID `
        -Edition $sourceDatabase.Edition -ServiceObjectiveName $sourceDatabase.CurrentServiceObjectiveName -ErrorAction Stop -Verbose
    Write-Verbose "[Azure Call] Azure SQL Database $SourceDatabaseName restored to $TargetDatabaseName"

    Write-Verbose "Completed Azure SQL Database Restore Task"
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}