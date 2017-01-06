import fs = require('fs');
import path = require('path');
import azureEndpointConnection = require('../../../Tasks/AzCopy/azureEndpointConnection');

var settings = JSON.parse(fs.readFileSync(path.join(__dirname, '../settings.json'), 'utf-8'));

var computeDigest = new Buffer("pat:" + settings.vsts.pat).toString('base64');
var auhtorizationHeader = "Basic " + computeDigest;

describe("AzureEndpointConnection", () => {

    it(": should support basic add.", (done: any) => {
        try {
            azureEndpointConnection.getConnectedServiceCredentials(
                settings.azure.connectionName,
                settings.azure.servicePrincipalId,
                settings.azure.servicePrincipalkey,
                settings.azure.tenantId,
                settings.azure.subscriptionName,
                settings.azure.subscriptionId)
                .then((result) => {
                    console.log(result);
                    expect(result).toBeDefined();
                    expect(result.creds).toBeTruthy();
                    expect(result.id).toBeTruthy();
                    expect(result.name).toBeTruthy();
                    done();
                })
                .catch((err) => {
                    expect(err).toBeNull();
                    done();
                });
        }
        catch (err) {
            expect(err).toBeUndefined();
        }
    }, 60000);
});