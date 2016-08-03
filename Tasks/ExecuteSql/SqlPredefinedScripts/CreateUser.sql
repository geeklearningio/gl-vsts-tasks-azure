if not exists(select * from [sys].[sysusers] where name = '$(Login)')
begin
	create user $(Login)
	for login $(Login)
	with default_schema = dbo
end
