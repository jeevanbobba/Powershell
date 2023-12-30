#setup azure connection
Disable-AzContextAutosave –Scope Process

$connection = Get-AutomationConnection -Name AzureRunAsConnection

while(!($connectionResult) -and ($logonAttempt -le 10))
{
    $LogonAttempt++
    # Logging in to Azure...
    $connectionResult = Connect-AzAccount `
                            -ServicePrincipal `
                            -Tenant $connection.TenantID `
                            -ApplicationId $connection.ApplicationID `
                            -CertificateThumbprint $connection.CertificateThumbprint

    Start-Sleep -Seconds 30
}

#script

##Setup remote command script on temporary storage
$commandpath = ".\RBCommand.ps1"
$remoteCommand = {
    #script block code 
    $skipshutdown = 0
    $varNow = (get-date)
    $LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $Flagfile = "C:\skipshutdown.txt"
    if (Test-Path -Path $Flagfile){
        $FlagDate = (Get-ChildItem $Flagfile).LastWriteTime
    }else{
        $FlagDate = $varNow.AddHours(-23)
    }
    if (($varNow - $FlagDate).hours -lt 12 -and ($varNow - $FlagDate).Days -lt 1){
        $skipshutdown = 1
    }elseif (($varNow - $LastBoot).hours -lt 2 -and ($varNow - $LastBoot).Days -lt 1) {
        $skipshutdown = 2
    }
    $skipshutdown
}
Set-Content -Path $commandpath -Value $remoteCommand

#Get list of Resource Groups in the subscription
$strResourceGroups = (Get-AzResourceGroup).ResourceGroupName

#Step thorugh the list of Resource Groups in the subscription
foreach ($strRG in $strResourceGroups){
    #Get the host pool from that Resource Group (when we have more than 1 host pool per resource group this script will need to change)
    $hostpoolname =  (Get-AzWvdHostPool -ResourceGroupName $strRG).Name
    if ( -not ($null -eq $hostpoolname ) ) {
        Write-Output "Resource Group HostPool: $strRG  $hostpoolname "
        #get the list of available session hosts that meet the shutdown criteria from the hostpool in the resource group
        $vmlist = Get-AzWvdSessionHost -ResourceGroupName $strRG -HostPoolName $hostpoolname | Where-Object {$_.Status -eq "Available" -and $_.Session -eq 0 -and $_.SessionTimestamp -lt ((get-date).AddHours(-2))}
        #Step through the list of sesion hosts
        foreach($vm in $vmlist) {
            #Create a VM object varialbe by getting the VM based on the VirtualmachineID from the session host
            $AzVM = Get-AzVM -ResourceGroupName $strRG | Where-Object {$_.VmId -eq $vm.VirtualMachineId -and $_.tags.DevAutomation -ne "skip"}
            #run the script created above on the VM and set the $skipstatus variable
            $skipstatus = (Invoke-AzVMRunCommand -ResourceGroupName $strRg -Name $AzVM.Name -CommandId 'RunPowerShellScript' -ScriptPath $commandpath).Value[0].Message
            if ($skipstatus -eq 0){
                $AzVM | Stop-AzVM -Force
                Write-Output $AzVM.Name "Deallocating"
            }elseif ($skipstatus -eq 1) {
                Write-Output $AzVM.Name "Skipped due to c:\skipshutdown flag"
            }elseif ($skipstatus -eq 2) {
                Write-Output $AzVM.Name "Skipped due to recent startup"
            }
        }
    }
}

#cleanup the script created above
Remove-Item $commandpath
