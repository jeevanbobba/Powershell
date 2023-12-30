$cred1 = Import-Clixml C:\Scripts\CItrix\xdreportspas.xml
$profiles = gci \\SILENTFS01.ent.dir.labor.gov\XenAPP_Profiles\ -Filter "*S-*"
$XDServers = 'dc1vwctxxdcp01.ent.dir.labor.gov','dc1vwctxxdcp02.ent.dir.labor.gov'
$SFServers =  'dc1vwctxsfp01.ent.dir.labor.gov','dc1vwctxsfp02.ent.dir.labor.gov'
$directorServer = 'dc1vwctxdirp01.ent.dir.labor.gov'
$XDServ =   (Test-Connection $XDServers -count 2 | Sort-Object -Property ResponseTime | select -First 1).Address
$TOLIST = "Bobba.Jeevan@DOL.gov","Nawthale.Kavibhushan@dol.gov","Wright.Brian.D@dol.gov","Quintanilla.Raul.H@DOL.gov","Surapaneni.Venu@dol.gov","Onadeko.Eddie@dol.gov","Khan.Adnan.A@dol.gov","Huynh.Anh.H@dol.gov","WatsonIII.George.A@DOL.GOV"
$SBforDC = {
Add-PSSnapin ci*
$config = Get-ConfigSite
[pscustomobject]@{
xddata = Get-BrokerController
catalog = Get-BrokerCatalog
Brokerdetails = Get-BrokerMachine
licdetails = Get-LicInventory -AdminAddress $config.LicenseServerName -CheckForSameSerialNumber -CertHash $config.MetadataMap.CertificateHash | ?{$_.LicenseEdition -match "PLT|STD"} 
dbdetails = Get-ConfigDBConnection
}
}
$fromSB = icm -ComputerName $XDServ  -Credential $cred1 -ScriptBlock $SBforDC -ErrorAction SilentlyContinue -ErrorVariable SBError
#Certlist = Get-ChildItem –Path 'Cert:\LocalMachine\My\' | ?{$_.DnsNameList -match "gov" -and $_.issuer }|select DNSNameList,Not*,Issuer | Out-String

#XenAPP Delivery Controller Information
$xddata = $fromSB.xddata
$XDCResults = New-Object System.Collections.Generic.List[System.Object]
get-job | Remove-Job -Force -Confirm:$false
icm -ComputerName  $xddata.DNSName -Credential $cred1 -ScriptBlock {
$oswmi = Get-CimInstance -ClassName win32_operatingsystem
$WMIDiskInfo = Get-CimInstance -ClassName Win32_Volume -Property Capacity,FreeSpace,DriveLetter | Where {$_.DriveLetter -eq $env:SystemDrive} | Select Capacity,FreeSpace,DriveLetter
[pscustomobject]@{
days = (New-TimeSpan -Start $oswmi.lastbootuptime -End $(get-date)).Days
cfreespace = [math]::Round(($WMIDiskInfo.FreeSpace * 100 / $WMIDiskInfo.Capacity))
vmtools = (Get-Service -Name "VMTOOLS" -ErrorAction SilentlyContinue).Status
osbuild = $oswmi.Version
avgcpu= [math]::Round((GET-COUNTER -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
avgmem = [math]::Round((GET-COUNTER -Counter "\Memory\% Committed Bytes In Use" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
AVDate = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatDate').AVDatDate
AVDat = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatVersion').AVDatVersion
lAstPatchdate =  (New-TimeSpan -Start (get-hotfix | Sort-Object -Property Installedon -Descending | select -First 1).Installedon  -End $(get-date)).Days 
certExpiring = (Get-ChildItem -Path 'Cert:\LocalMachine\My\' | ?{$_.DnsNameList -match ".gov" -and $_.Issuer -match "entrust|labor" -and (get-date).Adddays(5) -gt $_.NotAfter  }|select -ExpandProperty DNSNameList).Unicode
}
} -AsJob -JobName "DCDetails"
do{
start-sleep -Seconds 3
}while(Get-job -name "DCDetails" -IncludeChildJob | where state -eq Running)
$extraDCdetails = Get-job -name "DCDetails" -IncludeChildJob  |Receive-Job
foreach($XD in $xddata){
$XDCResults   += [pscustomobject]@{
ControllerServer = $XD.DNSName
Ping = $(Test-Connection -Quiet -ComputerName $XD.DNSName -Count 1)
State = $XD.State
DesktopsRegistered = $XD.DesktopsRegistered
ActiveSiteServices = $XD.ActiveSiteServices
'EPO(Date)'= ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).AVDate 
'EPO(DAT)' = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).AVDat
OSBuild	 = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).osbuild
'CFreespace(GB)' = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).cfreespace
AvgCPU	 = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).avgcpu
MemUsg	 = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).avgmem
Uptime = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).days
'LastPatched(DaysAgo)' = ($extraDCdetails | ?{$_.PScomputerName -eq $XD.DNSName}).lAstPatchdate
'ExpiringCerts'=if(($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).certExpiring){($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).certExpiring}else{"NONE"}

}
}


