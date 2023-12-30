$externalAddr = "http://216.117.52.142:8080/ocspproofs"
$externalAddr2 = "http://148.66.194.74:8080/ocspproofs"
$InternalAddr = "http://entcrl.dol.gov/proofs"
$InternalAddr2 = "http://entcrl.dol.gov/proofs2"
$DMZIPS = "10.49.2.47","10.49.2.48", "10.57.12.33","10.57.12.34"
$OCSPIPS = "DC1VAOCSPP01.ENT.DIR.LABOR.GOV","DC1VAOCSPP02.ENT.DIR.LABOR.GOV","DC2VAOCSPP01.ENT.DIR.LABOR.GOV","DC2VAOCSPP02.ENT.DIR.LABOR.GOV"
#$SummaryRecepients = "surapaneni.venu@DOL.GOV"
$SummaryRecepients = "zzOASAM-OCIO-ISD-IO-WindowsAdmin@DOL.GOV"
$rootfolder = "\\silentfs01.ent.dir.labor.gov\Reports\Entrust"
$folderpath = "$rootfolder\$(get-date -Format yyyyMMdd)"
if (!(Test-path $folderpath)) { New-Item -ItemType Directory -Path "$rootfolder\" -Name "$(get-date -Format yyyyMMdd)" -Force -Confirm:$false | Out-Null }
$EmailserverAddress = "smtp.dol.gov" 
$htmlfile = "$folderpath" + "\" + "Full_Report-" + "$(get-date -Format yyyyMMdd_HH-mm)" + ".html"
#Do NOT MODIFY 
$externalprffiles=@()
$internalprffiles=@()
$externalprffiles2=@()
$internalprffiles2=@()
$extstatus=$null
$OCSPstatus=@()
$DMZstatus = @()
$OCSPhtml =@()
$OCSPConnstatus = @()
$ipaddr = (Get-NetIPAddress).IPAddress -match "10."
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
#Calculate for External Files
if(Test-NetConnection $([uri]$externalAddr).Host -Port $([uri]$externalAddr).Port -WarningAction SilentlyContinue -InformationLevel Quiet){

            $Filenames = ((invoke-webrequest $externalAddr -DisableKeepAlive -UseBasicParsing -Method Get ).links).href -match "Federal"
            foreach($name in $Filenames){ 
                    $props = $(Invoke-webrequest "$externalAddr`/$name" -DisableKeepAlive -UseBasicParsing -Method Head).Headers
                    $externalprffiles += [Pscustomobject]@{
                    FileName = $name -replace "%20",""
                    FileSize = $props.'Content-Length'
                    ModifiedDate = $props.'Last-Modified'
            }
             }


}
else {
    $extstatus = "Connection to External Entrust DR Failed"
}
#Calculate for DR External Files
if(Test-NetConnection $([uri]$externalAddr2).Host -Port $([uri]$externalAddr2).Port -WarningAction SilentlyContinue -InformationLevel Quiet){

            $Filenames = ((invoke-webrequest $externalAddr2 -DisableKeepAlive -UseBasicParsing -Method Get ).links).href -match "Federal"
            foreach($name in $Filenames){ 
                    $props = $(Invoke-webrequest "$externalAddr2`/$name" -DisableKeepAlive -UseBasicParsing -Method Head).Headers
                    $externalprffiles2 += [Pscustomobject]@{
                    FileName = $name -replace "%20",""
                    FileSize = $props.'Content-Length'
                    ModifiedDate = $props.'Last-Modified'
            }
             }


}
else {
    $extstatus = "Connection to External Entrust Failed"
}

#Calculate for Internal Files on GLSB
if(Test-NetConnection $([uri]$InternalAddr).Host -Port $([uri]$InternalAddr).Port -InformationLevel Quiet -WarningAction SilentlyContinue){
            $GSLBIPResol = (Resolve-DnsName $([uri]$internalAddr).Host).IPAddress
            $Filenames = ((invoke-webrequest "$InternalAddr" -DisableKeepAlive -UseBasicParsing -Method Get ).links).href -match "Federal" -replace $([URI]$InternalAddr).PathAndQuery -replace "\/"
            foreach($name in $Filenames){ 
                    $props = $(Invoke-webrequest "$InternalAddr`/$name" -DisableKeepAlive -UseBasicParsing -Method Head).Headers
                    $Internalprffiles += [Pscustomobject]@{
                    FileName = $name -replace "%20",""
                    FileSize = $props.'Content-Length'
                    ModifiedDate = $props.'Last-Modified'
            }
             }
            


}
else {
    $GSLBIntstatus = "Connection to Internal Entrust Failed"
}
#Calculate for Internal Files 
if(Test-NetConnection $([uri]$InternalAddr2).Host -Port $([uri]$InternalAddr2).Port -InformationLevel Quiet -WarningAction SilentlyContinue){
            $GSLBIPResol = (Resolve-DnsName $([uri]$internalAddr2).Host).IPAddress
            $Filenames = ((invoke-webrequest "$InternalAddr2" -DisableKeepAlive -UseBasicParsing -Method Get ).links).href -match "Federal" -replace $([URI]$InternalAddr2).PathAndQuery -replace "\/"
            foreach($name in $Filenames){ 
                    $props = $(Invoke-webrequest "$InternalAddr2`/$name" -DisableKeepAlive -UseBasicParsing -Method Head).Headers
                    $Internalprffiles2 += [Pscustomobject]@{
                    FileName = $name -replace "%20",""
                    FileSize = $props.'Content-Length'
                    ModifiedDate = $props.'Last-Modified'
            }
             }
            


}
else {
    $GSLBIntstatus = "Connection to InternalProof Files2 Failed"
}
#Calculate for Internal Files on Individual DMZ Servers 
$DMZColl  = @()       
foreach($IP in $DMZIPS){
            if(Test-NetConnection $IP  -Port 80 -InformationLevel Quiet){
            $name = "http://$IP`/proofs"
            $Filenames = ((invoke-webrequest "$InternalAddr" -DisableKeepAlive -UseBasicParsing -Method Get ).links).href -match "Federal" -replace $([URI]$InternalAddr).PathAndQuery -replace "\/"
            foreach($name in $Filenames){ 
            $DMZColl += [pscustomobject]@{
                                            Server = $IP
                                            FileName = $name -replace "%20",""
                                            FileSize = $props.'Content-Length'
                                            ModifiedDate = $props.'Last-Modified'
                                            }
            }
            
  }

else {
    $DMZstatus += "Connection to DMZ Server $IP Failed"
}
}
#Check OCSP Ind Servers
foreach($OCSPServer in $OCSPIPS){
            $OCSPResp=@()
            $OCSPDatacoll= $null
            try{
            $OCSPDatacoll = Get-HTMLTables -URL "https://$OCSPserver`:3602/status"}
            catch {$OCSPConnstatus +="OCSP Failure on $OCSPServer"}
            if($OCSPDatacoll.3 -match "entcrl.dol.gov"){
            ($OCSPDatacoll.3)[1..10] | % {$OCSPResp += [Pscustomobject]@{
                                URL = $PSItem | Select-Object -ExpandProperty "0"
                                Status =$PSItem | Select-Object -ExpandProperty "1"
                                "Last Retreived" =$PSItem | Select-Object -ExpandProperty "2"
                                "Last Modified"  = $PSItem | Select-Object -ExpandProperty "3"
                                "Last Size" = $PSItem | Select-Object -ExpandProperty "4"
                        }#Custom Object
                        if($OCSPResp.Status -notmatch "Loaded"){$OCSPstatus +="OCSP Proof Files Expired on $OCSPServer"}
                        }#Foreach Loop
                        $OCSPhtml += $OCSPResp | ConvertTo-Html -As Table -Fragment -PreContent "<h2>OCSP Status on https://$OCSPserver`:3602/status</h2>" | Out-String
                        
            }
            else
            {
              $OCSPConnstatus +="OCSP Failure on $OCSPServer"
            }
               
}
$OCSPHtmlFrag = $OCSPhtml | Out-String

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
$hname = $env:COMPUTERNAME | Out-String
#Compare the Files and Present as a Table
$tableResults = Compare-Object -ReferenceObject $externalprffiles -DifferenceObject $internalprffiles -Property FileName -IncludeEqual 
$ExternalProofFrag  = $externalprffiles | ConvertTo-Html -As Table -Fragment -PreContent "<h2>External Proof Files Status Resolved Using $externalAddr</h2>" | Out-String
$ExternalProofFrag2  = $externalprffiles2 | ConvertTo-Html -As Table -Fragment -PreContent "<h2>External Proof Files Status Resolved Using $externalAddr2</h2>" | Out-String
$InternalProofFrag  = $Internalprffiles | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Internal Proof Files Status Resolved Using $InternalAddr (GSLB  Resolved to $GSLBIPResol) </h2>" | Out-String
$InternalProofFrag2 = $Internalprffiles2 | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Internal Proof Files Status Resolved Using $InternalAddr2 (GSLB  Resolved to $GSLBIPResol) </h2>" -PostContent "<h4><b><i>Running from $ipaddr - $hname</b></i></h4>" | Out-String
$ComparisonFrag = $tableResults | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Proof Files Comparison As of $(get-date)</h2>"  | Out-String
$outhtml = ConvertTo-HTML -head $head -PostContent $OCSPHtmlFrag,$ComparisonFrag,$ExternalProofFrag,$ExternalProofFrag2,$InternalProofFrag,$InternalProofFrag2  -Title "<h2>Entrust Proof File Status</h2>"
$finalhtml = $outhtml -replace "==","Same on External and Internal" -replace "&lt;=","Cannot Find On Internal Server" -replace "&lt;=","Cannot Find On External Server" -replace "SideIndicator","Status(FileName Only)" -Replace ('Cannot Find On Internal Server', '<font color="red">Cannot Find On Internal Server</font>')  
$finalhtml | Out-File $htmlfile -Force
$Emailsubject = "Entrust Proof File Replication Status"
if($extstatus){$Emailsubject = $extstatus}
if($GSLBIntstatus){$Emailsubject = $GSLBIntstatus}
if($DMZstatus){$Emailsubject = $DMZstatus}
if($OCSPstatus){$Emailsubject = $OCSPstatus}
if($OCSPConnstatus){$Emailsubject = $OCSPConnstatus}
if($null -eq $externalprffiles2 -or $null -eq $externalprffiles){$Emailsubject = "Issues With Reaching to ExtrenalProofFiles"}
#sendEmail -EmailFrom "EntrustOCSPStatus@dol.gov" -EmailTo $SummaryRecepients -Emailserver $EmailserverAddress -EmailSubject $Emailsubject  -EmailBody $finalhtml
Send-EmailMessage -To $SummaryRecepients -From "EntrustOCSPStatus@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $($Emailsubject | Out-String)  -HTML $finalhtml -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov' -Priority High
if($Emailsubject -ne "Entrust Proof File Replication Status"){
$smslist = import-csv C:\Scripts\OCIO\EntrustNotify.csv
#$smslist | %{Send-EmailMessage -To $($PSItem.Email).trim() -From "EntrustOCSPStatus@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $($Emailsubject | Out-String)  -Text "Testing SMS Provider for $($PSItem.Name) and $($PSItem.'Phone Number')" -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov' -Priority High}
$smslist | %{Send-EmailMessage -To $($PSItem.Email).trim() -From "EntrustOCSPStatus@dol.gov" -Server 'dc1-smtp.dol.gov' -Subject $($Emailsubject | Out-String)  -Text "Something Wrong with Entrust OCSP Appliances .Please Login and Check" -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror -ReplyTo 'EnterpriseServiceDesk@dol.gov' -Priority High}
}
if($mailerror){"Email Failed - $mailerror" | Add-Content "$folderpath\mailissues.txt"}