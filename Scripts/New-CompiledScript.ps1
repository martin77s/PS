function New-CompiledScript {

    param([string]$ScriptFilePath, [switch]$PassThru)

    $ExeFilePath = $ScriptFilePath -replace '\.ps1$', '.exe'
    $encodedCommand =  [System.Convert]::ToBase64String(
        [System.Text.Encoding]::Unicode.GetBytes((Get-Content -Path $ScriptFilePath -Raw)))

    Add-Type -OutputType ConsoleApplication -OutputAssembly $ExeFilePath -TypeDefinition @"
        using System;
        using System.Text;
        using System.Collections.ObjectModel;
        using System.Management.Automation;
        using System.Management.Automation.Runspaces;

        namespace $((Split-Path -Path $ExeFilePath -Leaf)-replace '\.exe') {
          internal class Program {
            private static void Main(string[] args) {
              string s = @"$($encodedCommand)";
              using (Runspace runspace = RunspaceFactory.CreateRunspace()) {
                runspace.Open();
                using (Pipeline pipeline = runspace.CreatePipeline()) {
                  string @string = Encoding.Unicode.GetString(Convert.FromBase64String(s));
                  pipeline.Commands.AddScript(@string);
                  pipeline.Commands.Add("Out-String");
                  Collection<PSObject> collection = pipeline.Invoke();
                  if (collection.Count <= 0) return;
                  StringBuilder stringBuilder = new StringBuilder();
                  foreach (PSObject psObject in collection)
                    stringBuilder.Append(psObject.BaseObject.ToString() + "\r\n");
                  Console.WriteLine(stringBuilder.ToString());
                }
              }
            }
          }
        }
"@
    if($PassThru) { Get-Item -Path $ExeFilePath }
}

New-CompiledScript -ScriptFilePath "C:\Code\IIS\PoshRSCA.ps1" -PassThru