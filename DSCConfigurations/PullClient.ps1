[DSCLocalConfigurationManager()]
configuration PullClient {

    PARAM(
        [string] $PullServer,
        [string] $RegistrationKey,
        [string[]] $ConfigurationNames
    )

    node localhost {

        Settings {
            RefreshMode          = 'Pull'
            RefreshFrequencyMins = 30
            RebootNodeIfNeeded   = $true
        }

        ConfigurationRepositoryWeb CONTOSO-PullSrv {
            ServerURL          = "https://$PullServer/PSDSCPullServer.svc"
            RegistrationKey    = $RegistrationKey
            ConfigurationNames = $ConfigurationNames
        }

        ReportServerWeb CONTOSO-PullSrv {
            ServerURL       = 'https://$PullServer/PSDSCPullServer.svc'
            RegistrationKey = $RegistrationKey
        }
    }
}

PullClient -OutputPath C:\Configs\TargetNodes -PullServer 'CONTOSO-PullSrv:8080' `
    RegistrationKey '140a952b-b9d6-406b-b416-e0f759c9c0e4' -ConfigurationNames @('ClientConfig')