#StoreFront Health Check
$SFResults = New-Object System.Collections.Generic.List[System.Object]
get-job | Remove-Job -Force -Confirm:$false
icm -ComputerName  $SFServers -Credential $cred1 -ScriptBlock {
Add-PSSnapin ci*
$oswmi = Get-CimInstance -ClassName win32_operatingsystem
$WMIDiskInfo = Get-CimInstance -ClassName Win32_Volume -Property Capacity,FreeSpace,DriveLetter | Where {$_.DriveLetter -eq $env:SystemDrive} | Select Capacity,FreeSpace,DriveLetter
[pscustomobject]@{
sfstatus = ($(Get-STFServerGroup).ClusterMembers).HostName
sfdetails = $(Get-STFWebReceiverService).FriendlyName
days = (New-TimeSpan -Start $oswmi.lastbootuptime -End $(get-date)).Days
cfreespace = [math]::Round(($WMIDiskInfo.FreeSpace * 100 / $WMIDiskInfo.Capacity))
vmtools = if((Get-Service -Name "VMTOOLS" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Running"}else {"Running"}
osbuild = $oswmi.Version
avgcpu= [math]::Round((GET-COUNTER -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
avgmem = [math]::Round((GET-COUNTER -Counter "\Memory\% Committed Bytes In Use" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
AVDate = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatDate').AVDatDate
AVDat = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatVersion').AVDatVersion
lAstPatchdate =  (New-TimeSpan -Start (get-hotfix | Sort-Object -Property Installedon -Descending | select -First 1).Installedon  -End $(get-date)).Days 
certExpiring = (Get-ChildItem -Path 'Cert:\LocalMachine\My\' | ?{$_.DnsNameList -match ".gov" -and $_.Issuer -match "entrust|labor" -and (get-date).Adddays(5) -gt $_.NotAfter  }|select -ExpandProperty DNSNameList).Unicode
}
} -AsJob -JobName "SFDetails"
do{
start-sleep -Seconds 3
}while(Get-job -name "SFDetails" -IncludeChildJob | where state -eq Running)
$extraSFdetails = Get-job -name "SFDetails" -IncludeChildJob  |Receive-Job
foreach($XD in $extraSFdetails){
$SFResults   += [pscustomobject]@{
StoreFrontServer = $XD.PSComputerName
StorefrontMembers = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).sfstatus
StorefrontSites = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).sfdetails
Ping = $(Test-Connection -Quiet -ComputerName $XD.PSComputerName -Count 1)
'EPO(Date)'= ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).AVDate 
'EPO(DAT)' = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).AVDat
OSBuild	 = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).osbuild
'CFreespace(GB)' = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).cfreespace
AvgCPU	 = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).avgcpu
MemUsg	 = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).avgmem
Uptime = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).days
'LastPatched(DaysAgo)' = ($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).lAstPatchdate
'ExpiringCerts'=if(($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).certExpiring){($extraSFdetails | ?{$_.PScomputerName -eq $XD.PSComputerName}).certExpiring}else{"NONE"}
}
}


