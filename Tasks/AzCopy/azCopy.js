"use strict";
var tl = require('vsts-task-lib/task');
var path = require('path');
var q = require('q');
var XRegExp = require('xregexp');
var msRestAzure = require('ms-rest-azure');
var storageManagementClient = require('azure-arm-storage');
var recursive = tl.getBoolInput('Recursive');
var pattern = tl.getInput('Pattern');
var excludeNewer = tl.getBoolInput('ExcludeNewer');
var excludeOlder = tl.getBoolInput('ExcludeOlder');
var sourceKind = tl.getInput('SourceKind');
var sourcePath = tl.getInput('SourcePath');
var sourceConnectedServiceName = tl.getInput('SourceConnectedServiceName');
var sourceAccount = tl.getInput('Sourc eAccount');
var sourceObject = tl.getInput('SourceObject');
var destinationKind = tl.getInput('DestinationKind');
var destinationPath = tl.getInput('DestinationPath');
var destinationConnectedServiceName = tl.getInput('DestinationConnectedServiceName');
var destinationAccount = tl.getInput('DestinationAccount');
var destinationObject = tl.getInput('DestinationObject');
var toolRunner = tl.createToolRunner(path.join(tl.getVariable('%ProgramFiles(x86)%'), 'Microsoft SDKs/Azure/AzCopy/azcopy.exe'));
q.when()
    .then(function () {
    if (sourceKind == "Storage") {
        return getConnectedServiceCredentials(sourceConnectedServiceName)
            .then(function (credentials) {
            return getStorageAccount(credentials, sourceAccount);
        })
            .then(function (storageAccount) {
            toolRunner.arg('/Source:' + storageAccount.blobEndpoint + '/' + sourceObject);
            toolRunner.arg('/SourceKey:' + storageAccount.key);
        });
    }
    else {
        toolRunner.arg('/Source:' + sourcePath);
    }
})
    .then(function () {
    if (destinationKind == "Storage") {
        return getConnectedServiceCredentials(destinationConnectedServiceName)
            .then(function (credentials) {
            return getStorageAccount(credentials, destinationAccount);
        })
            .then(function (storageAccount) {
            toolRunner.arg('/Dest:' + storageAccount.blobEndpoint + '/' + destinationObject);
            toolRunner.arg('/DestKey:' + storageAccount.key);
        });
    }
    else {
        toolRunner.arg('/Dest:' + destinationPath);
    }
})
    .then(function () {
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
    .then(function () { return toolRunner.exec(); })
    .then(function (result) {
    if (result) {
        tl.setResult(tl.TaskResult.Failed, "An error occured during azcopy");
    }
    else {
        tl.setResult(tl.TaskResult.Succeeded, "Files copied successfully");
    }
})
    .catch(function (err) {
    tl.setResult(tl.TaskResult.Failed, err);
});
var connectedServiceCredentialsCache = {};
function getConnectedServiceCredentials(connectedService) {
    var endpointAuth = tl.getEndpointAuthorization(connectedService, true);
    var servicePrincipalId = endpointAuth.parameters["serviceprincipalid"];
    var servicePrincipalKey = endpointAuth.parameters["serviceprincipalkey"];
    var tenantId = endpointAuth.parameters["tenantid"];
    var subscriptionName = tl.getEndpointDataParameter(connectedService, "SubscriptionName", true);
    var subscriptionId = tl.getEndpointDataParameter(connectedService, "SubscriptionId", true);
    if (connectedServiceCredentialsCache[connectedService]) {
        return q.when(connectedServiceCredentialsCache[connectedService]);
    }
    else {
        var deferal = q.defer();
        msRestAzure.loginWithServicePrincipalSecret(servicePrincipalId, servicePrincipalKey, tenantId, function (err, credentials) {
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
function getStorageAccount(credentials, accountName) {
    var deferal = q.defer();
    var client = new storageManagementClient(credentials.creds, credentials.id);
    client.storageAccounts.list(function (err, result) {
        if (err)
            q.reject(err);
        console.log(result);
        var account = result.value.filter(function (x) { return x.name == accountName; })[0];
        var parsedAccountId = XRegExp.exec(account.id, accountIdRegex);
        var resourceGroupName = parsedAccountId.resourceGroupName;
        client.storageAccounts.getProperties(resourceGroupName, accountName, function (err, properties) {
            if (err) {
                q.reject(err);
            }
            else {
                client.storageAccounts.listKeys(account.resourceGroupName, accountName, function (err, keys) {
                    if (err) {
                        q.reject(err);
                    }
                    else {
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
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiYXpDb3B5LmpzIiwic291cmNlUm9vdCI6IiIsInNvdXJjZXMiOlsiYXpDb3B5LnRzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiI7QUFBQSxJQUFPLEVBQUUsV0FBVyxvQkFBb0IsQ0FBQyxDQUFDO0FBQzFDLElBQU8sSUFBSSxXQUFXLE1BQU0sQ0FBQyxDQUFDO0FBQzlCLElBQU8sQ0FBQyxXQUFXLEdBQUcsQ0FBQyxDQUFDO0FBQ3hCLElBQU8sT0FBTyxXQUFXLFNBQVMsQ0FBQyxDQUFDO0FBRXBDLElBQUksV0FBVyxHQUFHLE9BQU8sQ0FBQyxlQUFlLENBQUMsQ0FBQztBQUMzQyxJQUFJLHVCQUF1QixHQUFHLE9BQU8sQ0FBQyxtQkFBbUIsQ0FBQyxDQUFDO0FBRTNELElBQUksU0FBUyxHQUFHLEVBQUUsQ0FBQyxZQUFZLENBQUMsV0FBVyxDQUFDLENBQUM7QUFDN0MsSUFBSSxPQUFPLEdBQUcsRUFBRSxDQUFDLFFBQVEsQ0FBQyxTQUFTLENBQUMsQ0FBQztBQUNyQyxJQUFJLFlBQVksR0FBRyxFQUFFLENBQUMsWUFBWSxDQUFDLGNBQWMsQ0FBQyxDQUFDO0FBQ25ELElBQUksWUFBWSxHQUFHLEVBQUUsQ0FBQyxZQUFZLENBQUMsY0FBYyxDQUFDLENBQUM7QUFFbkQsSUFBSSxVQUFVLEdBQUcsRUFBRSxDQUFDLFFBQVEsQ0FBQyxZQUFZLENBQUMsQ0FBQztBQUUzQyxJQUFJLFVBQVUsR0FBRyxFQUFFLENBQUMsUUFBUSxDQUFDLFlBQVksQ0FBQyxDQUFDO0FBRTNDLElBQUksMEJBQTBCLEdBQUcsRUFBRSxDQUFDLFFBQVEsQ0FBQyw0QkFBNEIsQ0FBQyxDQUFDO0FBQzNFLElBQUksYUFBYSxHQUFHLEVBQUUsQ0FBQyxRQUFRLENBQUMsZ0JBQWdCLENBQUMsQ0FBQztBQUNsRCxJQUFJLFlBQVksR0FBRyxFQUFFLENBQUMsUUFBUSxDQUFDLGNBQWMsQ0FBQyxDQUFDO0FBRS9DLElBQUksZUFBZSxHQUFHLEVBQUUsQ0FBQyxRQUFRLENBQUMsaUJBQWlCLENBQUMsQ0FBQztBQUVyRCxJQUFJLGVBQWUsR0FBRyxFQUFFLENBQUMsUUFBUSxDQUFDLGlCQUFpQixDQUFDLENBQUM7QUFFckQsSUFBSSwrQkFBK0IsR0FBRyxFQUFFLENBQUMsUUFBUSxDQUFDLGlDQUFpQyxDQUFDLENBQUM7QUFDckYsSUFBSSxrQkFBa0IsR0FBRyxFQUFFLENBQUMsUUFBUSxDQUFDLG9CQUFvQixDQUFDLENBQUM7QUFDM0QsSUFBSSxpQkFBaUIsR0FBRyxFQUFFLENBQUMsUUFBUSxDQUFDLG1CQUFtQixDQUFDLENBQUM7QUFFekQsSUFBSSxVQUFVLEdBQUcsRUFBRSxDQUFDLGdCQUFnQixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsRUFBRSxDQUFDLFdBQVcsQ0FBQyxxQkFBcUIsQ0FBQyxFQUFFLHdDQUF3QyxDQUFDLENBQUMsQ0FBQztBQUVqSSxDQUFDLENBQUMsSUFBSSxFQUFFO0tBQ0gsSUFBSSxDQUFDO0lBQ0YsRUFBRSxDQUFDLENBQUMsVUFBVSxJQUFJLFNBQVMsQ0FBQyxDQUFDLENBQUM7UUFDMUIsTUFBTSxDQUFDLDhCQUE4QixDQUFDLDBCQUEwQixDQUFDO2FBQzVELElBQUksQ0FBQyxVQUFBLFdBQVc7WUFDYixNQUFNLENBQUMsaUJBQWlCLENBQUMsV0FBVyxFQUFFLGFBQWEsQ0FBQyxDQUFDO1FBQ3pELENBQUMsQ0FBQzthQUNELElBQUksQ0FBQyxVQUFBLGNBQWM7WUFDaEIsVUFBVSxDQUFDLEdBQUcsQ0FBQyxVQUFVLEdBQUcsY0FBYyxDQUFDLFlBQVksR0FBRyxHQUFHLEdBQUcsWUFBWSxDQUFDLENBQUM7WUFDOUUsVUFBVSxDQUFDLEdBQUcsQ0FBQyxhQUFhLEdBQUcsY0FBYyxDQUFDLEdBQUcsQ0FBQyxDQUFDO1FBQ3ZELENBQUMsQ0FBQyxDQUFDO0lBQ1gsQ0FBQztJQUFDLElBQUksQ0FBQyxDQUFDO1FBQ0osVUFBVSxDQUFDLEdBQUcsQ0FBQyxVQUFVLEdBQUcsVUFBVSxDQUFDLENBQUM7SUFDNUMsQ0FBQztBQUNMLENBQUMsQ0FBQztLQUNELElBQUksQ0FBQztJQUNGLEVBQUUsQ0FBQyxDQUFDLGVBQWUsSUFBSSxTQUFTLENBQUMsQ0FBQyxDQUFDO1FBQy9CLE1BQU0sQ0FBQyw4QkFBOEIsQ0FBQywrQkFBK0IsQ0FBQzthQUNqRSxJQUFJLENBQUMsVUFBQSxXQUFXO1lBQ2IsTUFBTSxDQUFDLGlCQUFpQixDQUFDLFdBQVcsRUFBRSxrQkFBa0IsQ0FBQyxDQUFDO1FBQzlELENBQUMsQ0FBQzthQUNELElBQUksQ0FBQyxVQUFBLGNBQWM7WUFDaEIsVUFBVSxDQUFDLEdBQUcsQ0FBQyxRQUFRLEdBQUcsY0FBYyxDQUFDLFlBQVksR0FBRyxHQUFHLEdBQUcsaUJBQWlCLENBQUMsQ0FBQztZQUNqRixVQUFVLENBQUMsR0FBRyxDQUFDLFdBQVcsR0FBRyxjQUFjLENBQUMsR0FBRyxDQUFDLENBQUM7UUFDckQsQ0FBQyxDQUFDLENBQUM7SUFDWCxDQUFDO0lBQUMsSUFBSSxDQUFDLENBQUM7UUFDSixVQUFVLENBQUMsR0FBRyxDQUFDLFFBQVEsR0FBRyxlQUFlLENBQUMsQ0FBQztJQUMvQyxDQUFDO0FBQ0wsQ0FBQyxDQUFDO0tBQ0QsSUFBSSxDQUFDO0lBQ0YsRUFBRSxDQUFDLENBQUMsU0FBUyxDQUFDLENBQUMsQ0FBQztRQUNaLFVBQVUsQ0FBQyxHQUFHLENBQUMsSUFBSSxDQUFDLENBQUM7SUFDekIsQ0FBQztJQUVELEVBQUUsQ0FBQyxDQUFDLE9BQU8sQ0FBQyxDQUFDLENBQUM7UUFDVixVQUFVLENBQUMsR0FBRyxDQUFDLFdBQVcsR0FBRyxPQUFPLENBQUMsQ0FBQztJQUMxQyxDQUFDO0lBRUQsRUFBRSxDQUFDLENBQUMsWUFBWSxDQUFDLENBQUMsQ0FBQztRQUNmLFVBQVUsQ0FBQyxHQUFHLENBQUMsS0FBSyxDQUFDLENBQUM7SUFDMUIsQ0FBQztJQUVELEVBQUUsQ0FBQyxDQUFDLFlBQVksQ0FBQyxDQUFDLENBQUM7UUFDZixVQUFVLENBQUMsR0FBRyxDQUFDLEtBQUssQ0FBQyxDQUFDO0lBQzFCLENBQUM7QUFDTCxDQUFDLENBQUM7S0FDRCxJQUFJLENBQUMsY0FBTSxPQUFBLFVBQVUsQ0FBQyxJQUFJLEVBQUUsRUFBakIsQ0FBaUIsQ0FBQztLQUM3QixJQUFJLENBQUMsVUFBQyxNQUFNO0lBQ1QsRUFBRSxDQUFDLENBQUMsTUFBTSxDQUFDLENBQUMsQ0FBQztRQUNULEVBQUUsQ0FBQyxTQUFTLENBQUMsRUFBRSxDQUFDLFVBQVUsQ0FBQyxNQUFNLEVBQUUsZ0NBQWdDLENBQUMsQ0FBQTtJQUN4RSxDQUFDO0lBQUMsSUFBSSxDQUFDLENBQUM7UUFDSixFQUFFLENBQUMsU0FBUyxDQUFDLEVBQUUsQ0FBQyxVQUFVLENBQUMsU0FBUyxFQUFFLDJCQUEyQixDQUFDLENBQUE7SUFDdEUsQ0FBQztBQUNMLENBQUMsQ0FBQztLQUNELEtBQUssQ0FBQyxVQUFBLEdBQUc7SUFDTixFQUFFLENBQUMsU0FBUyxDQUFDLEVBQUUsQ0FBQyxVQUFVLENBQUMsTUFBTSxFQUFFLEdBQUcsQ0FBQyxDQUFDO0FBQzVDLENBQUMsQ0FBQyxDQUFDO0FBTVAsSUFBSSxnQ0FBZ0MsR0FBcUQsRUFBRSxDQUFDO0FBQzVGLHdDQUF3QyxnQkFBd0I7SUFDNUQsSUFBSSxZQUFZLEdBQUcsRUFBRSxDQUFDLHdCQUF3QixDQUFDLGdCQUFnQixFQUFFLElBQUksQ0FBQyxDQUFDO0lBQ3ZFLElBQUksa0JBQWtCLEdBQVcsWUFBWSxDQUFDLFVBQVUsQ0FBQyxvQkFBb0IsQ0FBQyxDQUFDO0lBQy9FLElBQUksbUJBQW1CLEdBQVcsWUFBWSxDQUFDLFVBQVUsQ0FBQyxxQkFBcUIsQ0FBQyxDQUFDO0lBQ2pGLElBQUksUUFBUSxHQUFXLFlBQVksQ0FBQyxVQUFVLENBQUMsVUFBVSxDQUFDLENBQUM7SUFDM0QsSUFBSSxnQkFBZ0IsR0FBVyxFQUFFLENBQUMsd0JBQXdCLENBQUMsZ0JBQWdCLEVBQUUsa0JBQWtCLEVBQUUsSUFBSSxDQUFDLENBQUM7SUFDdkcsSUFBSSxjQUFjLEdBQVcsRUFBRSxDQUFDLHdCQUF3QixDQUFDLGdCQUFnQixFQUFFLGdCQUFnQixFQUFFLElBQUksQ0FBQyxDQUFDO0lBR25HLEVBQUUsQ0FBQyxDQUFDLGdDQUFnQyxDQUFDLGdCQUFnQixDQUFDLENBQUMsQ0FBQyxDQUFDO1FBQ3JELE1BQU0sQ0FBQyxDQUFDLENBQUMsSUFBSSxDQUFDLGdDQUFnQyxDQUFDLGdCQUFnQixDQUFDLENBQUMsQ0FBQztJQUN0RSxDQUFDO0lBQUMsSUFBSSxDQUFDLENBQUM7UUFDSixJQUFJLE9BQU8sR0FBRyxDQUFDLENBQUMsS0FBSyxFQUFPLENBQUM7UUFFN0IsV0FBVyxDQUFDLCtCQUErQixDQUFDLGtCQUFrQixFQUFFLG1CQUFtQixFQUFFLFFBQVEsRUFBRSxVQUFVLEdBQVEsRUFBRSxXQUFnQjtZQUMvSCxFQUFFLENBQUMsQ0FBQyxHQUFHLENBQUMsQ0FBQyxDQUFDO2dCQUNOLE9BQU8sQ0FBQyxHQUFHLENBQUMsR0FBRyxDQUFDLENBQUM7Z0JBQ2pCLENBQUMsQ0FBQyxNQUFNLENBQUMsR0FBRyxDQUFDLENBQUM7Z0JBQ2QsTUFBTSxDQUFDO1lBQ1gsQ0FBQztZQUVELGdDQUFnQyxDQUFDLGdCQUFnQixDQUFDLEdBQUcsRUFBRSxJQUFJLEVBQUUsZ0JBQWdCLEVBQUUsRUFBRSxFQUFFLGNBQWMsRUFBRSxLQUFLLEVBQUUsV0FBVyxFQUFFLENBQUM7WUFDeEgsQ0FBQyxDQUFDLE9BQU8sQ0FBQyxXQUFXLENBQUMsQ0FBQztRQUMzQixDQUFDLENBQUMsQ0FBQztRQUVILE1BQU0sQ0FBQyxPQUFPLENBQUMsT0FBTyxDQUFDO0lBQzNCLENBQUM7QUFDTCxDQUFDO0FBRUQsSUFBSSxjQUFjLEdBQUcsT0FBTyxDQUFDLGdKQUFnSixDQUFDLENBQUM7QUFTL0ssMkJBQTJCLFdBQTBDLEVBQUUsV0FBbUI7SUFHdEYsSUFBSSxPQUFPLEdBQUcsQ0FBQyxDQUFDLEtBQUssRUFBbUIsQ0FBQztJQUV6QyxJQUFJLE1BQU0sR0FBRyxJQUFJLHVCQUF1QixDQUFDLFdBQVcsQ0FBQyxLQUFLLEVBQUUsV0FBVyxDQUFDLEVBQUUsQ0FBQyxDQUFDO0lBQzVFLE1BQU0sQ0FBQyxlQUFlLENBQUMsSUFBSSxDQUFDLFVBQVUsR0FBUSxFQUFFLE1BQVc7UUFDdkQsRUFBRSxDQUFDLENBQUMsR0FBRyxDQUFDO1lBQUMsQ0FBQyxDQUFDLE1BQU0sQ0FBQyxHQUFHLENBQUMsQ0FBQztRQUN2QixPQUFPLENBQUMsR0FBRyxDQUFDLE1BQU0sQ0FBQyxDQUFDO1FBQ3BCLElBQUksT0FBTyxHQUFHLE1BQU0sQ0FBQyxLQUFLLENBQUMsTUFBTSxDQUFDLFVBQUMsQ0FBTSxJQUFLLE9BQUEsQ0FBQyxDQUFDLElBQUksSUFBSSxXQUFXLEVBQXJCLENBQXFCLENBQUMsQ0FBQyxDQUFDLENBQUMsQ0FBQztRQUV4RSxJQUFJLGVBQWUsR0FBUSxPQUFPLENBQUMsSUFBSSxDQUFDLE9BQU8sQ0FBQyxFQUFFLEVBQUUsY0FBYyxDQUFDLENBQUM7UUFFcEUsSUFBSSxpQkFBaUIsR0FBRyxlQUFlLENBQUMsaUJBQWlCLENBQUM7UUFFMUQsTUFBTSxDQUFDLGVBQWUsQ0FBQyxhQUFhLENBQUMsaUJBQWlCLEVBQUUsV0FBVyxFQUFFLFVBQVUsR0FBUSxFQUFFLFVBQWU7WUFDcEcsRUFBRSxDQUFDLENBQUMsR0FBRyxDQUFDLENBQUMsQ0FBQztnQkFDTixDQUFDLENBQUMsTUFBTSxDQUFDLEdBQUcsQ0FBQyxDQUFBO1lBQ2pCLENBQUM7WUFBQyxJQUFJLENBQUMsQ0FBQztnQkFDSixNQUFNLENBQUMsZUFBZSxDQUFDLFFBQVEsQ0FBQyxPQUFPLENBQUMsaUJBQWlCLEVBQUUsV0FBVyxFQUFFLFVBQVUsR0FBUSxFQUFFLElBQVM7b0JBQ2pHLEVBQUUsQ0FBQyxDQUFDLEdBQUcsQ0FBQyxDQUFDLENBQUM7d0JBQ04sQ0FBQyxDQUFDLE1BQU0sQ0FBQyxHQUFHLENBQUMsQ0FBQTtvQkFDakIsQ0FBQztvQkFBQyxJQUFJLENBQUMsQ0FBQzt3QkFDSixDQUFDLENBQUMsT0FBTyxDQUFDOzRCQUNOLGlCQUFpQixFQUFFLGlCQUFpQjs0QkFDcEMsWUFBWSxFQUFFLFVBQVUsQ0FBQyxVQUFVLENBQUMsZ0JBQWdCLENBQUMsSUFBSTs0QkFDekQsYUFBYSxFQUFFLFVBQVUsQ0FBQyxVQUFVLENBQUMsZ0JBQWdCLENBQUMsS0FBSzs0QkFDM0QsR0FBRyxFQUFFLElBQUksQ0FBQyxJQUFJLENBQUMsQ0FBQyxDQUFDLENBQUMsS0FBSzt5QkFDMUIsQ0FBQyxDQUFDO29CQUNQLENBQUM7Z0JBQ0wsQ0FBQyxDQUFDLENBQUM7WUFDUCxDQUFDO1FBQ0wsQ0FBQyxDQUFDLENBQUM7SUFHUCxDQUFDLENBQUMsQ0FBQztJQUVILE1BQU0sQ0FBQyxPQUFPLENBQUMsT0FBTyxDQUFDO0FBQzNCLENBQUMifQ==