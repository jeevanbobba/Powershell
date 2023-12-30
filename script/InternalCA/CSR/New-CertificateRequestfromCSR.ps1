<#	
	.NOTES
	===========================================================================
	 Created on:   	05/22/2021
	 Updated on: 05/04/2022
	 Created by:   	Venu Surapaneni
	 Organization: 	OASAM/OCIO/WindowsServerTeamOperations
	 Filename:  New-CertificateRequestfromCSR
	===========================================================================
	.DESCRIPTION
		This File Generates the Certificate and Invokes a Workflow 
             Gets the Data from the Excel
             Signs the CSR and ZIPS,Encrypts and Send to the EMAIL
             Password Email will be seperately sent
             Saves the Data to Sharepoint List
			 Added Force Intercative Login to avoid saving credentials
			 Added New ZIP passworc Calculation

    .EXAMPLE
     Typical Usage
      #.\New-CertificateRequestfromCSR.ps1 -excelFile "D:\CSR-files\may21-Venu\5212021.xlsx" 
     
     For Testing only to Specific EMail
      #.\New-CertificateRequestfromCSR.ps1 -SMTPPasswdEmail "Surapaneni.venu@dol.gov" -excelFile "D:\CSR-files\may21-Venu\5212021.xlsx"


#>
[CmdletBinding()]
param (
	$excelFile,
	$SMTPPasswdEmail = "zzOASAM-OCIO-ITOS-Cert-Management@Dol.gov",
	[string]$SharePointSiteURL = "https://usdol.sharepoint.com/sites/T-OASAM-OCIO-Windows_Admins",
	[string]$SharePointListName = "Certificate Capture Information"
)
Function New-CertificateFromCSR
{
	[CmdletBinding()]
	param (
		[string]$CSRFile,
		[string]$ExportPath,
		[String]$CAServerName,
		[String]$templateName,
		[String]$ChangeReq,
		[String]$Requester,
		[String]$ApplicationName,
		[String]$SupportingGroupforapplication,
		[String]$FEDPOC,
		[String]$SupportteamDL,
		[String]$Agency,
		[String]$Requestdate,
		[String]$Commonname,
		[String]$Keysize,
		[String]$Environment,
		[String]$SANNames,
		[String]$EnhancedKeyUsage,
		[String]$EMailServer,
		[array]$CertSenderEmail,
		[string]$EmailFrom,
		[string]$PasswdDLEmail,
		$SharePointConnectionDetails,
		[string]$WorkingTemporaryPath
	)
	$ErrorActionPreference = "Stop"
    $listdetails = Get-PnPList -connection $SharePointConnectionDetails | Where-Object{ $PSItem.Title -eq $SharePointListName }
	$CA = Connect-CA -ComputerName $CAServerName -ErrorAction Stop
    Write-Output "Connected to $CAServerName"
	$CertDataReport = New-Object System.Collections.ArrayList
    $datefile = get-date -Format sshhMMddyyyy
	New-Item -ItemType Directory -Path "$WorkingTemporaryPath\$datefile" -force | Out-Null
	$Certpath = "$WorkingTemporaryPath\$datefile"
    $CSR = get-item $CSRFile
	$CSRExtensionType = (get-item $CSR.FullName).Extension
	Write-Output "The CertPath is $CertPath and Extension is $CSRExtensionType" 
    if ($CSRExtensionType)
	{
      Copy-item $CSR.FullName -Destination $("$certpath\$($CSR.Name)" -replace "$CSRExtensionType", ".csr")	 
      	}
	else
	{
	 Copy-item $CSR.FullName -Destination $("$certpath\$($CSR.Name)" + ".csr")
	}
	$filename = (Get-ChildItem $certpath -Filter "*.csr").FullName
	$ExistingCSR = Get-CertificateRequest -Path $filename
	$CommonnamefromCSR = ($ExistingCSR.Subject -split "CN=")[1] -replace ",.*", "$2"
	$emailFromCSR = if ($ExistingCSR.Subject -match "(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b") { $Matches[0] }
	$keyLengthfromCSR = $ExistingCSR.PublicKey.Key.KeySize
	$SANNamesfromCSR = ($ExistingCSR.Extensions | Where-Object { $_.Oid.FriendlyName -eq "subject alternative name" }).format(0) -replace "DNS Name="
	$CARequest = Submit-CertificateRequest -Path $filename -CertificationAuthority $CA -Attribute "CertificateTemplate:$templateName"
    Write-Output "The Cert is submitted to CA" 
	$ApprovedCA = Get-CertificationAuthority -Name $CA.DisplayName | Get-PendingRequest -ID $($CARequest.RequestID) | Approve-CertificateRequest
	Write-Output "The Cert is Approved by CA"
    $requestrow = Get-CertificationAuthority -Name $CA.DisplayName | Get-IssuedRequest -RequestID $($CARequest.RequestID)
	if ($null -eq $requestrow )
	{
		Write-Output "Denied .."
		$CARequest
		Exit
	}
	$finalfile = Receive-Certificate -RequestRow $requestrow -Path $Certpath -Force -ErrorVariable RCVCERTFailure
	if ($RCVCERTFailure)
	{
		Write-Output "Failed to Retreive FileName .."
		$RCVCERTFailure
		$finalfile
		Write-Output " $certpath Failed ..$requestrow "
		Exit
	}
	$filenameafterExport = (Get-ChildItem $certpath -Filter "*.cer").FullName
	$finalfilename = ($finalfile.Subject -split "CN=")[1] -replace ",.*", "$2"
	New-item -ItemType Directory -Path $Certpath -Name "RootandSubCA" -Force | Out-Null
	New-item -ItemType Directory -Path $Certpath -Name "CSR" -Force | Out-Null
	$Tp = "8535a72c3b1943659adcf8992f2c6f480692a9e7","18c038f22b0404b150bc3f740002f9ce5a1b4907","0edb33af66bebd6a3c5880d526a2414a3c67f48c" #List Prod Thumbprints
	$allrootcerts = Get-ChildItem Cert:\LocalMachine -Recurse | Where-Object{ $_.Subject -match "CN=DEV-ENT|CN=TEST-ENT|CN=STAGE-ENT"  -or $PSitem.Thumbprint -in $Tp -and $PSitem.NotAfter -gt $(get-date) }
	$allrootcerts | ForEach-Object{ Export-Certificate -Type CERT -Cert "Cert:\$(Split-Path $PSItem.pspath -NoQualifier)" -FilePath "$Certpath\ROOTandSUBCA\$(($PSItem.Subject -replace "CN=" -split ",")[0]).Cer" -Force } | Out-Null
	Move-Item $filename  "$Certpath\CSR\" -Force
	Move-item $filenameafterExport  "$Certpath\$finalfilename.cer" -force
	$expirydate = get-date -date $($finalfile.NotAfter) -UFormat "Expiry-%m-%d-%Y"
	$Issueddate = get-date -date $($finalfile.NotBefore) -UFormat "Issued-%m-%d-%Y"
	#Add-Type -AssemblyName 'System.Web'
	#$ZipPassword = [System.Web.Security.Membership]::GeneratePassword(10,2)
	#$ZipPassword = -join ((65 .. 90) + (97 .. 122) + (48 .. 57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
	$ZipPassword =(get-verb | get-random -Count 3).Verb+ (('+-*=@$').ToCharArray()|get-random -Count 1) + (('0123456789').ToCharArray()|get-random -Count 2) -join""
	Compress-7Zip -ArchiveFileName $($finalfilename + "_" + $Expirydate + ".zip") -Path "$Certpath" -OutputPath $ExportPath -Format Zip -Password $ZipPassword
	$FullZipName = $ExportPath + "\" + $finalfilename + "_" + $Expirydate + ".zip"
	$certDataReport = [pscustomobject]@{
		'Title' = $($CARequest.RequestID)
		'Change (CR#)' = $ChangeReq
		'Requester' = $Requester
		'Requester(FromActualCSR)' = $emailFromCSR
		'Application Name' = $ApplicationName
		'Supporting Group for application' = $SupportingGroupforapplication
		'FED POC' = $FEDPOC
		'Support team DL' = $SupportteamDL
		'Agency' = $Agency
		'Request Date' = get-date -Date $Requestdate
		'Common name' = $Commonname
		'Common name(FromActualCSR)' = $CommonnamefromCSR
		'Keysize' = $Keysize
		'Keysize(FromActualCSR)' = $keyLengthfromCSR
		'Environment' = $Environment
		'SAN Names' = $SANNames
		'SAN Names(FromActualCSR)' = $SANNamesfromCSR
		'Enhanced Key Usage' = $EnhancedKeyUsage
		'Cert Issuer' = $CAServerName
		'Cert Template' = $templateName
		'Cert Effective Date' = $(get-date -date $($finalfile.NotBefore) -UFormat "%m-%d-%Y")
		'Cert Expiration Date' = $(get-date -date $($finalfile.NotAfter) -UFormat "%m-%d-%Y")
		'Creator' = $env:USERDOMAIN+'\'+$env:USERNAMe
	}
	#$CertDataReport |  Export-Clixml "D:\PS_Venu\certdatareport.xml" -Force
	#$Fields = Get-PnPField -List $listdetails.ID
	Write-Output "ZIP Password is $ZipPassword . The Final ZIP file is located at $FullZipName"
	$convertParams = @{
		head = @"
 <Title>Certificate Key</Title>
<style>
table {
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    text-align: center;
}

td {
    border: 1px solid #0078D7;
}

th {
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
"@
	}
	Send-EmailMessage -Server $EMailServer -From $EmailFrom -To $CertSenderEmail -Subject "Certificate for $finalfilename.Please Reach out to Windows Team for Decrypting the Zip File" -Attachment $FullZipName -DeliveryNotificationOption Never -ErrorVariable MailFailure -Text "Please Reach out to Windows Team DL (zzOASAM-OCIO-ITOS-Cert-Managment@Dol.gov) for Decrypting the Zip File" -Port 25 | Out-Null
	Write-Output "Sent Email"
    $Passwd_Frag = $CertDataReport | ConvertTo-Html -As List -Fragment -PreContent "<h2>Extended Properties for the ZIP FileLocated on $FullZipName</h2>" -PostContent "<h2>This Script is ran from the $env:COMPUTERNAME using $env:USERNAME in $env:USERDNSDOMAIN on $(Get-date) </h2>" | Out-String
	$passwdBody = ConvertTo-HTML @convertParams -PreContent "<h2>Key for the Zip File $ZipPassword</h2>" -PostContent $Passwd_Frag
	Send-EmailMessage -Server $EMailServer -From $EmailFrom -To $PasswdDLEmail -Subject "Key for Certificate $finalfilename" -DeliveryNotificationOption Never -ErrorVariable MailFailure -Port 25 -HTML $passwdBody | Out-Null
	Write-Output "Sent Password Email"
    if($listdetails){
    $SPlist = Add-PnPListItem -connection $SharePointConnectionDetails -List $listdetails.Id -ErrorVariable SharePointWriteError -values @{
		'Title' = $certDataReport.'Title'
		'Change_x0020__x0028_CR_x0023__x0' = $certDataReport.'Change (CR#)'
		'Requester' = $certDataReport.'Requester'
		'Application_x0020_Name' = $certDataReport.'Application Name'
		'Supporting_x0020_Group_x0020_for' = $certDataReport.'Supporting Group for application'
		'FED_x0020_POC' = $certDataReport.'FED POC'
		'Support_x0020_team_x0020_DL' = $certDataReport.'Support team DL'
		'Agency' = $certDataReport.'Agency'
		'Request_x0020_date' = $certDataReport.'Request Date'
		'Common_x0020_name' = $certDataReport.'Common name'
		'Keysize' = $certDataReport.'Keysize'
		'Environment_x0020__x0028_DEV_x00' = $certDataReport.'Environment'
		'SAN_x0020_Names_x0020__x003a__x0' = $certDataReport.'SAN Names'
		'Enhanced_x0020_Key_x0020_Usage_x' = $certDataReport.'Enhanced Key Usage'
		'Cert_x0020_Issuer' = $certDataReport.'Cert Issuer'
		'Cert_x0020_Template' = $certDataReport.'Cert Template'
		'Cert_x0020_Effective_x0020_Date' = $certDataReport.'Cert Effective Date'
		'Cert_x0020_Expiration_x0020_Date' = $certDataReport.'Cert Expiration Date'
		'Creator' = $certDataReport.'Creator'
	} -ErrorAction Stop -ContentType "Item"
    if ($SharePointWriteError) { Write-Output "Cannot Write to the Sharepoint" }
    }
    else{
    Write-Output "Cannot Write to SharePoint as The connection was Denied"
    }
	Remove-Item -Recurse "$WorkingTemporaryPath\$datefile" -Force | Out-Null
	
}
	try{
	$SPConnectionDetails = Connect-PnPOnline -Url $SharePointSiteURL -Interactive -LaunchBrowser -ForceAuthentication -ReturnConnection
	}
    catch {
    Write-Output "Cannot Connect to SharePoint Online"
    }
$modules = "pspki", "7Zip4Powershell", "PnP.PowerShell", "ImportExcel", "Mailozaurr"
foreach ($module in $modules)
{
	Import-Module $module -Force -ErrorAction SilentlyContinue -ErrorVariable ModuleError
	if ($moduleError)
	{
		try
		{
			Write-Output "Cannot Find Module ..Importing Module - $module"
			Install-Module $module -Force -Scope CurrentUser -Confirm:$false
		}
		catch
		{
			Write-Output "Failed to Install $module"
		}
		
	}
}
Import-Module $modules -ErrorVariable ModuleImportError -ErrorAction Stop
if ($moduleImportError)
{
	Write-Output "Could Not Import All Required Modules"
	Exit
}
$certdata = Import-Excel $excelFile -DataOnly
$certArray = New-Object System.Collections.ArrayList
$AllCerts = ($certdata[14] | get-member | Where-Object{ $PSItem.Name -match "Certificate \d+" }).Name
foreach ($certreq in $AllCerts)
{
	#Checking to see If the CA Server Info is Filled in 
	if ($certdata[15]."$certreq")
	{
		$certlist = [pscustomobject]@{
			'ChangeReq' = $certdata[0]."$certreq"
			'Requester' = $certdata[1]."$certreq"
			'Application Name' = $certdata[2]."$certreq"
			'Supporting Group for application' = $certdata[3]."$certreq"
			'FED POC'   = $certdata[4]."$certreq"
			'Support team DL' = $certdata[5]."$certreq"
			'Agency'    = $certdata[6]."$certreq"
			'Request date' = [DateTime]::FromOADate($certdata[7]."$certreq").tostring("MM-dd-yyyy")
			'Common name' = $certdata[8]."$certreq"
			'Keysize'   = $certdata[9]."$certreq"
			'Environment' = $certdata[10]."$certreq"
			'SAN Names' = $certdata[11]."$certreq"
			'Enhanced Key Usage' = $certdata[12]."$certreq"
            'Request ID' = $certdata[13]."$certreq"
			'CA Server' = $certdata[15]."$certreq"
			'Cert Template' = $certdata[16]."$certreq"
			
		}
		$certArray.Add($certlist) | Out-Null
	}
}
foreach ($CSRLine in $certArray)
{
	if (Test-Connection $CSRLine.'CA Server' -Quiet -Count 1)
	{
		[string]$domain = ($CSRLine.'CA Server' -split "\.")[1 .. 6] -join "."
		switch ($domain)
		{
			'dev-ent.dev-dir.labor.gov' {
				$SMTPServer = "smtp.dev.dol.gov"
				$SMTPToEmail = "CertificateAuthority@dev.dol.gov"
				$ShareExportPath = "\\coe_dev_nas.dev-ent.dev-dir.labor.gov\COE-DEV-Certs"
			}
			'test-ent.test-dir.labor.gov' {
				$SMTPServer = "smtp.test.dol.gov"
				$SMTPToEmail = "CertificateAuthority@test.dol.gov"
				$ShareExportPath = "\\COE_test_NAS.test-ENT.test-DIR.LABOR.GOV\COE-TEST-Certs"
			}
			'stage-ent.stage-dir.labor.gov' {
				$SMTPServer = "smtp.stage.dol.gov"
				$SMTPToEmail = "CertificateAuthority@stage.dol.gov"
				$ShareExportPath = "\\COE_stage_NAS.stage-ENT.stage-DIR.LABOR.GOV\COE-STAGE-Certs"
			}
			'ent.dir.labor.gov' {
				$SMTPServer = "dc1-smtp.dol.gov"
				$SMTPToEmail = "CertificateAuthority@dol.gov"
				$ShareExportPath = "\\SILENTFS01.ent.dir.labor.gov\MGTOPS\Scrips_Certs\CSR\IssuedCerts"
			}
			
			
		}
		$CSRFile = get-item "$(split-path $excelfile)\$($CSRLine.'Request ID')"
		New-CertificateFromCSR -CSRFile $CSRFile -ExportPath $ShareExportPath -CAServerName $CSRLine.'CA Server' -templateName $CSRLine.'Cert Template' -EMailServer $SMTPServer -PasswdDLEmail $SMTPPasswdEmail -CertSenderEmail $CSRLine.Requester -EmailFrom $SMTPToEmail -ChangeReq $CSRLine.ChangeReq -Requester $CSRLine.Requester -ApplicationName $CSRLine.'Application Name' -SupportingGroupforapplication $CSRLine.'Supporting Group for application' -FEDPOC $CSRLine.'FED POC' -SupportteamDL $CSRLine.'Support team DL' -Agency $CSRLine.Agency -Requestdate $CSRLine.'Request date' -Commonname $CSRLine.'Common name' -Keysize $CSRLine.Keysize -Environment $CSRLine.Environment -SANNames $CSRLine.'SAN Names' -EnhancedKeyUsage $CSRLine.'Enhanced Key Usage' -SharePointConnectionDetails $SPConnectionDetails  -WorkingTemporaryPath $env:TEMP
	}
}
