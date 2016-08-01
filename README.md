![cistatus](https://geeklearning.visualstudio.com/_apis/public/build/definitions/f841b266-7595-4d01-9ee1-4864cf65aa73/37/badge)

# Microsoft Azure Build and Release Tasks

Visual Studio Team Services Build and Release Management extensions that help you to build and publish your applications on Microsoft Azure.

[Learn more](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki) about this extension on the wiki!

## Tasks included

* **[Azure Web App Slots Swap](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-Web-App-Slots-Swap)**: Swap two deployment slots of an Azure Web App
* **Start Azure Web App**: start an Azure Web App, or one of its slot
* **Stop Azure Web App**: stop an Azure Web App, or one of its slot
* **Azure SQL Database Restore**: restore an Azure SQL Database to another Azure SQL Database on the same server

## To contribute

1. From the root of the repo run `npm install`. This will pull down the necessary modules.
2. Run `gulp build` to compile the build tasks
3. Run `gulp package --version <version>` to create the .vsix extension packages (supports multiple environments) that includes the build tasks

## Release Notes
> **7-31-2016**
> - Added: Azure RM Support

## Contributors

This extension was created by [Geek Learning](http://geeklearning.io/), with help from the community.

We'd like to thank [Jesse Houwing](https://github.com/jessehouwing) for inspiring us.