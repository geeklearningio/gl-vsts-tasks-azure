namespace GeekLearning.VstsTasks.Azure.Tests
{
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.PlatformAbstractions;
    using Options;
    using System;

    public class ConfigurationFixture : IDisposable
    {
        public ConfigurationFixture()
        {
            this.BasePath = PlatformServices.Default.Application.ApplicationBasePath;

            var builder = new ConfigurationBuilder()
                .SetBasePath(BasePath)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .AddJsonFile("appsettings.development.json", optional: true);

            this.Configuration = builder.Build();

            var services = new ServiceCollection();

            services.AddOptions();

            services.Configure<AzureAccountOptions>(Configuration.GetSection("AzureAccount"));
            services.Configure<SqlMultiDacpacDeploymentOptions>(Configuration.GetSection("SqlMultiDacpacDeployment"));

            this.Services = services.BuildServiceProvider();
        }

        public IConfigurationRoot Configuration { get; }

        public IServiceProvider Services { get; }

        public string BasePath { get; }

        public string VstsTaskSdkPath
        {
            get
            {
                return this.Configuration["VstsTaskSdkPath"];
            }
        }

        public string VstsTasksPath
        {
            get
            {
                return this.Configuration["VstsTasksPath"];
            }
        }

        public void Dispose()
        {
        }
    }
}
