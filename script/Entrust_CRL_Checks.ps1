$temppath = "C:\Temp\CRLDownloadsQuickCheck"
#$SummaryRecepients = "surapaneni.venu@DOL.GOV"
$SummaryRecepients = "zzOASAM-OCIO-ISD-IO-WindowsAdmin@DOL.GOV"
$allcrlIPS = "10.57.12.33","10.49.2.47","10.57.12.34","10.49.2.48"
new-item -ItemType Directory -Path $temppath -Force | Out-Null
foreach($IP in $allcrlIPS){
$CRLURL = "http://$IP/CRLs"
$CRLpage = Invoke-WebRequest -URI  $CRLURL -UseBasicParsing
$crlFiles = $CRLpage.links | where {$_.OuterHTML -match "EMS"} | select href
$webClient = New-Object System.Net.WebClient
foreach($file in $crlFiles){
$durl = ($CRLURL -split "\/CRLS")[0]+$file.href
#Write-Output "$durl"
$filename = "$IP"+"-"+($durl -split "\/")[-1]
$webclient.DownloadFile($durl,"$temppath\$filename")
#Start-BitsTransfer $durl -Destination "$temppath\$filename" -Priority High
}
#Get-BitsTransfer | Complete-BitsTransfer 
}
$Crlfiles = gci $temppath
$hashinfo =  $crlFiles| Get-FileHash -Algorithm SHA256 | select Hash,Path
$hashgroup = $hashinfo | Group-Object -Property Hash 
$hashsizes = new-object System.Collections.ArrayList
foreach($h in $hashgroup){
$filename=$h.Group.Path| select -First 1
$re= (certutil -dump  $filename | select -first 50) -match "NextUpdate:"
$obj= [pscustomobject]@{
filename=$filename
Hash=$h.Name
ValidityEnds = ($re -REPLACE " NextUpdate: ").Trim()
}
$hashsizes.Add($obj)| Out-Null
}
$objs = new-object System.Collections.ArrayList
foreach($CRLfile in $crlfiles){
$hashinforetreive = ($hashinfo | ?{$psitem.path -eq $CRLFile.FullName} ).Hash
$crlhashretreive = ($hashsizes | ?{$psitem.hash -eq $hashinforetreive}).validityends
$ob = [pscustomobject]@{
VerifiedfromServer = $env:COMPUTERNAME
"ServerIP-CRLName"= $CRLfile.Name
Validityends = $crlhashretreive
}
$objs.add($ob) | Out-Null
}
get-item $temppath | Remove-Item -Force -Recurse | Out-Null
$fullreport=$objs | select *,@{l="Expiring in(Hrs)";e={[int](new-timespan -Start $(get-date) -End $(get-date -Date $PSItem.ValidityEnds)).totalhours}}| Sort-Object -Property 'Expiring in(Hrs)'
$hname = $env:COMPUTERNAME | Out-String
$ipaddr = (Get-NetIPAddress).IPAddress -match "10."
$CRLhtml = $fullreport | ConvertTo-Html -As Table -Fragment -PreContent "<h2>CRL Validity from all the 4 IIS DMZ Servers</h2>" -PostContent "<p><u><b>These are from the 4 Servers $($allcrlIPS -join ",")</b></u></p><p class='footer'>Report generated from $hname - $ipaddr on $(get-date) </p>"| Out-String
$head = @'

<style>

table {
    border-collapse: collapse;
    white-space: normal;
    line-height: normal;
    font-weight: normal;
    font-size: medium;
    font-style: normal;
    color: -internal-quirk-inherit;
    text-align: start;
    border-spacing: 2px;
    font-variant: normal;
}

td {
    display: table-cell;
    border: 1px solid #0078D7;
    vertical-align: inherit;
}

th {
    font-size: 1.1em;
    text-align: center;
    border: 1px solid;
    background-color: #0078D7;
    color: #ffffff;
    }

name tr {
    color: #000000;
    background-color: #0078D7;
}

</style>

'@
$outhtml = ConvertTo-HTML -head $head -PostContent $CRLhtml  -Title "<h2>CRL Validity</h2>"
if($fullreport | ?{$PSItem.'Expiring in(Hrs)' -le 12}){
$Emailsubject = "CRLS are Expiring in 12 Hours"
}
else {
$Emailsubject = "CRLS are Verified and Valid"
}
Send-EmailMessage -To $SummaryRecepients -From "CRL-Entrust-Validity-HeathCheck@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $($Emailsubject | Out-String)  -HTML $outhtml -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov'
