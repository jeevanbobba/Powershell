# Import AD module
Import-Module ActiveDirectory

# Domain names in forest
$ForestInfo = Get-ADForest
$Domains = $forestInfo.domains
$CurrentDate = Get-Date -Format 'MM-dd-yyyy_HH mm'
#$CurrentDate = $CurrentDate.ToString('MM-dd-yyyy_hh-mm-ss')
 
# Get your ad domain
$DomainName = (Get-ADDomain).DNSRoot
# $DomainName = (Get-ADforest).Domains
 
# Setup email parameters
$subject = "DEV-Domain Controllers"# in $DomainName"
$priority = "Normal"
$smtpServer = "smtp.dev.dol.gov"
#$smtpServer = "smtp.dev-ent.DEV-DIR.LABOR.GOV" # "esa-smtp.esa.dir.labor.gov"
$emailFrom = "bobba.jeevan@dev.dol.gov"
$emailTo = "bobba.jeevan@dol.gov"
$emailBcc = "Katneni.Krishna.C@dol.gov"
#$emailTo = (Get-ADUser -Identity $ENV:Username -Properties mail).mail
$port = 25
 
 #Get all DC's
<# $allDCs = $null
$AllDCs = Get-ADDomainController -Filter * -Server $DomainName | Select-Object Hostname,Ipv4address,isGlobalCatalog,Site,Forest,OperatingSystem
  
$allDCs = Get-ADDomainController -Filter * -Server $Domainname | Select-Object Hostname,Ipv4address,isGlobalCatalog,Site,Forest,OperatingSystem
#>
# get all domina
$ForestObj = Get-ADForest 
$AllDCs = foreach($Domain in $ForestObj.Domains) {Get-ADDomainController -Filter * -Server $domain | Select-Object Domain,Hostname,Ipv4address,isGlobalCatalog,Site,Forest,OperatingSystem}

<#
foreach($Domain in $ForestObj.Domains) {
    Get-ADDomainController -Filter * -Server $Domain | select Domain,Hostname,Ipv4address,isGlobalCatalog,Site,Forest,OperatingSystem
     
}
#>


# Create empty DataTable object
$DCTable = New-Object System.Data.DataTable
      
# Add columns
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[0].Caption = "Domain"
$DCTable.Columns[0].ColumnName = "Domain"

$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[1].Caption = "Hostname"
$DCTable.Columns[1].ColumnName = "Hostname"
  
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[2].Caption = "IPv4Address"
$DCTable.Columns[2].ColumnName = "IPv4Address"
                      
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[3].Caption = "isGlobalCatalog"
$DCTable.Columns[3].ColumnName = "isGlobalCatalog"
$DCTable.Columns[3].DataType = "Boolean"
  
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[4].Caption = "Site"
$DCTable.Columns[4].ColumnName = "Site"
  
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[5].Caption = "Forest"
$DCTable.Columns[5].ColumnName = "Forest"
  
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[6].Caption = "OperatingSystem"
$DCTable.Columns[6].ColumnName = "OperatingSystem"
 
$DCTable.Columns.Add() | Out-Null
$DCTable.Columns[7].Caption = "PingStatus"
$DCTable.Columns[7].ColumnName = "PingStatus"

 
# Loop each DC                        
ForEach($DC in $AllDCs)
{  
    $ping = ping $DC.Hostname -n 1 | Where-Object {$_ -match "Reply" -or $_ -match "Request timed out" -or $_ -match "Destination host unreachable"}
 
    switch ($ping)
    {
        {$_ -like "Reply*" }                          { $PingStatus = "Success" }
        {$_ -like "Request timed out*"}               { $PingStatus = "Timeout" }
        {$_ -like "Destination host unreachable*"}    { $PingStatus = "Unreachable" }
        default                                       { $PingStatus = "Unknown" }
    }
          
    $DCTable.Rows.Add(  
                        $DC.Domain,
                        $DC.Hostname,
                        $DC.Ipv4address,
                        $DC.isGlobalCatalog,
                        $DC.Site,
                        $DC.Forest,
                        $DC.OperatingSystem,
                        $PingStatus
                              
                        )| Out-Null                          
}
 
# Display results in console 
$DCTable | Sort-Object Site | Format-Table
 
#Creating head style
$Head = @"
<style>
  body {
    font-family: "Arial";
    font-size: 8pt;
    }
  th, td, tr { 
    border: 1px solid #e57300;
    border-collapse: collapse;
    padding: 5px;
    text-align: center;
    }
  th {
    font-size: 1.2em;
    text-align: left;
    background-color: #003366;
    color: #ffffff;
    }
  td {
    color: #000000;
     
    }
  .even { background-color: #ffffff; }
  .odd { background-color: #bfbfbf; }
  h6 { font-size: 12pt; 
       font-color: black;
       font-weight: bold;
       }
 
 text { font-size: 10pt;
        font-color: black;
        }
 }
</style>
"@
 
 
# Email body
[string]$body = [PSCustomObject]$DCTable | Select-Object Domain,Hostname,Ipv4address,isGlobalCatalog,Site,Forest,OperatingSystem,PingStatus | Sort-Object -Property Site | ConvertTo-HTML -Head $head -Body "<h6>Domain Controllers</h6></font>"
 $body|export-csv "D:\jb\ADReport\resport_$CurrentDate.csv"

# Send the report email
#Send-MailMessage -SmtpServer $smtpServer -To $emailTo -Bcc $emailBcc -Subject $subject -BodyAsHtml $body -Port $port -From $emailFrom -Priority $priority
Send-MailMessage -SmtpServer $smtpServer -To $emailTo -Subject $subject -BodyAsHtml $body -Port $port -From $emailFrom -Priority $priority
 