[CmdletBinding(DefaultParameterSetName = 'None')]
param
(
    [String] [Parameter(Mandatory = $true)]
    $ConnectedServiceName,
    
    [String] [Parameter(Mandatory = $true)]
    $ResourceGroupName,

    [String] [Parameter(Mandatory = $true)]
    $SqlServerName,

    [String] [Parameter(Mandatory = $true)]
    $SqlDatabaseName,

    [String] [Parameter(Mandatory = $true)]
    $TargetSqlDatabaseName,

    [String] [Parameter(Mandatory = $true)]
    $SqlAdminUser,

    [String] [Parameter(Mandatory = $true)]
    $SqlPassword,

    [String] [Parameter(Mandatory = $true)]
    $LoginToAdd
)

Write-Verbose "Entering script RestoreSqlDatabaseToSqlDatabase.ps1"

Write-Host "ConnectedServiceName = $ConnectedServiceName"
Write-Host "ResourceGroupName= $ResourceGroupName"
Write-Host "SqlServerName= $SqlServerName"
Write-Host "SqlDatabaseName= $SqlDatabaseName"
Write-Host "TargetSqlDatabaseName= $TargetSqlDatabaseName"
Write-Host "SqlAdminUser= $SqlAdminUser"
Write-Host "SqlPassword= $SqlPassword"
Write-Host "LoginToAdd= $LoginToAdd"

Import-Module AzureRM.Sql
Import-Module sqlps

Write-Host "Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $TargetSqlDatabaseName -ErrorAction SilentlyContinue"
$TargetDatabase = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $TargetSqlDatabaseName -ErrorAction SilentlyContinue
Write-Host "TargetDatabase= $TargetDatabase"

if ($TargetDatabase){
    Write-Host "Remove-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $TargetSqlDatabaseName -Force"
    Remove-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $TargetSqlDatabaseName -Force
}

Write-Host "Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $SqlDatabaseName"
$Database = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $SqlDatabaseName
Write-Host "Database= $Database"

$Date = Get-Date
Write-Host "Restore-AzureRmSqlDatabase -FromPointInTimeBackup -PointInTime $Date -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -TargetDatabaseName $TargetSqlDatabaseName -ResourceId $Database.ResourceID -Edition 'Standard' -ServiceObjectiveName 'S0'"
Restore-AzureRmSqlDatabase -FromPointInTimeBackup -PointInTime $Date -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -TargetDatabaseName $TargetSqlDatabaseName -ResourceId $Database.ResourceID -Edition "Standard" -ServiceObjectiveName "S0"

$sql =	@"
			CREATE USER $LoginToAdd
			FOR LOGIN $LoginToAdd
			WITH DEFAULT_SCHEMA = dbo
			GO
			EXEC sp_addrolemember N'db_owner', N'$LoginToAdd'
			GO
"@

Write-Host "Invoke-Sqlcmd -Query '$sql' -Database $TargetSqlDatabaseName -ServerInstance 'tcp:$SqlServerName.database.windows.net' -EncryptConnection -Username $SqlAdminUser -Password $SqlPassword -Verbose"
Invoke-Sqlcmd -Query "$sql" -Database $TargetSqlDatabaseName -ServerInstance "tcp:$SqlServerName.database.windows.net" -EncryptConnection -Username $SqlAdminUser -Password $SqlPassword -Verbose

Write-Verbose "Leaving script RestoreSqlDatabaseToSqlDatabase.ps1"