#XENAPP License Server Details 
$LicenseServerDetails = $fromSB.licdetails | select LocalizedLicenseProductName,LicenseEdition,LicenseSubscriptionAdvantageDate,LicensesInUse,LicensesAvailable
$LIcenseServerName = $fromsB.xddata.LastLicensingServerEventDetails[0] -replace "Server: "

#XENAPP CatalogInfo
$catalogInfo = $fromSB.catalog| select Name,UsedCount,AvailableUnassignedCount,ProvisioningType,AllocationType,SessionSupport,MinimumFunctionalLevel,PersistUserChanges

#Xenapp DB Info
$DBServer = ($fromSB.dbdetails -split ";")[0] -replace "server="
$DBInfo = icm -ComputerName  $DBServer -Credential $cred1 -ScriptBlock {
$oswmi = Get-CimInstance -ClassName win32_operatingsystem
$WMIDiskInfo = Get-CimInstance -ClassName Win32_Volume -Property Capacity,FreeSpace,DriveLetter | Where {$_.DriveLetter -match ":"} | Select Capacity,FreeSpace,DriveLetter
[pscustomobject]@{
'Uptime(in Days)' = (New-TimeSpan -Start $oswmi.lastbootuptime -End $(get-date)).Days
'Disk(% Free)' = ($WMIDiskInfo | select @{l="a";e={$($_.DriveLetter -replace ":")+"/"+$([math]::Round(($_.FreeSpace * 100 / $_.Capacity)))} }).a | ft -AutoSize | Out-String
vmtools = if((Get-Service -Name "VMTOOLS" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Running"}else {"Running"}
OSversion = $oswmi.Version
DBversion = (Invoke-SqlCmd -query "select @@version" -ServerInstance "localhost").column1 | Out-String
'AvgCPU(%)'= [math]::Round((GET-COUNTER -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
'AvgMem(%)' = [math]::Round((GET-COUNTER -Counter "\Memory\% Committed Bytes In Use" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
'EPO(DATE)' = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatDate').AVDatDate
'EPO(DAT)' = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatVersion').AVDatVersion
'LastPatched(DaysAgo)' =  (New-TimeSpan -Start (get-hotfix | Sort-Object -Property Installedon -Descending | select -First 1).Installedon  -End $(get-date)).Days 
}
}
$XenAppDBData = $DBInfo | select @{l="DBServer";e={$DBServer}},* -ExcludeProperty PScomputerName,RunspaceId

#Director DATA
$DirectorSBInfo = icm -ComputerName  $directorServer -Credential $cred1 -ScriptBlock {
$oswmi = Get-CimInstance -ClassName win32_operatingsystem
$WMIDiskInfo = Get-CimInstance -ClassName Win32_Volume -Property Capacity,FreeSpace,DriveLetter | Where {$_.DriveLetter -match ":"} | Select Capacity,FreeSpace,DriveLetter
[pscustomobject]@{
'Uptime(in Days)' = (New-TimeSpan -Start $oswmi.lastbootuptime -End $(get-date)).Days
'Disk(% Free)' = ($WMIDiskInfo | select @{l="a";e={$($_.DriveLetter -replace ":")+"/"+$([math]::Round(($_.FreeSpace * 100 / $_.Capacity)))} }).a | ft -AutoSize | Out-String
vmtools = if((Get-Service -Name "VMTOOLS" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Running"}else {"Running"}
OSversion = $oswmi.Version
DirVersion = (Get-WmiObject -Class Win32_Product | where Name -match "Director"| select @{l="a";e={$_.Name,$_.version}}).a
'AvgCPU(%)'= [math]::Round((GET-COUNTER -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
'AvgMem(%)' = [math]::Round((GET-COUNTER -Counter "\Memory\% Committed Bytes In Use" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
'EPO(DATE)' = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatDate').AVDatDate
'EPO(DAT)' = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatVersion').AVDatVersion
'LastPatched(DaysAgo)' =  (New-TimeSpan -Start (get-hotfix | Sort-Object -Property Installedon -Descending | select -First 1).Installedon  -End $(get-date)).Days 
}
}
$DirectorInfo = $DirectorSBInfo | select @{l="Director";e={$directorServer}},* -ExcludeProperty PScomputerName,RunspaceId


#XenAPP Servers Information
$Brokerdetails = $fromSB.Brokerdetails
$BrokerResults = New-Object System.Collections.Generic.List[System.Object]
get-job | Remove-Job -Force -Confirm:$false
icm -ComputerName $Brokerdetails.DNSName -Credential $cred1 -ScriptBlock {
$oswmi = Get-CimInstance -ClassName win32_operatingsystem
$WMIDiskInfo = Get-CimInstance -ClassName Win32_Volume -Property Capacity,FreeSpace,DriveLetter | Where {$_.DriveLetter -eq $env:SystemDrive} | Select Capacity,FreeSpace,DriveLetter
[pscustomobject]@{
days = (New-TimeSpan -Start $oswmi.lastbootuptime -End $(get-date)).Days
cfreespace = [math]::Round(($WMIDiskInfo.FreeSpace * 100 / $WMIDiskInfo.Capacity))
vmtools = if((Get-Service -Name "VMTOOLS" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Running"}else {"Running"}
spooler = if((Get-Service -Name "Spooler" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Runnning"}else {"Running"}
printer = if((Get-Service -Name "cpsvc" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Running"}else {"Running"}
fslogix = if((Get-Service -Name "frxccds","frxsvc" -ErrorAction SilentlyContinue).Status -notmatch "running"){"Not Found"}else {"Running"}
osbuild = $oswmi.Version
avgcpu= [math]::Round((GET-COUNTER -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
avgmem = [math]::Round((GET-COUNTER -Counter "\Memory\% Committed Bytes In Use" -SampleInterval 3 -MaxSamples 8 |select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average)
AVDate = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatDate').AVDatDate
AVDat = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\McAfee\AVEngine' -Name 'AVDatVersion').AVDatVersion
lAstPatchdate =  (New-TimeSpan -Start (get-hotfix | Sort-Object -Property Installedon -Descending | select -First 1).Installedon  -End $(get-date)).Days 
}
} -AsJob -JobName "ExtraDetails" -ErrorAction SilentlyContinue -ErrorVariable CTXErrors
do{
start-sleep -Seconds 3
}while(Get-job -name "extradetails" -IncludeChildJob | where state -eq Running)
$extradetails = Get-job -name "extradetails" -IncludeChildJob  |Receive-Job
foreach($broker in $Brokerdetails){
$BrokerResults  += [pscustomobject]@{
XenAppServer = $Broker.DNSName
IPAddress = $broker.IPAddress
CatalogName = $broker.CatalogName
DeliveryGroup = $broker.DesktopGroupName
Serverload = $broker.LoadIndex
Ping = $(Test-Connection -Quiet -ComputerName $broker.DNSName -Count 1)
MaintMode = if($broker.InMaintenanceMode){"NO"}else{"YES"}
Uptime = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).days
'LastPatched(DaysAgo)' = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).lAstPatchdate
RegState = $broker.RegistrationState
VDAVersion = $broker.AgentVersion
'EPO(Date)'= ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).AVDate 
'EPO(DAT)' = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).AVDat
Spooler = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).spooler
CitrixPrint = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).printer
Fslogix = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).fslogix
OSBuild	 = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).osbuild
'CFreespace(GB)' = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).cfreespace
AvgCPU	 = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).avgcpu
MemUsg	 = ($extradetails | ?{$_.PScomputerName -eq $broker.DNSName}).avgmem
ActiveSessions	 = $broker.SessionCount
ConnectedUsers	 = $broker.AssociatedUserNames
HostedOn = $broker.HostingServerName

}
}
#profileData
function ConvertFrom-SID
{
  param
  (
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [Alias('Value')]
    $Sid 
  )
  
  process
  {
    $objSID = New-Object System.Security.Principal.SecurityIdentifier($sid)
    $objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
    $objUser.Value
  }
}
$reportdata = New-Object System.Collections.Generic.List[System.Object]
foreach($profile in $profiles){
$uselater = gci $profile.FullName -Filter *.VHDX
$sum= ($uselater| Measure-Object -Property Length -Sum).Sum
$user = ConvertFrom-SID -Sid ($profile -split "_")[1] -ErrorAction SilentlyContinue -ErrorVariable usernotfound
$lastaccessdate = ($uselater | Sort-Object -Property LastWriteTime | select -First 1).LastWriteTime
$rdata = [pscustomobject]@{
User = if($usernotfound){"User Not Found in AD"}else{$user}
"Size(MB)" = [math]::round($sum/1MB)
"Size(GB)" = [math]::round($sum/1GB)
LastAccess = $lastaccessdate
Path = $profile.FullName
}
$reportdata.Add($rdata)
if($usernotfound){Clear-Variable usernotfound| Out-Null}
}
$XDprofiledata = $reportdata | ?{$_.USer -notmatch 'User Not Found in AD'} | Sort-Object -Property 'Size(GB)' -Descending | select -First 10
$inactiveusers = $reportdata | ?{$_.USer -match 'User Not Found in AD'}
$totalsize = ($reportdata| Measure-Object -Property 'Size(GB)' -Sum).Sum
$migprofiles = $profiles| %{if(($PSItem.name -split "_")[1] -like "S-1-5-21-430767753-*"){$PSItem}}


#This function generates HTML code from the results of the above functions.
Function New-ServerHealthHTMLTableCell(){
    param( $lineitem )
    $htmltablecell = $null
    switch ($($reportline."$lineitem"))
    {
        $success {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Running" {$htmltablecell = "<td class=""pass"">$([string]$reportline."$lineitem")</td>"}
        "Registered" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Active" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "YES" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "True" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Warn" {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        "Access Denied" {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        "Fail" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Failed" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "False" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "NO" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
         "Not Running" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Inactive" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Could not test server uptime." {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Could not test service health. " {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        "Unknown" {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        default {$htmltablecell = "<td>$($reportline."$lineitem")</td>"}
    }
    
    return $htmltablecell
}
#Common HTML head and styles
$htmlhead=" <style>
                BODY{font-family: Arial; font-size: 12pt;}
                H1{font-size: 16px;}
                H2{font-size: 14px;}
                H3{font-size: 12px;}
                TABLE{border: 1px solid black; border-collapse: separate; font-size: 10pt;table-layout: auto;}
                TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
                TD{border: 1px solid black; padding: 5px; }
                td.pass{background: #7ABA7A;}
                td.warn{background: #FFE600;}
                td.fail{background: #FF0000; color: #ffffff;}
                td.info{background: #85D4FF;}
             </style>"   
#Citrix Delivery Controller Table Header
$ctxDChtmltableheader = "<h2>Citrix Delivery Controller Server Summary</h2>
                        <table>
                        <tr>
                        <th>ControllerServer</th>
                        <th>Ping</th>
                        <th>State</th>
                        <th>DesktopsRegistered</th>
                        <th>ActiveSiteServices</th>
                        <th>EPO(Date)</th>
                        <th>EPO(DAT)</th>
                        <th>OSBuild</th>
                        <th>CFreespace(%)</th>
                        <th>AvgCPU(%)</th>
                        <th>MemUsg(%)</th>
                        <th>uptime(Days)</th>
                        <th>LastPatched(DaysAgo)</th>
                        <th>ExpiringCerts</th>
                        </tr>"
#citrix SF Table Header
$ctxSFhtmltableheader = "<h2>Citrix StoreFront Server Summary</h2>
                        <table>
                        <tr>
                        <th>StoreFrontServer</th>
                        <th>StoreFrontStatus</th>
                        <th>StoreFrontSites</th>
                        <th>Ping</th>
                        <th>EPO(Date)</th>
                        <th>EPO(DAT)</th>
                        <th>OSBuild</th>
                        <th>CFreespace(%)</th>
                        <th>AvgCPU(%)</th>
                        <th>MemUsg(%)</th>
                        <th>uptime(Days)</th>
                        <th>LastPatched(DaysAgo)</th>
                        <th>ExpiringCerts</th>
                        </tr>"
#Citrix Broker Health Report Table Header
$ctxbrokerhtmltableheader = "<h2>Citrix Broker Servers Health Summary</h2>
                        <table>
                        <tr>
                        <th>XenAppServer</th>
                        <th>IPAddress</th>
                        <th>CatalogName</th>
                        <th>DeliveryGroup</th>
                        <th>Serverload</th>
                        <th>Ping</th>
                        <th>Active</th>
                        <th>Uptime(Days)</th>
                        <th>LastPatched(DaysAgo)</th>
                        <th>RegState</th>
                        <th>VDAVersion</th>
                        <th>EPO(DATE)</th>
                        <th>EPO(DAT)</th>
                        <th>Spooler</th>
                        <th>CitrixPrint</th>
                        <th>FSLogix</th>
                        <th>OSBuild</th>
                        <th>CFreespace(%)</th>
                        <th>AvgCPU(%)</th>
                        <th>MemUsg(%)</th>
                        <th>ActiveSessions</th>
                        <th>ConnectedUsers</th>
                        <th>HostedOn</th>
                        </tr>"
$dchealthhtmltable=$cataloghealthhtmltable=$serverhealthhtmltable=$sfhealthhtmltable = $null
#For DC HTML
foreach ($reportline in $XDCResults)
    {
        $htmltablerow = "<tr>"
        $htmltablerow += "<td>$($reportline.ControllerServer)</td>"
        $htmltablerow += (New-ServerHealthHTMLTableCell "Ping")
        $htmltablerow += (New-ServerHealthHTMLTableCell "State")                
        $htmltablerow += "<td>$($reportline.DesktopsRegistered)</td>"
        $htmltablerow += "<td>$($reportline.ActiveSiteServices)</td>"
        if ($(get-date -date $($reportline.'EPO(Date)')) -lt (get-date).adddays(-2))
        {
            $htmltablerow += "<td class=""fail"">$(get-date -date $($reportline.'EPO(Date)'))</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$(get-date -date $($reportline.'EPO(Date)'))</td>"
         }
          $htmltablerow += New-ServerHealthHTMLTableCell "EPO(DAT)"
          $htmltablerow += "<td>$($reportline.OSBuild)</td>"
       if ($($reportline.'CFreespace(GB)') -lt 20)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.'CFreespace(GB)')</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.'CFreespace(GB)')</td>"
         }
       if ($($reportline.AvgCPU) -gt 70)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.AvgCPU)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.AvgCPU)</td>"
         }
      if ($($reportline.MemUsg) -gt 70)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.MemUsg)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.MemUsg)</td>"
         }
        if ($($reportline."Uptime") -gt 7)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.Uptime)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.Uptime)</td>"
         }
        if ($($reportline.'LastPatched(DaysAgo)') -gt 30)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.'LastPatched(DaysAgo)')</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.'LastPatched(DaysAgo)')</td>"
         }
         $htmltablerow += "<td>$($reportline.ExpiringCerts)</td>"  
       [array]$dchealthhtmltable += $htmltablerow
        }  
$dchealthhtmltable = $dchealthhtmltable + "</table></p>"
#For SF HTML
foreach ($reportline in $SFResults)
    {
        $htmltablerow = "<tr>"
        $htmltablerow += "<td>$($reportline.StoreFrontServer)</td>"
        $htmltablerow += "<td>$($reportline.StoreFrontMembers)</td>"
        $htmltablerow += "<td>$($reportline.StoreFrontSites)</td>"
        $htmltablerow += (New-ServerHealthHTMLTableCell "Ping")
        if ($(get-date -date $($reportline.'EPO(Date)')) -lt (get-date).adddays(-2))
        {
            $htmltablerow += "<td class=""fail"">$(get-date -date $($reportline.'EPO(Date)'))</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$(get-date -date $($reportline.'EPO(Date)'))</td>"
         }
          $htmltablerow += New-ServerHealthHTMLTableCell "EPO(DAT)"
          $htmltablerow += "<td>$($reportline.OSBuild)</td>"
       if ($($reportline.'CFreespace(GB)') -lt 20)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.'CFreespace(GB)')</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.'CFreespace(GB)')</td>"
         }
       if ($($reportline.AvgCPU) -gt 70)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.AvgCPU)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.AvgCPU)</td>"
         }
      if ($($reportline.MemUsg) -gt 70)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.MemUsg)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.MemUsg)</td>"
         }
        if ($($reportline."Uptime") -gt 7)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.Uptime)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.Uptime)</td>"
         }
        if ($($reportline.'LastPatched(DaysAgo)') -gt 30)
        {
            $htmltablerow += "<td class=""fail"">$($reportline.'LastPatched(DaysAgo)')</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.'LastPatched(DaysAgo)')</td>"
         }
        $htmltablerow += "<td>$($reportline.ExpiringCerts)</td>"  
       [array]$sfhealthhtmltable += $htmltablerow
        }  
