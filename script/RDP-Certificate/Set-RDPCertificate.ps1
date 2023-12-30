#Setting the Cert on DMZ/Non-Domain Joined Machines
if((Get-WmiObject -Class Win32_ComputerSystem).partofdomain -eq $false){
$Tprint = (gci Cert:\LocalMachine\My | ?{$PSItem.EnhancedKeyUsageList.objectID -eq  "1.3.6.1.5.5.7.3.2"  -and $PSItem.EnhancedKeyUsageList.objectID -eq  "1.3.6.1.5.5.7.3.1"  -and $PSItem.NotAfter -gt $(get-date) -and  $PSItem.Issuer -ne $PSItem.Subject  -and $PSItem.Issuer -match "DC=GOV"}).Thumbprint
$path = (Get-WmiObject "Win32_TSGeneralSetting"  -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").__path 
Set-WmiInstance -Path $path -argument @{SSLCertificateSHA1Hash=$Tprint}
}
#validate the current RDP Cert 
$currentRDPCertHash = (get-WmiObject "Win32_TSGeneralSetting"  -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").SSLCertificateSHA1Hash
$currentCert = gci Cert:\LocalMachine\My | ?{$PSItem.Thumbprint -eq $currentRDPCertHash} 
if($currentCert.Issuer -match "DC=GOV" -and $currentCert.Issuer -ne $currentCert.Subject){
#removing SelfSigned After Validating it has a valid cert ..along with restarting RDPsession
Get-Service SessionEnv | Restart-Service -PassThru -Force
do {Get-childitem 'Cert:\LocalMachine\Remote Desktop' | ? {$_.Subject -eq $_.Issuer} | remove-item -Force }
while (Get-childitem 'Cert:\LocalMachine\Remote Desktop' | ? {$_.Subject -eq $_.Issuer} )
#Setting Deny on the ACL
$RDSACL = Get-acl 'HKLM:\Software\Microsoft\SystemCertificates\Remote Desktop\Certificates'
$RDSNEW = New-Object System.Security.AccessControl.RegistryAccessRule ("NT AUTHORITY\System","CreateSubkey","Deny")
$RDSACL.SetAccessRule($RDSNEW)
$RDSACL | Set-Acl -Path 'HKLM:\Software\Microsoft\SystemCertificates\Remote Desktop\Certificates'
}
