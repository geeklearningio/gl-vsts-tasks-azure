declare @databaseVersion nvarchar(50)

select @databaseVersion = type_version
from master.dbo.sysdac_instances
where instance_name = $(DatabaseName)

select isnull(@databaseVersion, '0.0.0.0') as DatabaseVersion