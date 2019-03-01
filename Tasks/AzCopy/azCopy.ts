import { StorageManagementClient } from "azure-arm-storage";
import fs = require("fs-extra");
import path = require("path");
import q = require("q");
import tl = require("vsts-task-lib/task");
import { ToolRunner } from "vsts-task-lib/toolrunner";
import XRegExp = require("xregexp");
import azureEndpointConnection = require("./azureEndpointConnection");

const recursive: boolean = tl.getBoolInput("Recursive");
const pattern: string = tl.getInput("Pattern");
const excludeNewer: boolean = tl.getBoolInput("ExcludeNewer");
const excludeOlder: boolean = tl.getBoolInput("ExcludeOlder");
const sourceKind: string = tl.getInput("SourceKind");
const sourcePath: string = tl.getInput("SourcePath");
const sourceConnectedServiceName: string = tl.getInput("SourceConnectedServiceName");
const sourceAccount: string = tl.getInput("SourceAccount");
const sourceObject: string = tl.getInput("SourceObject");
const destinationKind: string = tl.getInput("DestinationKind");
const destinationPath: string = tl.getInput("DestinationPath");
const destinationConnectedServiceName: string = tl.getInput("DestinationConnectedServiceName");
const destinationAccount: string = tl.getInput("DestinationAccount");
const destinationObject: string = tl.getInput("DestinationObject");

const programFiles: string = tl.getVariable("ProgramFiles(x86)");
const additionalArguments: string = tl.getVariable("Arguments");

const azCopyknownLocations: string[] = [
    path.join(tl.getVariable("Agent.HomeDirectory"), "externals/azcopy/azcopy.exe"),
    path.join(__dirname, "../../azcopy.exe"),
    path.join(programFiles ? programFiles : "C:\\ProgramFiles(x86)", "Microsoft SDKs/Azure/AzCopy/azcopy.exe"),
];

const accountIdRegex: RegExp = XRegExp(
    "/subscriptions/(?<subscriptionId>.*?)"
    + "/resourceGroups/(?<resourceGroupName>.*?)"
    + "/providers/Microsoft.Storage"
    + "/storageAccounts/(?<accountName>.*?)");

function getConnectedServiceCredentials(connectedService: string): q.Promise<any> {
    const endpointAuth: tl.EndpointAuthorization = tl.getEndpointAuthorization(connectedService, true);
    const servicePrincipalId: string = endpointAuth.parameters.serviceprincipalid;
    const servicePrincipalKey: string = endpointAuth.parameters.serviceprincipalkey;
    const tenantId: string = endpointAuth.parameters.tenantid;
    const subscriptionName: string = tl.getEndpointDataParameter(connectedService, "SubscriptionName", true);
    const subscriptionId: string = tl.getEndpointDataParameter(connectedService, "SubscriptionId", true);

    return azureEndpointConnection.getConnectedServiceCredentials(
        connectedService,
        servicePrincipalId,
        servicePrincipalKey,
        tenantId,
        subscriptionName,
        subscriptionId);
}

function getStorageAccount(
    credentials: ICachedSubscriptionCredentals,
    accountName: string): q.Promise<IStorageAccount> {
    const deferal: q.Deferred<IStorageAccount> = q.defer<IStorageAccount>();

    const client: StorageManagementClient = new StorageManagementClient(credentials.creds, credentials.id);
    client.storageAccounts.list((listError: any, result: any): void => {
        if (listError) {
            deferal.reject(listError);
        }

        const account: any = result.filter((x: any) => x.name === accountName)[0];
        const parsedAccountId: any = XRegExp.exec(account.id, accountIdRegex) as any;
        const resourceGroupName: any = parsedAccountId.resourceGroupName;

        client.storageAccounts.getProperties(
            resourceGroupName,
            accountName,
            (getPropertiesError: any, properties: any): void => {
                if (getPropertiesError) {
                    deferal.reject(getPropertiesError);
                } else {
                    client.storageAccounts.listKeys(
                        resourceGroupName,
                        accountName,
                        (listKeysError: any, keys: any): void => {
                            if (listKeysError) {
                                deferal.reject(listKeysError);
                            } else {
                                deferal.resolve({
                                    blobEndpoint: properties.primaryEndpoints.blob,
                                    key: keys.keys[0].value,
                                    resourceGroupName,
                                    tableEndpoint: properties.primaryEndpoints.table,
                                });
                            }
                        });
                }
            });
    });

    return deferal.promise;
}

(async function execute(): Promise<void> {
    try {
        const azCopy: string[] = azCopyknownLocations.filter((x) => fs.existsSync(x));
        if (azCopy.length) {

            tl.debug("AzCopy utility found at path : " + azCopy[0]);

            const toolRunner: ToolRunner = tl.tool(azCopy[0]);

            if (sourceKind === "Storage") {
                tl.debug("retrieving source account details");
                const sourceCredentials: any = await getConnectedServiceCredentials(sourceConnectedServiceName);
                const sourceStorageAccount: IStorageAccount = await getStorageAccount(sourceCredentials, sourceAccount);
                tl.debug(sourceStorageAccount.blobEndpoint + sourceObject);
                toolRunner.arg("/Source:" + sourceStorageAccount.blobEndpoint + sourceObject);
                toolRunner.arg("/SourceKey:" + sourceStorageAccount.key);
            } else {
                toolRunner.arg("/Source:" + sourcePath);
            }

            if (destinationKind === "Storage") {
                const destCredentials: any = await getConnectedServiceCredentials(destinationConnectedServiceName);
                const destStorageAccount: IStorageAccount = await getStorageAccount(
                    destCredentials,
                    destinationAccount);
                tl.debug(destStorageAccount.blobEndpoint + destinationObject);
                toolRunner.arg("/Dest:" + destStorageAccount.blobEndpoint + destinationObject);
                toolRunner.arg("/DestKey:" + destStorageAccount.key);
            } else {
                toolRunner.arg("/Dest:" + destinationPath);
            }

            if (recursive) {
                toolRunner.arg("/S");
            }

            if (pattern) {
                toolRunner.arg("/Pattern:" + pattern);
            }

            if (excludeNewer) {
                toolRunner.arg("/XN");
            }

            if (excludeOlder) {
                toolRunner.arg("/XO");
            }

            if (additionalArguments) {
                toolRunner.line(additionalArguments);
            }

            toolRunner.arg("/Y");

            const result: number = await toolRunner.exec();
            if (result) {
                tl.setResult(tl.TaskResult.Failed, "An error occured during azcopy");
            } else {
                tl.setResult(tl.TaskResult.Succeeded, "Files copied successfully");
            }
        } else {
            tl.setResult(
                tl.TaskResult.Failed,
                "AzCopy utility was not found, please refer to documentation for installation instructions.");
        }
    } catch (err) {
        tl.debug(err.stack);
        tl.setResult(tl.TaskResult.Failed, err);
    }
})();

interface ICachedSubscriptionCredentals {
    name: string;
    id: string;
    creds: any;
}

interface IStorageAccount {
    resourceGroupName: string;
    blobEndpoint: string;
    tableEndpoint: string;
    key: string;
}