$SFhealthhtmltable = $sfhealthhtmltable + "</table></p>"
#For Broker HTML
foreach ($reportline in $BrokerResults)
    {
        $htmltablerow = "<tr>"
        $htmltablerow += "<td>$($reportline.XenAppServer)</td>"
        $htmltablerow += "<td>$($reportline.IPAddress)</td>"
        $htmltablerow += "<td>$($reportline.CatalogName)</td>"
        $htmltablerow += "<td>$($reportline.DeliveryGroup)</td>"
        if ($reportline.Serverload -gt 5000)
            {
                $htmltablerow += "<td class=""warn"">$($reportline.Serverload)</td>"
            }
            else
            {
                $htmltablerow += "<td class=""pass"">$($reportline.Serverload)</td>"
            }
        $htmltablerow += (New-ServerHealthHTMLTableCell "Ping")
        $htmltablerow += (New-ServerHealthHTMLTableCell "MaintMode")                 
        if ($($reportline."Uptime") -gt 7)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.Uptime)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.Uptime)</td>"
         }
        if ($($reportline.'LastPatched(DaysAgo)') -gt 30)
        {
            $htmltablerow += "<td class=""fail"">$($reportline.'LastPatched(DaysAgo)')</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.'LastPatched(DaysAgo)')</td>"
         }
          $htmltablerow += (New-ServerHealthHTMLTableCell "RegState")
          $htmltablerow += (New-ServerHealthHTMLTableCell "VDAVersion")
        if ($(get-date -date $($reportline.'EPO(Date)')) -lt (get-date).adddays(-2))
        {
            $htmltablerow += "<td class=""fail"">$(get-date -date $($reportline.'EPO(Date)'))</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$(get-date -date $($reportline.'EPO(Date)'))</td>"
         }
          $htmltablerow += "<td>$($reportline.'EPO(Dat)')</td>"
          $htmltablerow += New-ServerHealthHTMLTableCell 'Spooler'
          $htmltablerow += New-ServerHealthHTMLTableCell 'CitrixPrint'
          $htmltablerow += New-ServerHealthHTMLTableCell 'FSLOGIX'
          $htmltablerow += New-ServerHealthHTMLTableCell "OSBUILD"
       if ($($reportline.'CFreespace(GB)') -lt 20)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.'CFreespace(GB)')</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.'CFreespace(GB)')</td>"
         }
       if ($($reportline.AvgCPU) -gt 70)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.AvgCPU)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.AvgCPU)</td>"
         }
      if ($($reportline.MemUsg) -gt 70)
        {
            $htmltablerow += "<td class=""warn"">$($reportline.MemUsg)</td>"
        }
        else
        {
            $htmltablerow += "<td class=""pass"">$($reportline.MemUsg)</td>"
         }
        $htmltablerow += "<td>$($reportline.ActiveSessions)</td>"
        $htmltablerow += "<td>$($reportline.Connectedusers)</td>"
        $htmltablerow += "<td>$($reportline.Hostedon)</td>"
       [array]$serverhealthhtmltable += $htmltablerow
        }  
