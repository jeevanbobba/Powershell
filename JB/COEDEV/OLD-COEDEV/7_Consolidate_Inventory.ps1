#read script folder
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"
################################################
$files = (Get-ChildItem '\\mgtutils01.oasam.dir.labor.gov\DML\COE-DEV\RDP_Files\To Agency' -Recurse -Filter "*.rdp").FullName
#Rename-Item \\mgtutils01.oasam.dir.labor.gov\DML\COE-DEV\RDP_Files\Inventory_All.csv -NewName "\\mgtutils01.oasam.dir.labor.gov\DML\COE-DEV\RDP_Files\Inventory$(Get-Date -Format yyy-mm-dd-hhmm).csv" -Force
foreach($file in $files){
$data = gc $file
$username = ($data -match "username:s:" -split ":")[-1]
$COEDEVIP = ($data -match "full address:s:" -split ":")[-1]
$VMName = ($file -replace ".rdp" -split "-")[-1]
$Agency = ($file -replace ".rdp" -split "\\")[-2]
New-Object psobject -Property @{
"Virtual Machine Name"=$VMNAme
"COE DEV IP"=$COEDEVIP
"COE DEV UserName"=$username
"COE DEV Agency"=$Agency} | Export-Csv -NoTypeInformation "C:\temp\inventory.csv" -Append
} 