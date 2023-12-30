$OCSPIPS = "DC1VAOCSPP01.ENT.DIR.LABOR.GOV","DC1VAOCSPP02.ENT.DIR.LABOR.GOV","DC2VAOCSPP01.ENT.DIR.LABOR.GOV","DC2VAOCSPP02.ENT.DIR.LABOR.GOV"
$RUNMODE = "PROD" #Valid Options PROD and TEST
$expirytime = 3 #hours to start counting down
$forcetime = 1 #hours to start running the update
$SummaryRecepients = "zzOASAM-OCIO-ISD-IO-WindowsAdmin@DOL.GOV"
$SMSfile = "C:\Scripts\OCIO\EntrustNotify.csv"
$subj = "OCSP Proof Files are Expiring in Less than $expirytime Hours"
if($RUNMODE -eq 'TEST'){
$SMSfile = "C:\Scripts\OCIO\EntrustNotify_TEST.csv"
$SummaryRecepients = "Surapaneni.Venu@dol.gov","WatsonIII.George.A@DOL.GOV","Quintanilla.Raul.H@dol.gov","Onadeko.Eddie@dol.gov","Kleinkauf.Karl.H@dol.gov"
$expirytime = 30
$forcetime = 20
$subj = "TEST - OCSP Proof Files are Expiring in Less than $expirytime Hours"
}

Function Get-HTMLTables{
Param(
[uri]$URL,
[boolean]$firstRowHeader = $false
)
#Ignore SSL
function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    ## We create an instance of TrustAll and attach it to the ServicePointManager
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}  
#Calling function to Ignore the Certificates 
Ignore-SSLCertificates
#Get the webpage
$page = Invoke-WebRequest $URL
 
#Filter out only the tables
$tables = $page.ParsedHtml.body.getElementsByTagName('Table')
 
#Get only the tables that have cells
$tableswithcells = $tables | Where{$_.cells}
$hashPage = @{}
$tablecount = 0
 
#ForEach table
ForEach($table in $tableswithcells){
    $arrTable = @()
    $rownum = 0
    $arrTableHeader = @()
    #Get all the rows in the tables
    ForEach($row in $table.rows){
        #Treat the first row as a header
        if($rownum -eq 0 -and $firstRowHeader){
            ForEach($cell in $row.cells){
                $arrTableHeader += $cell.InnerText.Trim()
            }
            #If not the first row, but using headers, store the value by header name
        }elseIf($firstRowHeader){
            $cellnum = 0
            $hashRow = @{}
            ForEach($cell in $row.cells){
                $strHeader = $arrTableHeader[$cellNum]
                If($strHeader){
                    $hashRow.Add($strHeader,$cell.innertext)
                }else{
                    #If the header is null store it by cell number instead
                    $hashRow.Add($cellnum,$cell.innertext)
                }
                $cellnum++
            }
            #Save the row as a custom ps object
            $objRow = New-object -TypeName PSCustomObject -Property $hashRow
            $arrTable += $objRow
            #if not the first row and not using headers, store the value by cell index
        }else{
            $cellnum = 0
            $hashRow = @{}
            ForEach($cell in $row.cells){
                $hashRow.Add($cellnum,$cell.innertext)
                $cellnum++
            }
            #Store the row as a custom object
            $objRow = New-object -TypeName PSCustomObject -Property $hashRow
 
            #Add the row to the array of rows
            $arrTable += $objRow
        }
        $rownum++
    }
    #Add the tables to the hashtable of tables
    $hashPage.Add($tablecount,$arrTable)
    $tablecount++
}
$objPage = New-object -TypeName PSCustomObject -Property $hashPage
Return $objPage
}
Function ConvertTo-LocalTime {
     [cmdletbinding()]
     [alias("ctlt")]
     [Outputtype([System.Datetime])]
     Param(
         [Parameter(Position = 0, Mandatory, HelpMessage = "Specify the date and time from the other time zone. ")]
         [ValidateNotNullorEmpty()]
         [alias("dt")]
         [string]$Time,
         [Parameter(Position = 1, Mandatory, HelpMessage = "Select the corresponding time zone.")]
         [alias("tz")]
         [string]$TimeZone
     )
     $ParsedDateTime = Get-Date $time
     $tzone = Get-TimeZone -Id $Timezone
     $datetime = "{0:f}" -f $parsedDateTime
     Write-Verbose "Converting $datetime [$($tzone.id) $($tzone.BaseUTCOffSet) UTC] to local time."
     $ParsedDateTime.AddHours(-($tzone.BaseUtcOffset.totalhours)).ToLocalTime()
 }
