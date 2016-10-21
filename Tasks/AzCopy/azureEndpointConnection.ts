import q = require('q');
var msRestAzure = require('ms-rest-azure');



var connectedServiceCredentialsCache: { [key: string]: ICachedSubscriptionCredentals } = {};

export function getConnectedServiceCredentials(
    connectedService: string,
    servicePrincipalId: string,
    servicePrincipalKey: string,
    tenantId: string,
    subscriptionName: string,
    subscriptionId: string): q.Promise<ICachedSubscriptionCredentals> {


    if (connectedServiceCredentialsCache[connectedService]) {
        return q.when(connectedServiceCredentialsCache[connectedService]);
    } else {
        var deferal = q.defer<ICachedSubscriptionCredentals>();
        // console.log(msRestAzure);
        // console.log(msRestAzure.loginWithServicePrincipalSecret);

        //var credentials = new msRestAzure.ApplicationTokenCredentials(servicePrincipalId, tenantId, servicePrincipalKey);

        // connectedServiceCredentialsCache[connectedService] = { name: subscriptionName, id: subscriptionId, creds: credentials };
        // return q.resolve(credentials);
        msRestAzure.loginWithServicePrincipalSecret(servicePrincipalId, servicePrincipalKey, tenantId, {}, function (err: any, credentials: any) {
            if (err) {
                console.log(err);
                deferal.reject(err);
                return;
            }

            var result = connectedServiceCredentialsCache[connectedService] = { name: subscriptionName, id: subscriptionId, creds: credentials };
            deferal.resolve(result);

        });

        return deferal.promise;
    }
}

export interface ICachedSubscriptionCredentals {
    name: string, id: string, creds: any
}
