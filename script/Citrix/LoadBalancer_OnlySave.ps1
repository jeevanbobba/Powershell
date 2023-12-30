$cred = import-Clixml C:\Scripts\secrets\nscred.xml
$netscalers = "dc1prodlb.ent.dir.labor.gov","dc1stagelb.ent.dir.labor.gov","stlprodns.ent.dir.labor.gov","dc1devlb.ent.dir.labor.gov" ,"dc1testlb.ent.dir.labor.gov"
$lbresults =  New-Object System.Collections.Generic.List[System.Object]
$reportparentfolder = "\\SILENTFS01.ent.dir.labor.gov\reports\LB"
$dailyreportfolder = "$reportparentfolder\$(get-date -format 'MM-dd-yyyy')"
if(!(Test-Path $dailyreportfolder)){New-Item -ItemType Directory  $dailyreportfolder -Force | Out-Null}
$Netscalerfile = "$dailyreportfolder\DC1 and DC2 Directory Services Load Balancer Details.xlsx"
$netscalers | % {
 $nname = $PSItem
Write-Output "Working on $PSitem"
$conn =  Connect-NetScaler -Hostname $PSItem -Credential $cred -Https -PassThru
$siteName= (($conn.Endpoint).Substring(0,3)).toupper()
 $lBinfos = Get-NSLBVirtualServer -Session $conn  | ?{$_.Port -match "^53|636|3269|^389|3268"} | Select Name,Ipv46,port,ServiceType,LBMethod
 foreach($lb in $lBinfos) {
$lbresults += Get-NSLBVirtualServerBinding -Session $conn -Name $lb.Name -ErrorAction SilentlyContinue | select Name,Service* | %{Get-NSLBServiceGroupMemberBinding -Name $PSItem.ServiceName -Session $conn } | select @{l="Netscaler";e={$nname}},@{l="Site";e={$siteName}},@{l="LB Name";e={$lb.Name}},@{l="LB IP";e={$lb.ipv46}},@{l="LB Port";e={$lb.port}},@{l="LB ServiceType";e={$lb.ServiceType}},@{l="LB Method";e={$lb.lbmethod}},ServiceGroupName,ServerName,Weight,IP,Port,svrstate,@{l="Netscaler State";e={$_.state}}
}
Disconnect-NetScaler -Session $conn
Start-Sleep -Seconds 2
}
#export to the Excel File
if(Test-Path $Netscalerfile){Remove-Item $Netscalerfile -Force}
$lbresults  | Export-Excel -Path $Netscalerfile -AutoSize -Append -TableStyle Medium2