$AllOCSPServerData = new-object System.Collections.ArrayList
foreach($OCSPServer in $OCSPIPS){
            $OCSPDatacoll = Get-HTMLTables -URL "https://$OCSPserver`:3602/status"
            foreach($r in ($OCSPDatacoll.4)[1..8] ) {
                                 $Resp = [Pscustomobject]@{
                                 "OCSPServerName" = $OCSPServer
                                 "PublicKeyHash" = ($r."1" |Out-String).trim()
                                 "OCSPLoaded"  = ConvertTo-LocalTime $(get-date -date (($r."5" ) -split " UTC")[0]) -TimeZone UTC
                                 "OCSPValidityStart"  = ConvertTo-LocalTime $(get-date -date (($r."6" ) -split " UTC")[0]) -TimeZone UTC
                                 "OCSPValidityEnd"  = ConvertTo-LocalTime $(get-date -date (($r."7" ) -split " UTC")[0]) -TimeZone UTC
                                 "OCSPExpiry(Hrs)" = [math]::Round((New-TimeSpan -Start $(get-date) -End $(ConvertTo-LocalTime $(get-date -date (($r."7" ) -split " UTC")[0]) -TimeZone UTC)).TotalHours)
                        }#Custom Object
                        $AllOCSPServerData.Add($resp)|Out-Null
                        }#Foreach Loop
}
$expiryocsps = $AllOCSPServerData | ?{$PSItem.'OCSPExpiry(Hrs)' -le $expirytime}
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
#For LEss than 3 Hours
if($expiryocsps){
$outhtml = $expiryocsps | ConvertTo-Html -As Table -Fragment -PreContent "<h2>OCSP Proof Files Expiring in Less than $expirytime Hours </h2>" | Out-String
$finalhtml = ConvertTo-HTML -head $head -PostContent $outhtml -PreContent "<h2>OCSP Proof Files Script. This Script runs every 30 mins from 5AM to 10PM</h2>"
$mstatus = Send-EmailMessage -To $SummaryRecepients -From "EntrustOCSPStatus@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $subj  -HTML $finalhtml -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov' -Priority High
$MSGID = $mstatus.Message -match "\d+" | ForEach-Object { $Matches.Values }
"Sent OCSP Proof Files Expiry Warning with Subject -$subj with MessageID -$MSGID - $(get-date -f MMM-dd-yyyy-hh-mm)" | Add-Content "\\silentfs01.ent.dir.labor.gov\Reports\EntrustProofChecks\Failure-MailTracking.txt" 
import-csv $SMSfile | %{Send-EmailMessage -To $($PSItem.Email).trim() -From "EntrustOCSPStatus@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $($Emailsubject | Out-String)  -Text $subj -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov' -Priority High}
}
#For Less than one Hour Initiate a Update
$inlessthan1hour = $AllOCSPServerData | ?{$PSItem.'OCSPExpiry(Hrs)' -le $forcetime}
foreach($e in $inlessthan1hour){
$OCSPServer = $e.OCSPServerName
Invoke-WebRequest "https://$OCSPserver`:3602/status" -UseBasicParsing -Method Post
Invoke-WebRequest "https://$OCSPserver`:3602/update" -UseBasicParsing -Method Get
}