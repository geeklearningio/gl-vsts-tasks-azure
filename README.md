![Icon](https://github.com/geeklearningio/gl-vsts-tasks-azure/blob/master/Extension/extension-icon.png)

# Microsoft Azure Build and Release Tasks

[![Build status](https://geeklearning.visualstudio.com/gl-github/_apis/build/status/Azure%20Pipelines%20Tasks/gl-vsts-tasks-azure)](https://geeklearning.visualstudio.com/gl-github/_build/latest?definitionId=37)

Visual Studio Team Services Build and Release Management extensions that help you to build and publish your applications on Microsoft Azure.

[Learn more](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki) about this extension on the wiki!

## Tasks included

* **[Azure Web App Slots Swap](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Slots-Swap)**: Swap two deployment slots of an Azure Web App
* **[Azure Web App Start](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Start)**: Start an Azure Web App, or one of its slot
* **[Azure Web App Stop](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Stop)**: Stop an Azure Web App, or one of its slot
* **[Azure SQL Execute Query](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-SQL-Execute-Query)**: Execute a SQL query on an Azure SQL Database
* **[Azure SQL Database Restore](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-SQL-Database-Restore)**: Restore an Azure SQL Database to another Azure SQL Database on the same server using the latest point-in-time backup
* **[Azure SQL Database Incremental Deployment](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-SQL-Database-Incremental-Deployment)**: Deploy an Azure SQL Database using multiple DACPAC and performing incremental deployments based on current Data-Tier Application version
* **[Azure Copy Files](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/AzCopy)**: Copy blobs across Azure Storage accounts using AzCopy

## To contribute

1. Globally install typescript and tfx-cli (to package VSTS extensions): `npm install -g typescript tfx-cli`
2. From the root of the repo run `npm install`. This will pull down the necessary modules for the different tasks and for the build tools.
3. Run `npm run build` to compile the build tasks.
4. Run `npm run package -- --version <version>` to create the .vsix extension packages (supports multiple environments) that includes the build tasks.

## Release Notes

> **10-24-2016**
> - Added: AzCopy Tool Task

> **8-19-2016**
> - Added: Azure SQL Database Incremental Deployment

> **8-1-2016**
> - Added: Azure SQL Execute Query
> - New build tools for all GL tasks

> **7-31-2016**
> - Added: Azure RM Support

## Contributors

This extension was created by [Geek Learning](http://geeklearning.io/), with help from the community.

## Attributions

* [AzureWebPowerShellDeployment icon from the VSTS Tasks project](https://github.com/Microsoft/vsts-tasks)
* [SqlAzureDacpacDeployment icon from the VSTS Tasks project](https://github.com/Microsoft/vsts-tasks)
* [Lightning by Carla Dias from the Noun Project](https://thenounproject.com/search/?q=lightning&i=542899)
* [Restore by Arthur Shlain from the Noun Project](https://thenounproject.com/search/?q=restore&i=52760)
* [Trade by Michelle Fosse from the Noun Project](https://thenounproject.com/search/?q=swap&i=560173)
* [Stop by NAS from the Noun Project](https://thenounproject.com/search/?q=stop&i=55668)
* [Play by NAS from the Noun Project](https://thenounproject.com/search/?q=play&i=55667)
* [Checkmarks by Matt Saling from the Noun Project](https://thenounproject.com/search/?q=Checkmarks&i=202337)
