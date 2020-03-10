# PSLab: WMI and WSMAN

### Function structure:

```
function Get-SharePermisionsReport {
    param(...
    # Hint: Win32_Share
}
```

### Function expected output:

```
ComputerName     ShareName      Path                 NTFS                                                                                    
------------     ---------      ----                 ----                                                                                    
MyRemotePC       AKADA          C:\Temp\AKADA        BUILTIN\Administrators = Allow,FullControl                                              
MyRemotePC       AKADA          C:\Temp\AKADA        NT AUTHORITY\SYSTEM = Allow,FullControl                                                 
MyRemotePC       AKADA          C:\Temp\AKADA        BUILTIN\Users = Allow,ReadAndExecute                                                    
MyRemotePC       AKADA          C:\Temp\AKADA        NT AUTHORITY\Authenticated Users = Allow,Modify                                         
MyRemotePC       AKADA          C:\Temp\AKADA        NT AUTHORITY\Authenticated Users = Allow,-536805376                                     
MyRemotePC       DriveC         C:\                  NT AUTHORITY\Authenticated Users = Allow,AppendData                                     
MyRemotePC       DriveC         C:\                  NT AUTHORITY\Authenticated Users = Allow,-536805376                                     
MyRemotePC       DriveC         C:\                  NT AUTHORITY\SYSTEM = Allow,FullControl                                                 
MyRemotePC       DriveC         C:\                  BUILTIN\Administrators = Allow,FullControl                                              
MyRemotePC       DriveC         C:\                  BUILTIN\Users = Allow,ReadAndExecute                                                    
MyRemotePC       TEMP           C:\windows\temp      CREATOR OWNER = Allow,FullControl                                                       
MyRemotePC       TEMP           C:\windows\temp      NT AUTHORITY\SYSTEM = Allow,FullControl                                                 
MyRemotePC       TEMP           C:\windows\temp      BUILTIN\Administrators = Allow,FullControl                                              
MyRemotePC       TEMP           C:\windows\temp      BUILTIN\Users = Allow,CreateFiles, AppendData, ExecuteFile                              
MyRemotePC       TEMP           C:\windows\temp      BUILTIN\IIS_IUSRS = Allow,ReadData                                                      
MyRemotePC       TEMP           C:\windows\temp      CONTOSO\myUserName = Allow,FullControl                                                 
MyRemotePC       TEMP           C:\windows\temp      S-1-5-21-12345678-1234567890-123456789-123456 = Allow,Read  
```