$serverhealthhtmltable = $serverhealthhtmltable + "</table></p>"
    
$finalreport = $htmlhead+$ctxDChtmltableheader+$dchealthhtmltable+$ctxSFhtmltableheader+$SFhealthhtmltable+$ctxbrokerhtmltableheader+$serverhealthhtmltable
$catfrag = $catalogInfo | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix Catalog Information </h2>"  -PostContent "<br></br>"   | Out-String
$Licfrag  = $LicenseServerDetails | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix License Information-$LIcenseServerName </h2>"  -PostContent "<br></br>"   | Out-String
$DBFrag = $XenAppDBData | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix SQL DB Information </h2>"  -PostContent "<br></br>"   | Out-String
$dirdataGrag = $Directorinfo| ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix Director </h2>"  -PostContent "<br></br>"   | Out-String
$XDProfileFrag = $XDprofiledata | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Total Profile Share size is $totalsize GB.. Top 10 Profiles</h2> . "  -PostContent "<br></br>"   | Out-String
$XDProfileInactiveFrag = $inactiveusers | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix InactiveProfiles</h2>"  -PostContent "<br></br>"   | Out-String
$MIGProfileFrag = $migprofiles | select Name,FUllName,LastAccessTime | ConvertTo-Html -As Table -Fragment -PreContent "<h2>ENT Migrated Accounts</h2>"  -PostContent "<br>Please delete the Old Profiles</br>"   | Out-String
#$concerns = $BrokerResults.'EPO(Date)' |%{if($(get-date -date $PSItem) -le $(get-date).AddDays(-2)){$a = $PSItem ;$BrokerResults |?{$_.'EPO(Date)' -contains $a} } }
#$xdcresults_Frag = $XDCResults  | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix Daily Report for  $(get-date -Format D)</h2>" -PostContent "<br></br>" | Out-String
#$Catalog_Frag = $catalogInfo | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix Catalog Information </h2>"  -PostContent "<br></br>"   | Out-String
#$BrokerResults_Frag = $BrokerResults | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Citrix Application Servers Information</h2>" -PostContent "<br></br>" | Out-String 
#$body = ConvertTo-HTML @convertParams -PreContent $xdcresults_Frag,$Catalog_Frag,$BrokerResults_Frag -Title "<h2>Citrix Daily Checks $(get-date -Format D) </h2>" 
#$finalbody = $body -replace ('FALSE', '<font color="red">FALSE</font>')  -Replace ('True', '<font color="green">True</font>')
$body = ConvertTo-HTML  -PreContent $finalreport,$catfrag,$Licfrag,$DBFrag,$dirdataGrag,$XDProfileInactiveFrag,$XDProfileFrag,$MIGProfileFrag  -Title "<h2>Citrix Daily Checks $(get-date -Format D) </h2>"  -PostContent "<p class='footer'>Report generated from $env:COMPUTERNAME on $(get-date) .Report is run using $($cred1.username)</p>"
Send-EmailMessage -To $TOLIST -From 'DC1CitrixHealthReport@dol.gov' -Server 'dc1-smtp.dol.gov' -Subject "Citrix Daily Report for DC1"  -HTML $body -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror
#Send-EmailMessage -To "surapaneni.venu@dol.gov" -From 'CitrixHourlyChecks@dol.gov' -Server 'dc1-smtp.dol.gov' -Subject $Subj -Attachment $attachments -HTML $Body -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror
#if($mailerror){"Email Failed - $mailerror" | Add-Content "$hourlyreportfolder\$hourlyreportfolder-mailissues.txt"}
