import tl = require('vsts-task-lib/task');
import path = require('path');
import fs = require('fs-extra');
import q = require('q');
import XRegExp = require('xregexp');

var msRestAzure = require('ms-rest-azure');
var storageManagementClient = require('azure-arm-storage');

var recursive = tl.getBoolInput('Recursive');
var pattern = tl.getInput('Pattern');
var excludeNewer = tl.getBoolInput('ExcludeNewer');
var excludeOlder = tl.getBoolInput('ExcludeOlder');

var sourceKind = tl.getInput('SourceKind');

var sourcePath = tl.getInput('SourcePath');

var sourceConnectedServiceName = tl.getInput('SourceConnectedServiceName');
var sourceAccount = tl.getInput('SourceAccount');
var sourceObject = tl.getInput('SourceObject');

var destinationKind = tl.getInput('DestinationKind');

var destinationPath = tl.getInput('DestinationPath');

var destinationConnectedServiceName = tl.getInput('DestinationConnectedServiceName');
var destinationAccount = tl.getInput('DestinationAccount');
var destinationObject = tl.getInput('DestinationObject');

var programFiles = tl.getVariable('ProgramFiles(x86)');

var azCopyknownLocations = [
    path.join(__dirname, '../../azcopy.exe'),
    path.join(programFiles ? programFiles : 'C:\\ProgramFiles(x86)', 'Microsoft SDKs/Azure/AzCopy/azcopy.exe')
];

var azCopy = azCopyknownLocations.filter(x => fs.existsSync(x));
if (azCopy.length) {


    var toolRunner = tl.tool(azCopy[0]);

    q.when()
        .then(() => {
            if (sourceKind == "Storage") {
                return getConnectedServiceCredentials(sourceConnectedServiceName)
                    .then(credentials => {
                        return getStorageAccount(credentials, sourceAccount);
                    })
                    .then(storageAccount => {
                        toolRunner.arg('/Source:' + storageAccount.blobEndpoint + '/' + sourceObject);
                        toolRunner.arg('/SourceKey:' + storageAccount.key);
                    });
            } else {
                toolRunner.arg('/Source:' + sourcePath);
            }
        })
        .then(() => {
            if (destinationKind == "Storage") {
                return getConnectedServiceCredentials(destinationConnectedServiceName)
                    .then(credentials => {
                        return getStorageAccount(credentials, destinationAccount);
                    })
                    .then(storageAccount => {
                        toolRunner.arg('/Dest:' + storageAccount.blobEndpoint + '/' + destinationObject);
                        toolRunner.arg('/DestKey:' + storageAccount.key);
                    });
            } else {
                toolRunner.arg('/Dest:' + destinationPath);
            }
        })
        .then(() => {
            if (recursive) {
                toolRunner.arg('/S');
            }

            if (pattern) {
                toolRunner.arg('/Pattern:' + pattern);
            }

            if (excludeNewer) {
                toolRunner.arg('/XN');
            }

            if (excludeOlder) {
                toolRunner.arg('/XO');
            }
        })
        .then(() => toolRunner.exec())
        .then((result) => {
            if (result) {
                tl.setResult(tl.TaskResult.Failed, "An error occured during azcopy")
            } else {
                tl.setResult(tl.TaskResult.Succeeded, "Files copied successfully")
            }
        })
        .catch(err => {
            tl.setResult(tl.TaskResult.Failed, err);
        });
} else {
    tl.setResult(tl.TaskResult.Failed, "AzCopy utility was not found, please refer to documentation for installation instructions.")
}

interface ICachedSubscriptionCredentals {
    name: string, id: string, creds: any
}

var connectedServiceCredentialsCache: { [key: string]: ICachedSubscriptionCredentals } = {};
function getConnectedServiceCredentials(connectedService: string): q.Promise<any> {
    var endpointAuth = tl.getEndpointAuthorization(connectedService, true);
    var servicePrincipalId: string = endpointAuth.parameters["serviceprincipalid"];
    var servicePrincipalKey: string = endpointAuth.parameters["serviceprincipalkey"];
    var tenantId: string = endpointAuth.parameters["tenantid"];
    var subscriptionName: string = tl.getEndpointDataParameter(connectedService, "SubscriptionName", true);
    var subscriptionId: string = tl.getEndpointDataParameter(connectedService, "SubscriptionId", true);


    if (connectedServiceCredentialsCache[connectedService]) {
        return q.when(connectedServiceCredentialsCache[connectedService]);
    } else {
        var deferal = q.defer<any>();

        msRestAzure.loginWithServicePrincipalSecret(servicePrincipalId, servicePrincipalKey, tenantId, function (err: any, credentials: any) {
            if (err) {
                console.log(err);
                q.reject(err);
                return;
            }

            connectedServiceCredentialsCache[connectedService] = { name: subscriptionName, id: subscriptionId, creds: credentials };
            q.resolve(credentials);
        });

        return deferal.promise;
    }
}

var accountIdRegex = XRegExp('/subscriptions/(?<subscriptionId>.*?)/resourceGroups/(?<resourceGroupName>.*?)/providers/Microsoft.Storage/storageAccounts/(?<accountName>.*?)');

interface IStorageAccount {
    resourceGroupName: string,
    blobEndpoint: string,
    tableEndpoint: string,
    key: string
}

function getStorageAccount(credentials: ICachedSubscriptionCredentals, accountName: string)
    : q.Promise<IStorageAccount> {

    var deferal = q.defer<IStorageAccount>();

    var client = new storageManagementClient(credentials.creds, credentials.id);
    client.storageAccounts.list(function (err: any, result: any) {
        if (err) q.reject(err);
        console.log(result);
        var account = result.value.filter((x: any) => x.name == accountName)[0];

        var parsedAccountId = <any>XRegExp.exec(account.id, accountIdRegex);

        var resourceGroupName = parsedAccountId.resourceGroupName;

        client.storageAccounts.getProperties(resourceGroupName, accountName, function (err: any, properties: any) {
            if (err) {
                q.reject(err)
            } else {
                client.storageAccounts.listKeys(account.resourceGroupName, accountName, function (err: any, keys: any) {
                    if (err) {
                        q.reject(err)
                    } else {
                        q.resolve({
                            resourceGroupName: resourceGroupName,
                            blobEndpoint: properties.properties.primaryEndpoints.blob,
                            tableEndpoint: properties.properties.primaryEndpoints.table,
                            key: keys.keys[0].value
                        });
                    }
                });
            }
        });


    });

    return deferal.promise;
}


// var client = new someAzureServiceClient(credentials, 'your-subscriptionId');
// client.someOperationGroup.method(param1, param2, function (err, result) {
//     if (err) console.log(err);
//     console.log(result);
// });
