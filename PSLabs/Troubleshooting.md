# PSLab: Troubleshooting

### Use the troubleshooting.ps1 to generate the output:

```
$data = .\troubleshooting.ps1
$data | Where-Object { ($_.ExpirationDate -gt (Get-Date)) -and $_.IsCompatible }
```

### Display only the non-expired and compatible devices in the list

```
DeviceId        : M-123456
DeviceName      : MissleLauncher
IsCompatible    : True
ManufactureDate : 2020-01-19 00:00:00
ExpirationDate  : 2022-01-19 00:00:00

DeviceId        : F-774321
DeviceName      : Missle
IsCompatible    : True
ManufactureDate : 2020-05-17 00:00:00
ExpirationDate  : 2021-05-28 00:00:00
```