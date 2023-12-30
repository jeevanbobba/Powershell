$VMNAME = "AVDOASAMD939"
[System.String]$ScriptBlock = {
[string]$userName = "dev-dir\vsurapaneni"
[string]$userPassword = 'Y^&YTFY^R%$^%E'
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$cred = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
Test-ComputerSecureChannel -Repair -Credential $cred
}
$FileName = "RunScript.ps1"
Out-File -FilePath $FileName -InputObject $ScriptBlock -NoNewline
$vm = Get-AzVM -Name $VMNAME
Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -Name $vmname -CommandId 'RunPowerShellScript' -ScriptPath $FileName
Remove-Item -Path $FileName -Force -ErrorAction SilentlyContinue


#https://learn.microsoft.com/en-us/azure/virtual-machines/windows/run-command