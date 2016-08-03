if exists(select * from [sys].[sysusers] where name = '$(Login)')
begin
	exec sp_addrolemember N'$(Role)', N'$(Login)'
end
