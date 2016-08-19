namespace GeekLearning.VstsTasks.Azure.Tests.Options
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Management.Automation;
    using System.Threading.Tasks;

    public class SqlMultiDacpacDeploymentOptions
    {
        public string DacpacFiles { get; set; }

        public string AdditionalArguments { get; set; }

        public string ServerName { get; set; }

        public string DatabaseName { get; set; }

        public string SqlUsername { get; set; }

        public string SqlPassword { get; set; }

        public string IpDetectionMethod { get; set; }

        public bool DeleteFirewallRule { get; set; }

        public void PopulateInputs(PowerShell powerShell)
        {
            powerShell.AddVstsInput(nameof(DacpacFiles), this.DacpacFiles);
            powerShell.AddVstsInput(nameof(AdditionalArguments), this.AdditionalArguments);
            powerShell.AddVstsInput(nameof(ServerName), this.ServerName);
            powerShell.AddVstsInput(nameof(DatabaseName), this.DatabaseName);
            powerShell.AddVstsInput(nameof(SqlUsername), this.SqlUsername);
            powerShell.AddVstsInput(nameof(SqlPassword), this.SqlPassword);
            powerShell.AddVstsInput(nameof(IpDetectionMethod), this.IpDetectionMethod);
            powerShell.AddVstsInput(nameof(DeleteFirewallRule), this.DeleteFirewallRule.ToString());
        }
    }
}
