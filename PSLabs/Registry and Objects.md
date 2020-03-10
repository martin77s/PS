# PSLab: Registry and Objects

### Uninstall information (appwiz.cpl) is located under:

HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\\*
HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\\*

### Function expected output:
```
Publisher                     DisplayName                                                    DisplayVersion      InstallDate
---------                     -----------                                                    --------------      -----------
Docker Inc.                   Docker Desktop                                                 2.2.0.3                        
The Git Development Community Git version 2.24.1.2                                           2.24.1.2            2020-01-13 
Mozilla                       Mozilla Firefox 72.0.2 (x64 en-US)                             72.0.2                         
Microsoft Corporation         Microsoft Office 365 ProPlus - en-us                           16.0.12527.20242               
VideoLAN                      VLC media player                                               3.0.8                          
Python Software Foundation    Python 3.7.1 Tcl/Tk Support (64-bit)                           3.7.1150.0          2018-12-06 
Intel Corporation             Intel(R) Wireless Manageability Driver Extension               1.0.0.0             2019-01-01 
Microsoft Corporation         Microsoft .NET Core AppHost Pack - 3.1.1 (x64_arm)             24.68.28408         2020-02-09 
Microsoft Corporation         Microsoft .NET Core SDK 2.2.401 (x64)                          8.100.26668         2019-08-29 
Oracle Corporation            MySQL Workbench 8.0 CE                                         8.0.19              2020-03-05 
Microsoft Corporation         Microsoft ASP.NET Core 3.1.1 Shared Framework (x64)            3.1.1.0             2020-02-09 
Microsoft Corporation         Microsoft Azure Compute Emulator - v2.9.6                      2.9.8899.26         2019-02-24 
Apple Inc.                    iTunes                                                         12.10.4.2           2020-02-02 
Google, Inc.                  Backup and Sync from Google                                    3.48.8668.1933      2020-01-25 
Adobe Systems Incorporated    Adobe AIR                                                      32.0.0.89                      
Realtek Semiconductor Corp.   Realtek High Definition Audio Driver                           6.0.8777.1          2019-10-15 
Microsoft Corporation         Microsoft .NET Framework 4.7.2 SDK                             4.7.03081           2018-12-06 

```

#### Bonus options: 
* Add a [string] FilterDisplayName parameter to the function
* Add a [version] FilterMiminumVersion parameter to the function