<#
       .NOTES
       ===========================================================================
       Created on:        09/04/2019
       Last Modified: 09/17/2019
       Created by:        Venu Surapaneni
       Organization:      DOL\OCIO\Windows Server Team
       Filename:    All_User_Accounts_Active.ps1
       ===========================================================================
       .DESCRIPTION
        HighLights
              Script to Report on All Users (Exclude all Service,Elevated,Resource and Test Accounts).
        Variables for Script
          File Dump Location
          LDAP Filter
          Domains that need the Consolidated Info
          Function to determine real Last Logondate
          9/17 - Added Disabled Accounts as well
          03/24/2020 - Added Company
        
#>

##Variables
#$exportfilepath = "\\silentfs01.ent.dir.labor.gov\Reports\ADUserReports\All_User_Account_Summary-$(get-date -Format MM-dd-yyyy_HH-mm).csv"
#$exportfilepath = "\\silvmdevfile01\workflowdata\Weekly-Report\All_User_Account_Summary-$(get-date -Format MM-dd-yyyy_HH-mm).csv"
$exportfilepath = "\\silvmdevfile01\workflowdata\Daily-report\All_User_Account_Summary-$(get-date -Format MM-dd-yyyy_HH-mm).csv"
$ADFilter = { UserPrincipalName -ne "$null"}
$ForestInfo=Get-ADForest
$Domains =$forestInfo.domains
#$domains = "oasam.dir.labor.gov", "oalj.dir.labor.gov", "apps.dir.labor.gov", "dir.labor.gov", "EBSADOL.dir.labor.gov", "ent.dir.labor.gov", "esa.dir.labor.gov", "eta.dir.labor.gov", "msha.dir.labor.gov", "osha.dir.labor.gov"

##Functions
function LastLogonConvert ($ftDate)
{
       $Date = [DateTime]::FromFileTime($ftDate)
       if ($Date -lt (Get-Date '1/1/1900') -or $date -eq 0 -or $Date -eq $null) { "Never" }
       else { $Date }
}
#Finding PDC if not finding the Shortest path
foreach ($domain in $domains)
{
       $domainInfo = (Get-ADDomain -Server $domain)
       $DCS = $domainInfo.ReplicaDirectoryServers
       $PDCServer = $domainInfo.PDCEmulator
       $NetBiosname = $domainInfo.NetBiosName
       if (Test-Connection $PDCServer -Quiet)
       {
              $GetReportDC = $PDCServer
       }
       else
       {
              #Or get the Closet DC
              $GetReportDC = (Test-Connection $DCS -count 1 | Sort-Object ResponseTime | Select-Object  Address -First 1).Address
       }
       
       $DomainRawData = Get-ADUser -Filter $ADFilter -Server $GetReportDC -Properties DisplayName, SamAccountName, UserPrincipalName, EmailAddress, WhenCreated, WhenChanged, lastLogonTimestamp, Enabled, DistinguishedName, proxyAddresses, Company
       #Exclude the Non User Accounts
       
       $DomainRawData | ?{ ($_.SamAccountName -notlike "z-*") -and ($_.SamAccountName -notlike "zz*") -and ($_.SamAccountName -notlike "adm-*") -and ($_.SamAccountName -notlike "m-*") -and ($_.SamAccountName -notlike "s-*") -and ($_.SamAccountName -notlike "t-*") -and ($_.SamAccountName -notlike "s_*") -and ($_.SamAccountName -notlike "zx*") } | select @{ l = "Domain Name"; e = { $NetBiosname } }, DisplayName, SamAccountName, UserPrincipalName, EmailAddress, WhenCreated, WhenChanged, @{ Name = 'Last Logon Date'; Expression = { LastLogonConvert ($_.LastLogonTimeStamp) } }, Enabled, DistinguishedName, @{ l = "proxyAddress"; e = { $_.proxyAddresses -match '@+[a-z0-9.]+.gov' -notmatch 'x500' -replace "SMTP:" } },Company | export-csv $exportfilepath -Append -NoTypeInformation
}
