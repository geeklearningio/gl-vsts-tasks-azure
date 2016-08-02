# Microsoft Azure Build and Release Tasks

Visual Studio Team Services Build and Release Management extensions that help you to build and publish your applications on Microsoft Azure.

[Learn more](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki) about this extension on the wiki!

![cistatus](https://geeklearning.visualstudio.com/_apis/public/build/definitions/f841b266-7595-4d01-9ee1-4864cf65aa73/37/badge)

![Icon](https://github.com/geeklearningio/gl-vsts-tasks-azure/blob/master/Extension/extension-icon.png)

## Tasks included

* **[Azure Web App Slots Swap](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Slots-Swap)**: Swap two deployment slots of an Azure Web App
* **[Azure Web App Start](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Start)**: Start an Azure Web App, or one of its slot
* **[Azure Web App Stop](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Stop)**: Stop an Azure Web App, or one of its slot
* **Azure SQL Database Restore**: restore an Azure SQL Database to another Azure SQL Database on the same server

## To contribute

1. Globally install typescript and tfx-cli (to package VSTS extensions): `npm install -g typescript tfx-cli`
2. From the root of the repo run `npm install`. This will pull down the necessary modules for the different tasks and for the build tools.
3. Run `npm run build` to compile the build tasks.
4. Run `npm run package -- --version <version>` to create the .vsix extension packages (supports multiple environments) that includes the build tasks.

## Release Notes

> **8-1-2016**
> - New build tools for all GL tasks

> **7-31-2016**
> - Added: Azure RM Support

## Contributors

This extension was created by [Geek Learning](http://geeklearning.io/), with help from the community.