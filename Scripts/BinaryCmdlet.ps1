# C# definition for cmdlet                
$code = @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Text;
using System.Management.Automation;

namespace CustomCmdlet
{
    [Cmdlet("Get", "Magic", SupportsTransactions = false)]
    public class test : PSCmdlet
    {
        private int _Age;

        [Alias(new string[] { "HowOld", "YourAge" }),
        Parameter(Position = 0,ValueFromPipeline = true)]
        
        public int Age
        {
            get { return _Age; }
            set { _Age = value; }
        }

        private string _Name;

        [Parameter(Position = 1)]
        public string Name
        {
            get { return _Name; }
            set { _Name = value; }
        }


        protected override void BeginProcessing()
        {
            this.WriteObject("Good morning...");
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            this.WriteObject("Your name is " + Name + " and your age is " + Age);
            base.ProcessRecord();
        }

        protected override void EndProcessing()
        {
            this.WriteObject("That's it for now.");
            base.EndProcessing();
        }
    }
}

'@


# compile the C# code to a DLL
$myCmdletDLL = '{0}\myCmdlet_{1:yyyyMMddHHmmss}.dll' -f $env:TEMP, (Get-Date)
Add-Type -TypeDefinition $code -OutputAssembly $myCmdletDLL

# import the module
Import-Module -Name $myCmdletDLL -Verbose
