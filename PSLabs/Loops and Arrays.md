# PSLab: Loops and Arrays

### Function structure:

```
function Get-FriendlySize {
    param(...
}
```


### Sample outputs: 

```
Get-FriendlySize
0.00 bytes

Get-FriendlySize 256
256.00 bytes

Get-FriendlySize 1024
1.00 KB

Get-FriendlySize 2453667
2.34 MB

Get-FriendlySize 6088116142
5.67 GB

Get-FriendlySize 9785653487206
8.90 TB

Get-FriendlySize 2961799813685248
2.63 PB

Get-FriendlySize 9876543210123456789012
8.37 ZB

Get-FriendlySize 3799184210123456789012345
3.14 YB
```