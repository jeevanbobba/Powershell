##########################Restart multiple servers #######################################
$servers = get-content c:\temp\dc2.txt
foreach ($server in $Servers)
{
(gwmi -Class Win32_OperatingSystem -ComputerName $server).Win32Shutdown(6)
If ($?) {
Write-Host "$server successfully rebooted"
}Else{
Write-Host "Could not reboot $server"
}}