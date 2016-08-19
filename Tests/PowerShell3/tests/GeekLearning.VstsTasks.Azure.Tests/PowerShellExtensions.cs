namespace GeekLearning.VstsTasks.Azure.Tests
{
    using System.Collections.Generic;
    using System.IO;
    using System.Management.Automation;
    using Xunit;
    using Xunit.Abstractions;

    public static class PowerShellExtensions
    {
        public static PowerShell ImportVstsTaskSdk(this PowerShell powerShell, string vstsTaskSdkPath)
        {
            powerShell
                .AddCommand("Import-Module")
                .AddArgument(vstsTaskSdkPath)
                .AddParameter("ArgumentList", new Dictionary<string, object> { { "NonInteractive", true } })
                .AddStatement();

            return powerShell;
        }

        public static PowerShell AddVstsInput(this PowerShell powerShell, string name, string value)
        {
            powerShell.AddEnvironmentVariable($"INPUT_{name}", value);
            return powerShell;
        }

        public static PowerShell AddVstsEndPoint(this PowerShell powerShell, string name, string url, string auth, string data)
        {
            powerShell.AddEnvironmentVariable($"ENDPOINT_URL_{name}", url);
            powerShell.AddEnvironmentVariable($"ENDPOINT_AUTH_{name}", auth);
            powerShell.AddEnvironmentVariable($"ENDPOINT_DATA_{name}", data);
            return powerShell;
        }

        public static PowerShell AddEnvironmentVariable(this PowerShell powerShell, string name, string value)
        {
            powerShell
                .AddScript($"${{env:{name}}} = '{value}'")
                .AddStatement();

            return powerShell;
        }

        public static PowerShell ExecuteVstsTask(this PowerShell powerShell, string vstsTasksPath, string taskName, ITestOutputHelper output)
        {
            var scriptPath = Path.Combine(vstsTasksPath, taskName, $"{taskName}.ps1");

            powerShell
                .AddCommand("Invoke-VstsTaskScript")
                .AddParameter("ScriptBlock", ScriptBlock.Create(". " + scriptPath))
                .AddParameter("Verbose")
                .AddParameter("Debug");

            var results = powerShell.Invoke();

            foreach (var outputItem in results)
            {
                if (outputItem != null)
                {
                    output.WriteLine(outputItem.BaseObject.GetType().FullName);
                    output.WriteLine(outputItem.BaseObject.ToString());
                }
            }

            foreach (var error in powerShell.Streams.Error)
            {
                output.WriteLine("[PowerShell] Error in cmdlet: " + error.Exception.Message);
            }

            foreach (var warning in powerShell.Streams.Warning)
            {
                output.WriteLine("[PowerShell] Warning: " + warning.Message);
            }

            //foreach (var information in powerShell.Streams.Information)
            //{
            //    output.WriteLine("[PowerShell] Information: " + information.ToString());
            //    System.Console.WriteLine("[PowerShell] Information: " + information.ToString());
            //}

            foreach (var verbose in powerShell.Streams.Verbose)
            {
                output.WriteLine("[PowerShell] Verbose: " + verbose.Message);
            }

            foreach (var debug in powerShell.Streams.Debug)
            {
                output.WriteLine("[PowerShell] Debug: " + debug.Message);
            }

            return powerShell;
        }
    }
}
