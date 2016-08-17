namespace GeekLearning.VstsTasks.Azure.Tests.Options
{
    using Newtonsoft.Json.Linq;
    using System;
    using System.Management.Automation;

    public class AzureAccountOptions
    {
        private const string EndPointUrl = "https://management.core.windows.net/";

        public Guid EndPointName { get; } = Guid.NewGuid();

        public string ConnectionName { get; set; }

        public string SubscriptionId { get; set; }

        public string SubscriptionName { get; set; }

        public string ServicePrincipalClientId { get; set; }

        public string ServicePrincipalKey { get; set; }

        public string TenantId { get; set; }

        private string EndPointAuth
        {
            get
            {
                return JObject.FromObject(new
                {
                    scheme = "ServicePrincipal",
                    parameters = new
                    {
                        servicePrincipalId = this.ServicePrincipalClientId,
                        servicePrincipalKey = this.ServicePrincipalKey,
                        tenantId = this.TenantId
                    }
                }).ToString();
            }
        }

        private string EndPointData
        {
            get
            {
                return JObject.FromObject(new
                {
                    subscriptionId = this.SubscriptionId,
                    subscriptionName = this.SubscriptionName,
                    azureSpnRoleAssignmentId = string.Empty,
                    spnObjectId = string.Empty,
                    appObjectId = string.Empty,
                    creationMode = "Manual"
                }).ToString();
            }
        }

        public void PopulateAzureAccountEndpoint(PowerShell powerShell, string inputName = "ConnectedServiceName")
        {
            powerShell.AddVstsInput(inputName, this.EndPointName.ToString());
            powerShell.AddVstsEndPoint(
                this.EndPointName.ToString(),
                EndPointUrl,
                this.EndPointAuth,
                this.EndPointData);
        }
    }
}
