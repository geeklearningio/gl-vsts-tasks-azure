function Get-TestsConfiguration() {
	param(
        [Parameter(Mandatory=$true)][string]$invocationCommandPath
	)

	function ExtendJSON($base, $ext) {
		$propNames = $($ext | Get-Member -MemberType *Property).Name
		foreach ($propName in $propNames) {
			if ($base.PSObject.Properties.Match($propName).Count) {
				if ($base.$propName.GetType().Name -eq "PSCustomObject") {
					$base.$propName = ExtendJSON $base.$propName $ext.$propName
				}
				else {
					$base.$propName = $ext.$propName
				}
			}
			else {
				$base | Add-Member -MemberType NoteProperty -Name $propName -Value $ext.$propName
			}
		}

		return $base
	}

	$here = Split-Path -Parent $invocationCommandPath
	$appSettings = Get-Content (Join-Path $here "appsettings.json") | ConvertFrom-Json
	$appDevelopmentSettingsPath = Join-Path $here "appsettings.development.json"

	if (Test-Path $appDevelopmentSettingsPath) {
		$appDevelopmentSettings = Get-Content $appDevelopmentSettingsPath | ConvertFrom-Json
		$settings = ExtendJSON $appSettings $appDevelopmentSettings
	}
	else {
		$settings = $appSettings
	}

	$tasksFolderPath = Resolve-Path "$here/$($settings.VstsTasksPath)"
	$scriptName = (Split-Path -Leaf $invocationCommandPath) -replace '\.Tests\.', '.'
	$scriptFolderName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)
	$scriptPath = Resolve-Path "$tasksFolderPath/$scriptFolderName/$scriptName"
	$taskLibPath = Resolve-Path "$tasksFolderPath/$scriptFolderName/$($settings.VstsTaskSdkPath)"

	return @{
		settings = $settings
		tasksFolderPath = $tasksFolderPath
		targetScriptName = $scriptFolderName
		targetScriptPath = $scriptPath
		taskLibPath = $taskLibPath
	}
}

function Add-AzureEndpoint() {
	param(
        [Parameter(Mandatory=$true)]$config,
        [Parameter(Mandatory=$false)][string]$inputName
    )

	if (!($inputName)) {
		$inputName = "ConnectedServiceName"
	}

	$endPointName = [System.Guid]::NewGuid().ToString()

	$auth = @{
		scheme = "ServicePrincipal"
        parameters = @{
			servicePrincipalId = $config.settings.AzureAccount.ServicePrincipalClientId
            servicePrincipalKey = $config.settings.AzureAccount.ServicePrincipalKey
            tenantId = $config.settings.AzureAccount.TenantId
        }
    } | ConvertTo-Json

	$data = @{
		subscriptionId = $config.settings.AzureAccount.SubscriptionId
		subscriptionName = $config.settings.AzureAccount.SubscriptionName
		azureSpnRoleAssignmentId = ""
		spnObjectId = ""
		appObjectId = ""
		creationMode = "Manual"
    } | ConvertTo-Json

	Add-VstsInput -name $inputName -value $endPointName
	Add-VstsEndPoint -name $endPointName -url "https://management.core.windows.net/" `
					 -auth $auth -data $data
}

function Add-EnvironmentVariable() {
	param(
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$false)][string]$value
    )

	$addEnvironmentVariable = "`${env:$name} = '$value'"
	Invoke-Expression -Command $addEnvironmentVariable
}

function Add-VstsInput() {
	param(
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$false)][string]$value
    )

	Add-EnvironmentVariable -name "INPUT_$name" -value $value
}

function Add-VstsEndPoint() {
	param(
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$url,
        [Parameter(Mandatory=$true)][string]$auth,
        [Parameter(Mandatory=$true)][string]$data
    )

	Add-EnvironmentVariable -name "ENDPOINT_URL_$name" -value $url
	Add-EnvironmentVariable -name "ENDPOINT_AUTH_$name" -value $auth
	Add-EnvironmentVariable -name "ENDPOINT_DATA_$name" -value $data
}