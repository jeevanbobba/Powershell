#read script folder
#$scriptpath = $MyInvocation.MyCommand.P
#$dir = Split-Path $scriptpath
#Write-host "My directory is $dir"
################################################
#$file = '\\mgtutils01\dml\COE-DEV\RDP_Files\Ref\Scripts\Final\Dev_Systems.csv'
$file = "D:\JB\FInal\Dev_systems.csv"
$VMDATA = import-csv $file
$cred = Get-Credential -Message "Enter VCenter Administrative credentials"
Connect-VIServer silwvcp01.ent.dir.labor.gov -Credential $cred -force
$DS = 'silnafi_COE_Int_nfs_Win10NonPrd_NRepl_DS_04' #Datastore where Vm will be built
$devnetwork = 'dvPortGroup-Dev-Workstations-VLAN628'
$Template = Get-Template -Name "_Template1_Win10x64_1709v4"
$Specification = Get-OSCustomizationSpec -Name 'Win10_1709v4_DEV'
$tasktracker = @{}
rename-item $file  $($file -replace ".csv","_$(Get-Date -Format hhmm-MM-dd-yyyy).csv" )  -ErrorAction Stop
$clusterData = get-cluster 'COE-Int-Dev-Cluster' | Get-VMHost
foreach($data in $VMData){
if ($data.Status -like "Ready")
	{
     $ESXiHostName = $clusterData | Get-Random
	 $folder = $data.FolderName
	 $VirtualObj = $data.ComputerName
     $VMIP = $data.'IPAddress'
     $nicsettings= Get-OSCustomizationSpec $Specification | Get-OSCustomizationNicMapping 
     if($nicsettings -ne $null) {$nicsettings| Remove-OSCustomizationNicMapping –Confirm:$false -Verbose}
     New-OSCustomizationNicMapping -OSCustomizationSpec $Specification -IpMode UseStaticIP –IpAddress $VMIP -SubnetMask "255.255.252.0" -DefaultGateway "10.50.28.1" -Dns '10.50.11.143','10.50.11.156'  -Confirm:$false -Verbose
     $tasktracker[(New-VM -Name $VirtualObj -Template $Template -OSCustomizationSpec $Specification  -VMHost $ESXiHostName   -Datastore $DS -Location $Folder -ErrorAction Stop -RunAsync).Id] = $VirtualObj
     Get-OSCustomizationSpec $Specification | Get-OSCustomizationNicMapping | Remove-OSCustomizationNicMapping –Confirm:$false -Verbose
     $data.Status = "Provisioned"
	 $data | Export-csv $file -Append -NoTypeInformation -ErrorAction Stop
}
}
$ActiveTasks = $tasktracker.Count
while($ActiveTasks -gt 0){
    Get-Task | % {
        if($TaskTracker.ContainsKey($_.Id) -and $_.State -eq "Success"){
            #$xx = Get-VM $TaskTracker[$_.Id] 
            #Write-Output  "Powering on VM $xx.Name"
            Get-VM $TaskTracker[$_.Id] | Start-VM
            $TaskTracker.Remove($_.Id)
            $ActiveTasks--
        }
        elseif($TaskTracker.ContainsKey($_.Id) -and $_.State -eq "Error"){
            $TaskTracker.Remove($_.Id)
            $ActiveTasks--
        }
    }
    Start-Sleep -Seconds 15
}