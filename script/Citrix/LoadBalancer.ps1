$cred = import-Clixml C:\Scripts\secrets\nscred.xml
$netscalers = "dc1prodlb.ent.dir.labor.gov","dc1stagelb.ent.dir.labor.gov","dc1testlb.ent.dir.labor.gov","dc1devlb.ent.dir.labor.gov","stlprodns.ent.dir.labor.gov"
$TOLIST = "Surapaneni.Venu@dol.gov"
$lbresults =  New-Object System.Collections.Generic.List[System.Object]
$reportparentfolder = "\\SILENTFS01.ent.dir.labor.gov\reports\LB"
$dailyreportfolder = "$reportparentfolder\$(get-date -format 'MM-dd-yyyy')"
if(!(Test-Path $dailyreportfolder)){New-Item -ItemType Directory  $dailyreportfolder -Force | Out-Null}
$Netscalerfile = "$dailyreportfolder\DC1 and DC2 Directory Services Load Balancer Details.xlsx"
$netscalers | % {
 $nname = $PSItem
$conn =  Connect-NetScaler -Hostname $PSItem -Credential $cred -Https -PassThru
$siteName= (($conn.Endpoint).Substring(0,3)).toupper()
 $lBinfos = Get-NSLBVirtualServer -Session $conn  | ?{$_.Port -match "^53|636|3269|389|3268"} | Select Name,Ipv46,port,ServiceType,LBMethod
 foreach($lb in $lBinfos) {
$lbresults += Get-NSLBVirtualServerBinding -Session $conn -Name $lb.Name | select Name,Service* | %{Get-NSLBServiceGroupMemberBinding -Name $PSItem.ServiceName -Session $conn } | select @{l="Netscaler";e={$nname}},@{l="Site";e={$siteName}},@{l="LB Name";e={$lb.Name}},@{l="LB IP";e={$lb.ipv46}},@{l="LB Port";e={$lb.port}},@{l="LB ServiceType";e={$lb.ServiceType}},@{l="LB Method";e={$lb.lbmethod}},ServiceGroupName,ServerName,Weight,IP,Port,svrstate,@{l="Netscaler State";e={$_.state}}
}
Disconnect-NetScaler
Start-Sleep -Seconds 2
}
#export to the Excel File
if(Test-Path $Netscalerfile){Remove-Item $Netscalerfile -Force}
$lbresults  | Export-Excel -Path $Netscalerfile -AutoSize -Append -TableStyle Medium2


#For Monitoring DNS
$DNSInfo = $lbresults | ?{$_.port -eq 53}
$DNSresults =  New-Object System.Collections.Generic.List[System.Object]
foreach($Info in $DNSInfo){
$proto = "UDP"
$query = "C:\PStool\PortQry.exe -n $($Info.IP) -p $proto -o $($Info.port)"
$qryresults = cmd.exe /c $query
$state = ($qryresults[-1] -split ": " -split " is ")[-1].Trim()
$pingstate = Test-Connection -ComputerName $Info.IP -Count 2 -Quiet
$data  =  $info | Select *,@{l="Protocol";e={$proto}},@{l="Actual Port State";e={$state}},@{l="Actual Ping State";e={$pingstate}}
$DNSresults.Add($data)
}

#For Monitoring AD
$ADInfo = $lbresults | ?{$_.port -ne 53}
$ADresults =  New-Object System.Collections.Generic.List[System.Object]
foreach($Info in $ADInfo){
$proto = "TCP"
$hostname = [System.Net.Dns]::GetHostEntry($info.ip).HostName
$query = "C:\PStool\PortQry.exe -n $($Info.IP) -p $proto -o $($Info.port)"
$LDAPS = [ADSI]"LDAP://$($hostname):$($Info.port)"
try {
$Connection = [adsi]($LDAPS)
} 
Catch {

}
If ($Connection.Path) {
$SSLStatus="Yes"
} Else {
$SSLStatus="Not Enabled"
}
$qryresults = cmd.exe /c $query
$pingstate = Test-Connection -ComputerName $Info.IP -Count 2 -Quiet
$state = ($qryresults[-1] -split ": " -split " is ")[-1].Trim()
$data  =  $info | Select *,@{l="Protocol";e={$proto}},@{l="Actual Port State";e={$state}},@{l="Actual Ping State";e={$pingstate}},@{l="SSL State";e={$SSLStatus}}
$ADresults.Add($data)
 }
<#
#LB Quick Check
$LBQResults = New-Object System.Collections.Generic.List[System.Object]
$CSVLBDATA = import-csv \\SILENTFS01.ent.dir.labor.gov\reports\LB\Master\proddetails.csv
$uniqueLB = $lbresults.'LB name' | select -Unique
foreach($q in $CSVLBDATA){
$LBIP = ($lbresults | ?{$_.'LB IP' -like $q.'IP' } | select -Property 'LB IP' -Unique).'LB IP'
$hostname = ($CSVLBDATA | ?{$_.IP -like $LBIP}).'Preferred DNS name (For SSL)'
$ports = "53","636","3269"
foreach($port in $ports){
            if($port -match "636|3269"){
            $LDAPS = [ADSI]"LDAP://$($hostname):$port"
            try {
            $Connection = ([adsi]($LDAPS))
            } 
            Catch {

            }
                    If ($Connection.Path) {
                    $SSLStatus="Yes"
                    } Else {
                    $SSLStatus="Not Enabled"
                    }
                    $Data = [System.Management.Automation.PSCustomObject]@{
                    'LB(FQDN)' = $q.'Preferred DNS name (For SSL)'
                    'LB(IP)' = $q.IP
                    'LB(Port)'= $port
                    '$LB(Resolved)' = 

                    }


            }

}


$LBQResults.Add($data) #Final Data
}
#>
#Frag Summary
$convertParams = @{ 
 head = @"
 <Title>Citrix Session Summary</Title>
<style>
table {
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    border-spacing: 5px;
    margin: 20px;
    text-align: center;
}

td {
    font-size: 1em;
    border: 1px solid #0078D7;
    padding: 5px 5px 5px 5px;
}

th {
    font-size: 1.1em;
    text-align: center;
    border: 1px solid;
    padding-top: 5px;
    padding-bottom: 5px;
    padding-right: 7px;
    padding-left: 7px;
    background-color: #0078D7;
    color: #ffffff;
    }

name tr {
    color: #000000;
    background-color: #0078D7;
}

</style>
"@
}
#$LBresultsFrag = $LBQResults | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Netscaler  LB Quick Glance</h2>"  -PostContent "<br></br>"   | Out-String
$DNSResultsFrag = $DNSresults | ConvertTo-Html -As Table -Fragment -PreContent "<h2>DNS LB Infromation</h2>"  -PostContent "<br></br>"   | Out-String
$ADResultsFarg = $ADresults | ConvertTo-Html -As Table -Fragment -PreContent "<h2>AD LB Infromation</h2>"  -PostContent "<br></br>"   | Out-String
$body = ConvertTo-HTML @convertParams -PreContent $DNSResultsFrag,$ADResultsFarg  -Title "<h2>Load Balncer Details $(get-date -Format D) </h2>"  -PostContent "<p class='footer'>Report generated from $env:COMPUTERNAME on $(get-date) .Report is run using $($cred.username)</p>"
Send-EmailMessage -To $TOLIST -From 'ADTeamLoadBalancers@dol.gov' -Server 'dc1-smtp.dol.gov' -Subject "LB Report for DC1 and DC2"  -HTML $body -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -Attachment $Netscalerfile
