[CmdletBinding(DefaultParameterSetName = 'None')]
param
(
    [String] [Parameter(Mandatory = $true)]
    $ConnectedServiceName,

    [String] [Parameter(Mandatory = $true)]
    $WebSiteName,

    [String] [Parameter(Mandatory = $false)]
    $Slot,

    [String] [Parameter(Mandatory = $true)]
    $WebHookUrl
)

Write-Verbose "Entering script PostReleaseToSlack.ps1"

# Import the Task.Common and Task.Internal dll that has all the cmdlets we need for Build
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebSiteName"
Write-Host "Slot= $Slot"
Write-Host "WebHookUrl= $WebHookUrl"

# $VstsUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
# $VstsCollection = "DefaultCollection"
# $VstsProject = $env:SYSTEM_TEAMPROJECT

$author = Get-TaskVariable $distributedTaskContext "build.sourceVersionAuthor"
if([string]::IsNullOrEmpty($author)) {
    # fall back to build/release requestedfor
    $author = Get-TaskVariable $distributedTaskContext "build.requestedfor"
    if([string]::IsNullOrEmpty($author)) {
        $author = Get-TaskVariable $distributedTaskContext "release.requestedfor"
    }
    # At this point if this is still null, let's use agent name
    if([string]::IsNullOrEmpty($author)) {
        $author = Get-TaskVariable $distributedTaskContext "agent.name"
    }
}

if ($Slot)
{
    $website = Get-AzureWebsite -Name "$WebSiteName" -Slot "$Slot"
}
else
{
    $website = Get-AzureWebsite -Name "$WebSiteName"
}

$websiteUrl = "http://$($website.EnabledHostNames[0])" 

$buildIdTaskVar = Get-TaskVariable $distributedTaskContext "build.buildId"
$releaseName = Get-TaskVariable $distributedTaskContext "release.releaseName"
$environmentName = Get-TaskVariable $distributedTaskContext "release.environmentName"

$message = @{
  attachments = @(
    @{
      color = "good"
      fields = @(
        @{
          title = "Requested by"
          value = $author
          short = "true"
        }
      )
      pretext = "Release $ReleaseName deployed to $EnvironmentName environment successfully! :grinning:
You can test it now on <$websiteUrl>."
      mrkdwn_in = @(
        "pretext"
      )
      fallback = "Release $ReleaseName deployed to $EnvironmentName successfully!"
    }
  )
}

$json = $message | ConvertTo-Json -Depth 4

try 
{
  Invoke-RestMethod -Uri "$WebHookUrl" -Method Post -Body $json -ContentType 'application/json; charset=utf-8'
}
catch 
{
  echo "Slack API call failed."
  echo "StatusCode:" $_.Exception.Response.StatusCode.value__ 
  echo "StatusDescription:" $_.Exception.Response.StatusDescription
}

Write-Verbose "Leaving script PostReleaseToSlack.ps1"