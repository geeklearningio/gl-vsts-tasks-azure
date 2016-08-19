$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here/Helpers.ps1"

$config = Get-TestsConfiguration -invocationCommandPath $MyInvocation.MyCommand.Path

Import-Module $config.taskLibPath -ArgumentList @{ NonInteractive = $true }

Describe "SqlMultiDacpacDeployment" {
	
	Context "With correctly configured Azure Endpoint" {

		Add-AzureEndpoint -config $config
		Add-EnvironmentVariable -name "BUILD_SOURCESDIRECTORY" -value $here

		It "Runs" {
            Add-VstsInput -name "DacpacFiles" -value $config.settings.SqlMultiDacpacDeployment.DacpacFiles.Replace("`$(Build.SourcesDirectory)", $here)
            Add-VstsInput -name "AdditionalArguments" -value $config.settings.SqlMultiDacpacDeployment.AdditionalArguments
            Add-VstsInput -name "ServerName" -value $config.settings.SqlMultiDacpacDeployment.ServerName
            Add-VstsInput -name "DatabaseName" -value $config.settings.SqlMultiDacpacDeployment.DatabaseName
            Add-VstsInput -name "SqlUsername" -value $config.settings.SqlMultiDacpacDeployment.SqlUsername
            Add-VstsInput -name "SqlPassword" -value $config.settings.SqlMultiDacpacDeployment.SqlPassword
            Add-VstsInput -name "IpDetectionMethod" -value $config.settings.SqlMultiDacpacDeployment.IpDetectionMethod
            Add-VstsInput -name "DeleteFirewallRule" -value $config.settings.SqlMultiDacpacDeployment.DeleteFirewallRule.ToString()

			Invoke-VstsTaskScript -ScriptBlock ([scriptblock]::Create(". $($config.targetScriptPath)")) -Verbose

			$error.Count | Should Be 0
		}

		It "Fails because no DACPAC is found" {
            Add-VstsInput -name "DacpacFiles" -value "whatever\\*.any"
            Add-VstsInput -name "AdditionalArguments" -value $config.settings.SqlMultiDacpacDeployment.AdditionalArguments
            Add-VstsInput -name "ServerName" -value $config.settings.SqlMultiDacpacDeployment.ServerName
            Add-VstsInput -name "DatabaseName" -value $config.settings.SqlMultiDacpacDeployment.DatabaseName
            Add-VstsInput -name "SqlUsername" -value $config.settings.SqlMultiDacpacDeployment.SqlUsername
            Add-VstsInput -name "SqlPassword" -value $config.settings.SqlMultiDacpacDeployment.SqlPassword
            Add-VstsInput -name "IpDetectionMethod" -value $config.settings.SqlMultiDacpacDeployment.IpDetectionMethod
            Add-VstsInput -name "DeleteFirewallRule" -value $config.settings.SqlMultiDacpacDeployment.DeleteFirewallRule.ToString()

			Invoke-VstsTaskScript -ScriptBlock ([scriptblock]::Create(". $($config.targetScriptPath)")) -Verbose

			($error.Count -gt 0) | Should Be $True
		}
	}
}