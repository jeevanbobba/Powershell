#$TESTOCSPURL = 'https://dc1vaocspp03.ent.dir.labor.gov:3602/status'
#$EmailDL = "surapaneni.venu@DOL.GOV"
#$testcase="TEST"
$EmailDL = "zzOASAM-OCIO-ISD-IO-WindowsAdmin@DOL.GOV"
$ocspcheckshare = "\\silentfs01.ent.dir.labor.gov\Reports\EntrustProofChecks"
$archivereportsfolder = '\\silentfs01.ent.dir.labor.gov\Reports\EntrustProofChecks\Archive'
$failreportfolder = '\\silentfs01\Reports\EntrustProofChecks\Failures'
function Modify-LocalHostRecord {
    [CmdletBinding()]
    Param(
        [string]$DesiredIP,
        [string]$Hostname,
        [ValidateSet("Add", "Remove")]
        [string]$action,
        [bool]$CheckHostnameOnly = $false
    )
    #Requires -RunAsAdministrator
    $hostsFilePath = "$($Env:WinDir)\system32\Drivers\etc\hosts"
    $hostsFile = Get-Content $hostsFilePath
    if ($action -eq "Add") {
        #Write-Host "About to add $desiredIP for $Hostname to hosts file" -ForegroundColor Gray
        $escapedHostname = [Regex]::Escape($Hostname)
        $patternToMatch = If ($CheckHostnameOnly) { ".*\s+$escapedHostname.*" } Else { ".*$DesiredIP\s+$escapedHostname.*" }
        If (($hostsFile) -match $patternToMatch) {
            Write-Host $desiredIP.PadRight(20, " ") "$Hostname - not adding; already in hosts file" -ForegroundColor DarkYellow
        } 
        Else {
            Write-Host $desiredIP.PadRight(20, " ") "$Hostname - adding to hosts file... " -ForegroundColor Yellow -NoNewline
            Add-Content -Encoding UTF8  $hostsFilePath ("$DesiredIP".PadRight(20, " ") + "$Hostname")
            #Write-Host " done"
        }
    }
    if ($action -eq "Remove") {
        #Write-Host "About to remove $Hostname from hosts file" -ForegroundColor Gray
        $escapedHostname = [Regex]::Escape($Hostname)
        If (($hostsFile) -match ".*\s+$escapedHostname.*") {
            Write-Host "$Hostname - removing from hosts file... " -ForegroundColor Yellow -NoNewline
            $hostsFile -notmatch ".*\s+$escapedHostname.*" | Out-File $hostsFilePath 
            #Write-Host " done"
        } 
        Else {
            Write-Host "$Hostname - not in hosts file (perhaps already removed); nothing to do" -ForegroundColor DarkYellow
        }
    }
}
function Verify-OCSPCheck {
    [CmdletBinding()]
    Param(
        [string]$CERFILE,
        [string]$intercert = "c:\Scripts\OCIO\openssl\Inter.Cer",
        [string]$rootcert = "c:\Scripts\OCIO\openssl\Root.cer",
        [string]$exefile = "c:\Scripts\OCIO\openssl\openssl-3\x64\bin\openssl.exe",
        [string]$tmpfolder = 'C:\Temp\ocsptemp',
        [string]$failreportfolder = '\\silentfs01\Reports\EntrustProofChecks\Failures'
    )
    certutil -f -urlcache * delete | out-null
    ipconfig /flushdns | out-null
    Set-Location -Path $tmpfolder | Out-Null
    $value = Certutil -f  -verify -split -silent -urlfetch $CerFile
    $OCSPIPC = [Net.Dns]::Resolve('ocsp.managed.entrust.com').addresslist.IPAddressTostring
    if ($OCSPIPC) {}else { $OCSPIPC = "No DNS Resolved" }
    $SSPURL = 'http://ocsp.managed.entrust.com/OCSP/EMSSSPCAResponder'
    $RootURL = 'http://ocsp.managed.entrust.com/OCSP/EMSRootCAResponder'
    $CertDataStartlines = for ($i = 0; $i -le $value.count; $i++) { if ($value[$i] -match "CertContext") { $i } }
    $OCSPStartlines = for ($i = 0; $i -le $value.count; $i++) { if ($value[$i] -match "----------------  Certificate OCSP  ----------------") { $i } }
    for ($i = 0; $i -lt $CertDataStartlines.count; $i++) {
        $data = $value[$($CertDataStartlines[$i] + 1)..$($CertDataStartlines[$i + 1] - 1)]
        $OCSPData = $value[$($OCSPStartlines[$i] + 1)..$($OCSPStartlines[$i] + 2)]
        if ($OCSPData -match "Error retrieving URL: ") { $OCSPData = $value[$($OCSPStartlines[$i] + 1)..$($OCSPStartlines[$i] + 3)] }
        if ($OCSPData -match $SSPURL) { $OCSPIP = $SSPURL }
        elseif ($OCSPData -match $RootURL) { $OCSPIP = $RootURL }else { $OCSPIP = "NO IP" }
        if ($data -match "OU=FPKI" -or $OCSPIP -eq 'NO IP') {}else {
            #Write-Output "$OCSP - OCSP IP"
            $SubjectCertd = (($data -match "Subject: " -split ", OU=" -replace "Subject: OU=" -replace "Subject: CN=")[0]).trim()
            if ($SubjectCertd -match 'SSP CA') {
                $Issuercert = $intercert
                $maincert = $cerfile
                $URL = $SSPURL
            }
            else {
                $Issuercert = $rootcert
                $maincert = $intercert
                $URL = $RootURL
            }
            $ErrorActionPreference = "SilentlyContinue"
            $openssldata = invoke-expression "$exefile ocsp -issuer $Issuercert -cert $maincert -text -url $URL"
            $ErrorActionPreference = "Continue"
            $tdata = (($openssldata[-2] -split "Update: ")[1]) -split "GMT" -split " " | Where-Object { $PSItem -ne "" }
            if ($tdata[1].length -eq 1) { $tdata[1] = '0' + $tdata[1] }
            $tdstring = $tdata[0] + '-' + $tdata[1] + '-' + $tdata[2] + '-' + $tdata[3]
            $sd = get-date -date $([Datetime]::ParseExact($tdstring.trim(), 'MMM-dd-HH:mm:ss-yyyy', $null))
            $edata = (($openssldata[-1] -split "Update: ")[1]) -split "GMT" -split " " | Where-Object { $PSItem -ne "" }
            if ($edata[1].length -eq 1) { $edata[1] = '0' + $edata[1] }
            $edstring = $edata[0] + '-' + $edata[1] + '-' + $edata[2] + '-' + $edata[3]
            $ed = get-date -date $([Datetime]::ParseExact($edstring.trim(), 'MMM-dd-HH:mm:ss-yyyy', $null))
            $ST = ($sd.AddHours( - ($(get-timezone -id 'GMT Standard Time').BaseUtcOffset.totalhours)).ToLocalTime()).ToString()
            $ocspCertificate = $openssldata[-3..-1] -match ".cer" -split "\\" -split "\:" -match ".cer" | Out-String
            $OCSPProofhash = ($openssldata[0..10] -match 'Issuer Key Hash: ' -replace 'Issuer Key Hash: ').trim()
            $ET = ($ed.AddHours( - ($(get-timezone -id 'GMT Standard Time').BaseUtcOffset.totalhours)).ToLocalTime()).ToString()
            if ($null -eq $ocspCertificate) { $ST = $ET = $OCSPProofhash = "No Data" }
            $obj = [pscustomobject]@{
                SubjectCert                   = $SubjectCertd
                SubjectCertSerial             = (($data -match "Serial: " -replace "Serial: ")[0]).trim()
                IssuerCA                      = (($data -match "Issuer: " -split ", OU=" -replace "Issuer: OU=")[0]).trim()
                "IssuerCAValidStartDate(EST)" = get-date ($data -match "NotBefore: " -replace "NotBefore: ")[0]
                "IssuerCAValidEndDate(EST)"   = get-date ($data -match "NotAfter: " -replace "NotAfter: ")[0]
                OCSPResponse                  = if ($OCSPData[0] -match "Verified") { "OCSP Verified" }else { "Not Verified" }
                OCSPURL                       = $OCSPIP
                OCSPResolvedIP                = $OCSPIPC
                OCSPProofHash                 = $OCSPProofhash
                "OCSPValidStart(EST)"         = $ST
                "OCSPValidEnd(EST)"           = $ET
            }
            $obj
            if($obj -match "Not Verified|NO DATA|No DNS Resolved" ){
            $value | Add-Content "$failreportfolder\Certutil-ErrorLog-$(get-date -f MMM-dd-yyyy-HH-mm-ss-tt).txt"
            $openssldata | Add-Content "$failreportfolder\openssl-ErrorLog-$(get-date -f MMM-dd-yyyy-HH-mm-ss-tt).txt" 
            }
        }
    }#final ForLoop
    Get-ChildItem $tmpfolder | Remove-Item -Force -Confirm:$false -Recurse
}#Function
#$intercert = "C:\Temp\Inter.cer" #Intermediate Certificate
#$rootcert = "C:\Temp\Root.cer" #Root Certificate
do {
    $Cerfile = (Get-ChildItem "c:\Scripts\OCIO\openssl\certs" | get-random).FullName #Main Certificate
    $Certa = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $Certa.Import("$Cerfile")
}
until(
    $certa.IssuerName.Name -match 'Entrust Managed Services SSP CA' -and $certa.NotAfter -gt $(get-date)
)
$certificateName = ($certa.DnsNameList).unicode
Write-Output "Verifying OCSP Validity for CERTIFICATE - $certificateName"
#using Internal
Modify-LocalHostRecord -Hostname "ocsp.managed.entrust.com" -action Remove
$internalOCSPRES = Verify-OCSPCheck -CERFILE $Cerfile 
#Using External
$pubocsp = (Resolve-DnsName "ocsp.managed.entrust.com" -Type A  -Server "10.50.14.28" -QuickTimeout -DnsOnly).IPAddress
Modify-LocalHostRecord -DesiredIP $pubocsp -Hostname "ocsp.managed.entrust.com" -action Add
$externalOCSPRES = Verify-OCSPCheck -CERFILE $Cerfile 
Modify-LocalHostRecord -Hostname "ocsp.managed.entrust.com" -action Remove
#using Test OCSP
$TESTOCSP = 'dc1vaocspp03.ent.dir.labor.gov'
$TESTOCSPIP = (Resolve-DnsName -Name $TESTOCSP).IPAddress
Modify-LocalHostRecord -DesiredIP $TESTOCSPIP -Hostname "ocsp.managed.entrust.com" -action Add
$testOCSPRES = Verify-OCSPCheck -CERFILE $Cerfile
Modify-LocalHostRecord -Hostname "ocsp.managed.entrust.com" -action Remove
$emailresultsDOL_Frag = $internalOCSPRES | ConvertTo-Html -As Table  -Fragment -PreContent "<h2>Internal OCSP Validation for $certificateName</h2>" | Out-String
$emailresultsENtrust_Frag = $externalOCSPRES | ConvertTo-Html -As Table -Fragment -PreContent "<h2>External OCSP Validation for $certificateName</h2>" | Out-String
$emailresultsTestDOL_Frag = $testOCSPRES | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Test OCSP Validation for $certificateName</h2>" | Out-String
$convertParams = @{ 
    head = @"
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
$body = ConvertTo-HTML @convertParams  -PreContent $emailresultsDOL_Frag, $emailresultsENtrust_Frag, $emailresultsTestDOL_Frag -Title "<h2>OCSP Validation Report $(get-date -Format g) </h2>" -PostContent "<p class='footer'>This Report Runs every 5 minutes.Report generated from $env:COMPUTERNAME on $(get-date)</p>"  -ErrorVariable MorningReportFailure
#$body | out-file C:\Temp\certs.html -Force
$ALLDATA = $internalOCSPRES + $externalOCSPRES + $testOCSPRES
$timeofreport = $(get-date -f MMM-dd-yyyy-hh-mm-ss)
$filename = "$ocspcheckshare\OCSP-ProofChecks-$(get-date -f MMM-dd-yyyy).csv"
$ALLDATA | Select-Object @{l = "ReportTime"; e = { $timeofreport } }, * | Export-Csv $FileName -NoTypeInformation -Append 
$subj = "[Informational]OCSP Validity Check successful"
$SMSfile = "C:\Scripts\OCIO\EntrustNotify.csv"
if ($body -match "Not Verified|NO DATA|No DNS Resolved") {
    $subj = "[Critical]OCSP Validity Check Failure"
    if($internalOCSPRES -match "Not Verified|NO DATA|No DNS Resolved" ){    $subj = "[Critical]OCSP Validity Check Failure - For Internal Entrust Environment"}
    elseif($externalOCSPRES -match "Not Verified|NO DATA|No DNS Resolved" ){    $subj = "[Critical]OCSP Validity Check Failure - For External/DMZ Entrust Environment"}
    elseif($testOCSPRES -match "Not Verified|NO DATA|No DNS Resolved" ){    $subj = "[Warning]OCSP Validity Check Failure - For Test Entrust Environment"}
    $mstatus = Send-EmailMessage -To $EmailDL -From 'OCSP-ProofFileValidity-Check@dol.gov'  -Server 'dc1-smtp.dol.gov' -Subject $subj -DeliveryNotificationOption Never -Verbose -Port 25 -HTML $body -ErrorVariable MSGERR
    $MSGID = $mstatus.Message -match "\d+" | ForEach-Object { $Matches.Values }
    "Sent Failure Email Subject -$subj with MessageID -$MSGID - $(get-date -f MMM-dd-yyyy-hh-mm)" | Add-Content "$ocspcheckshare\Failure-MailTracking.txt"
    if ($msgerr) { $msgerr | Add-Content "$ocspcheckshare\Failure-MailTracking.txt" }
    import-csv $SMSfile | ForEach-Object { Send-EmailMessage -To $($PSItem.Email).trim() -From "EntrustOCSPSSL-CERTUTIL@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $subj  -Text "OCSP SSL CERTUTIL Failure" -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov' -Priority High }
}
#if($testcase="TEST"){
#Send-EmailMessage -To $EmailDL -From 'OCSP-ProofFileValidity-Check@dol.gov'  -Server 'dc1-smtp.dol.gov' -Subject $subj -DeliveryNotificationOption Never -Verbose -Port 25 -HTML $body
#}
#Moving Files to Archive
$filestoMove = Get-ChildItem $ocspcheckshare -Exclude $(Split-Path $filename -Leaf) -Name "*.csv" -File
foreach ($file in $filestoMove) {
    [array]$rvals = $file -match '\-(?<Month>[A-Z]{3})\-\d{2}-(?<Year>\d{4})' | ForEach-Object { $Matches }
    $ffolderpath = "$archivereportsfolder\$($rvals.Year)\$($rvals.Month)"
    if (!(Test-path $ffolderpath)) { New-Item -ItemType Directory -Path $ffolderpath -Force }
    import-csv $ocspcheckshare\$file | Export-Excel "$ffolderpath\$($file -replace ".csv",".xlsx")"
    Remove-Item $ocspcheckshare\$file -Force | Out-Null
}
Remove-Variable * -ErrorAction SilentlyContinue -Force
Remove-Module *
$error.Clear()
