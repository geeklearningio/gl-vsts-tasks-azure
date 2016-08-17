namespace GeekLearning.VstsTasks.Azure.Tests
{
    using System;
    using Xunit;
    using System.Collections.ObjectModel;
    using System.IO;
    using System.Collections.Generic;
    using Microsoft.Extensions.PlatformAbstractions;
    using System.Management.Automation.Runspaces;
    using System.Management.Automation;
    using System.Management.Automation.Host;
    using Xunit.Abstractions;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Options;
    using Options;

    [Collection(nameof(UnitTestsCollection))]
    [Trait("Task", "SqlMultiDacpacDeployment")]
    public class SqlMultiDacpacDeploymentTests
    {
        private readonly ITestOutputHelper output;
        private readonly ConfigurationFixture configurationFixture;

        public SqlMultiDacpacDeploymentTests(ITestOutputHelper output, ConfigurationFixture configurationFixture)
        {
            this.output = output;
            this.configurationFixture = configurationFixture;
        }

        [Fact]
        public void SqlMultiDacpacDeploymentTest() 
        {
            var azureAccountOptions = this.configurationFixture.Services.GetRequiredService<IOptions<AzureAccountOptions>>();
            var sqlMultiDacpacDeploymentOptions = this.configurationFixture.Services.GetRequiredService<IOptions<SqlMultiDacpacDeploymentOptions>>();

            using (var powerShell = PowerShell.Create())
            {
                powerShell.ImportVstsTaskSdk(this.configurationFixture.VstsTaskSdkPath);
                azureAccountOptions.Value.PopulateAzureAccountEndpoint(powerShell);

                sqlMultiDacpacDeploymentOptions.Value.PopulateInputs(powerShell);
                powerShell.ExecuteVstsTask(this.configurationFixture.VstsTasksPath, "SqlMultiDacpacDeployment", this.output);

                Assert.True(!powerShell.HadErrors);
            }
        }
    }
}
