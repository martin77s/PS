configuration PullServer {
    param (
            [string[]]$NodeName = 'localhost',

            [ValidateNotNullOrEmpty()]
            [string] $certificateThumbPrint,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string] $RegistrationKey
     )

     Import-DSCResource -ModuleName xPSDesiredStateConfiguration, PSDesiredStateConfiguration

     Node $NodeName  {

         WindowsFeature DSCServiceFeature  {
             Ensure = 'Present'
             Name   = 'DSC-Service'
         }

         xDscWebService PSDSCPullServer  {
             Ensure                   = 'Present'
             EndpointName             = 'PSDSCPullServer'
             Port                     = 8080
             PhysicalPath             = "$env:SystemDrive\inetpub\PSDSCPullServer"
             CertificateThumbPrint    = $certificateThumbPrint
             ModulePath               = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
             ConfigurationPath        = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
             State                    = 'Started'
             DependsOn                = '[WindowsFeature]DSCServiceFeature'
             UseSecurityBestPractices = $false
            # DisableSecurityBestPractices = 'SecureTLSProtocols'
         }

        File RegistrationKeyFile {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}


# To find the Thumbprint for an installed SSL certificate for use with the pull server list all certifcates in your local store
# and then copy the thumbprint for the appropriate certificate by reviewing the certificate subjects
$certThumbprint = (dir Cert:\LocalMachine\my -SSLServerAuthentication)[0].Thumbprint

# Generate a registration key to be saved in the RegistrationKeys.txt in C:\Program Files\WindowsPowerShell\DscService.
$registrationKey = (New-Guid).Guid

# Then include this thumbprint when running the configuration
PullServer -certificateThumbprint $certThumbprint -RegistrationKey $registrationKey -OutputPath C:\Configs\PullServer

# Run the compiled configuration to make the target node a DSC Pull Server
Start-DscConfiguration -Path C:\Configs\PullServer -Wait -Verbose
