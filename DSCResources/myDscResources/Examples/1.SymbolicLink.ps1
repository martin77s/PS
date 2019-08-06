
configuration Main {

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName NovaDscResources

    node localhost {

        SymbolicLink 'JOB_WORKING_DIR' {
            Path       = 'D:\JOB_WORKING_DIR'
            TargetPath = 'E:\MARS\JOB_WORKING_DIR'
        }

        SymbolicLink 'OTHER_DIR' {
            Path       = 'D:\OTHER_DIR'
            TargetPath = 'E:\MARS\OTHER_DIR'
        }
    }
}