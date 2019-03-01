import msRestAzure = require("ms-rest-azure");
import q = require("q");

const connectedServiceCredentialsCache: { [key: string]: ICachedSubscriptionCredentals } = {};

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
        const deferal = q.defer<ICachedSubscriptionCredentals>();
        msRestAzure.loginWithServicePrincipalSecret(
            servicePrincipalId,
            servicePrincipalKey,
            tenantId,
            {}, (err: any, credentials: any) => {
                if (err) {
                    deferal.reject(err);
                    return;
                }

                const result = connectedServiceCredentialsCache[connectedService] = {
                    creds: credentials,
                    id: subscriptionId,
                    name: subscriptionName,
                };

                deferal.resolve(result);
            });

        return deferal.promise;
    }
}

export interface ICachedSubscriptionCredentals {
    name: string;
    id: string;
    creds: any;
}
