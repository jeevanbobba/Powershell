<#	
	.NOTES
	===========================================================================
	 Created on:   	05/26/2022
     Last Modified : 07/07/2022
	 Created by:   	Venu Surapaneni
	 Organization: 	OASAM/OCIO/WindowsServerTeamOperations
	 Filename:  Provision-UserAccountandAVD.ps1
     ===========================================================================
	.DESCRIPTION
		This Script Creates the user account in DEV/TEST/STAGE and creates a WVD in Azure , Need Agency and Ticket Information 
               if user already exists in the corresponding Environment(Checking by comparing the Employeenumber attrib to prod email account)  ..this script will not do anything
                Adds the EmployeeNumber as prod email to help reset the password
                Adds the User to the AZ groups in Prod. for Billing
                Need Email Relay Authorized to run this Script (Additional Details Please Contact T3 EMail Team)
                Need Following Modules 
                          Azure (Provision AZure VM)
                          Mailozaurr (Sending Email)
                          AD CmdLets (Create AD Account)
                Need Access to GitLab to get the Provisioing and Template JSON 
                This Will not impact an Existing and Enabled Non-Production Account
                Currently only supports only these agencies 
                           "ETA"
                           "OASAM"
                           "AE"
                           "ET"
                           "EBSA"
                           "OSHA"
                           "MSHA"
                           "WHD"
                           "OWCP"
                           "OFCCP"
                Currently only supports these Environments (For User Creation)
                           "COE-DEV"
                           "COE-TEST"
                           "COE-STAGE"

				ChangeLog:
				 5/31 - Changed user create function to address SamAccountName ending with Period
                 7/5/22 - Added COE-TEST and STAGE svc. accounts  to the keystore and had some cosmetic changes
                 7/7/22 - Added Credential to ruleout mismatched Subscriptions


    .EXAMPLE
     Typical Usage
      Always Run this Script from a Management Server using Elevated Account on Production
	   
	  #.\Provision-UserAccountandAVD.ps1 -COEENV "COE-DEV" -ProvisioningMode "User_With_AVD"  -Agency OASAM -Ticket "CRQ165421" -Prodemail "LastName.FirstName@dol.gov"  -FedLeadEmail "UserLead@dol.gov" 

       
      If you want to bulk process Accounts or Machines ..Define the Credential and call it in the function ..
        $AZCred = Get-Credential #Put your Email and Password on Pop-Up
        $CSVFile with headers Agency,Ticket,ProdEmail,FedLeadEmail
        $objs = Import-csv $CSVFile
        foreach($obj in $objs){
          .\Provision-UserAccountandAVD.ps1 -COEENV "COE-DEV" -ProvisioningMode "User_With_AVD"  -Agency $obj.Agency -Ticket  $obj.Ticket -Prodemail  $obj.Prodemail  -FedLeadEmail $obj.FedLeademail -AZcred $azcred
         }
	 
      #If you are having Azure Login issues Try These 3 commands
	  Disconnect-AzAccount 
	  $Cred = Get-Credential #Put your Email and Password on Pop-Up
	  Connect-AzAccount -SubscriptionId "f03da233-2925-4557-b7cc-5f6200da4d49" -Force -WarningAction SilentlyContinue -Tenant "75a63054-7204-4e0c-9126-adab971d4aca" -Credential $cred
      

#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true, Position = 0, HelpMessage = "Environment ")]
	[ValidateSet("COE-DEV", "COE-TEST", "COE-STAGE")]
	[String]$COEENV,
	[Parameter(Mandatory = $true, Position = 1, HelpMessage = "Script Mode ")]
	[ValidateSet("User_With_AVD", "User_Only", "AVD_Only")]
	[String]$ProvisioningMode,
	[Parameter(HelpMessage = "AzureSubscription")]
	[String]$AZsubs = 'f03da233-2925-4557-b7cc-5f6200da4d49',
	[Parameter(HelpMessage = "AzureTenantID")]
	[String]$AZTenantID = "75a63054-7204-4e0c-9126-adab971d4aca",
	[Parameter(Mandatory = $true, Position = 2, HelpMessage = "Agency that user is Supporting")]
	[ValidateSet("ETA", "OASAM", "AE", "ET", "EBSA", "OSHA", "MSHA", "WHD", "OWCP", "OFCCP")]
	[String]$Agency,
	[Parameter(Mandatory = $true, Position = 3, HelpMessage = "TicketNumber")]
	[string]$Ticket,
	[Parameter(Mandatory = $true, Position = 4, HelpMessage = "Production Email Address")]
	[string]$ProdEmail,
	[Parameter(Mandatory = $true, Position = 5, HelpMessage = "Federal Lead Email Address")]
	[string]$FedLeadEmail,
	[Parameter(Mandatory = $false, Position = 6, HelpMessage = "Provide Production Azure Credential")]
	[System.Management.Automation.PSCredential]$AzCred = $(Get-Credential -Message "Enter Production Credential" -UserName "")
)
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
switch ($COEENV)
{
	'COE-DEV' {
		$LBIP = "10.50.14.31"
		$COEENVENT = "DEV-ENT.DEV-DIR.LABOR.GOV"
		$domainprefix = "dev-ent"
		$creduser = "dev-ent\s-azurevd"
		$credsecretname = "DEVDomainJoin"
		if ($Agency -eq "ETA")
		{
			$DomainOU = 'OU=Win10Developers,OU=ETA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.ETA'
			$AzGroup = 'avd-dev-eta-users'
			$resourcegroup = 'eta-dev-ocio-avd-ue-rg'
			$hostpool = 'ETAVDIDHP'
			$CompObjOUPath = 'OU=WIN10,OU=ETA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "OASAM")
		{
			$DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OASAM'
			$AzGroup = 'avd-dev-itos-users'
			$resourcegroup = 'oasam-dev-ocio-avd-ue-rg'
			$hostpool = 'OCIOVDIDHP'
			$CompObjOUPath = 'OU=OCIO,OU=NO,OU=OASAM,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "AE")
		{
			$DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OASAM'
			$AzGroup = 'avd-dev-ae-users'
			$resourcegroup = 'oasam-dev-ae-avd-ue-rg'
			$hostpool = 'AEVDIDHP'
			$CompObjOUPath = 'OU=OCIO,OU=NO,OU=OASAM,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "ET")
		{
			$DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OASAM'
			$AzGroup = 'avd-dev-et-users'
			$resourcegroup = 'oasam-dev-et-avd-ue-rg'
			$hostpool = 'ETVDIDHP'
			$CompObjOUPath = 'OU=OCIO,OU=NO,OU=OASAM,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "EBSA")
		{
			$DomainOU = 'OU=Win10Developers,OU=EBSA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.EBSA'
			$AzGroup = 'avd-dev-ebsa-users'
			$resourcegroup = 'ebsa-dev-ocio-avd-ue-rg'
			$hostpool = 'EBSAVDIDHP'
			$CompObjOUPath = 'OU=WIN10,OU=EBSA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "OSHA")
		{
			$DomainOU = 'OU=Win10Developers,OU=OSHA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OSHA'
			$AzGroup = 'avd-dev-osha-users'
			$resourcegroup = 'osha-dev-ocio-avd-ue-rg'
			$hostpool = 'OSHAVDIDHP'
			$CompObjOUPath = 'OU=WIN10,OU=OSHA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "MSHA")
		{
			$DomainOU = 'OU=Win10Developers,OU=MSHA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.MSHA'
			$AzGroup = 'avd-dev-msha-users'
			$resourcegroup = 'msha-dev-ocio-avd-ue-rg'
			$hostpool = 'MSHAVDIDHP'
			$CompObjOUPath = 'OU=WIN10,OU=MSHA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "WHD")
		{
			$DomainOU = 'OU=Win10Developers,OU=WHD,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.WHD'
			$AzGroup = 'avd-dev-whd-users'
			$resourcegroup = 'whd-dev-ocio-avd-ue-rg'
			$hostpool = 'WHDVDIDHP'
			$CompObjOUPath = 'OU=WHD,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "OWCP")
		{
			$DomainOU = 'OU=Win10Developers,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OWCP'
			$AzGroup = 'avd-dev-owcp-users'
			$resourcegroup = 'owcp-dev-ocio-avd-ue-rg'
			$hostpool = 'OWCPVDIDHP'
			$CompObjOUPath = 'OU=OWCP,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
		if ($Agency -eq "OFCCP")
		{
			$DomainOU = 'OU=Win10Developers,OU=OFCCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OFCCP'
			$AzGroup = 'avd-dev-OFCCP-users'
			$resourcegroup = 'ofccp-dev-ocio-avd-ue-rg'
			$hostpool = 'OFCCPVDIDHP'
			$CompObjOUPath = 'OU=OFCCP,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
		}
	}
	'COE-TEST' {
		$LBIP = "10.52.13.42"
		$COEENVENT = "TEST-ENT.TEST-DIR.LABOR.GOV"
		$domainprefix = "test-ent"
		$creduser = "test-ent\s-AVD-userprov"
		$credsecretname = "coe-test"
		if ($Agency -eq "ETA")
		{
			$DomainOU = 'OU=Win10Testusers,OU=ETA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.ETA'
			#$AzGroup = 'avd-Test-eta-users'
		}
		if ($Agency -eq "OASAM")
		{
			$DomainOU = 'OU=Win10Testusers,OU=OASAM_OCIO,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.OASAM'
			#$AzGroup = 'avd-Test-itos-users'
		}
		if ($Agency -eq "AE")
		{
			$DomainOU = 'OU=Win10Testusers,OU=OASAM_OCIO,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.OASAM'
			$AzGroup = 'avd-Test-ae-users'
		}
		if ($Agency -eq "ET")
		{
			$DomainOU = 'OU=Win10Testusers,OU=OASAM_OCIO,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.OASAM'
			#$AzGroup = 'avd-Test-et-users'
		}
		if ($Agency -eq "EBSA")
		{
			$DomainOU = 'OU=Win10Testusers,OU=EBSA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.EBSA'
			#$AzGroup = 'avd-Test-ebsa-users'
		}
		if ($Agency -eq "OSHA")
		{
			$DomainOU = 'OU=Win10Testusers,OU=OSHA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.OSHA'
			#$AzGroup = 'avd-Test-osha-users'
		}
		if ($Agency -eq "MSHA")
		{
			$DomainOU = 'OU=Win10Testusers,OU=MSHA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.MSHA'
			#$AzGroup = 'avd-Test-msha-users'
		}
		if ($Agency -eq "WHD")
		{
			$DomainOU = 'OU=Win10Testusers,OU=WHD,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.WHD'
			#$AzGroup = 'avd-Test-whd-users' 
		}
		if ($Agency -eq "OWCP")
		{
			$DomainOU = 'OU=Win10Testusers,OU=OWCP,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.OWCP'
			#$AzGroup = 'avd-Test-owcp-users' 
		}
		if ($Agency -eq "OFCCP")
		{
			$DomainOU = 'OU=Win10Testusers,OU=OFCCP,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.testusers.OFCCP'
			#$AzGroup = 'avd-Test-OFCCP-users'
		}
	}
	'COE-STAGE' {
		$LBIP = "10.53.11.197"
		$COEENVENT = "STAGE-ENT.STAGE-DIR.LABOR.GOV"
		$domainprefix = "stage-ent"
		$creduser = "stage-ent\s-AVD-userprov"
		$credsecretname = "coe-stage"
		if ($Agency -eq "ETA")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=ETA,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.ETA'
			#$AzGroup = 'avd-Stage-eta-users'
		}
		if ($Agency -eq "OASAM")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=OASAM_OCIO,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.OASAM'
			#$AzGroup = 'avd-Stage-itos-users'
		}
		if ($Agency -eq "AE")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=OASAM_OCIO,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.OASAM'
			#$AzGroup = 'avd-Stage-ae-users'
		}
		if ($Agency -eq "ET")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=OASAM_OCIO,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.OASAM'
			#$AzGroup = 'avd-Stage-et-users'
		}
		if ($Agency -eq "EBSA")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=EBSA,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.EBSA'
			#$AzGroup = 'avd-Stage-ebsa-users'
		}
		if ($Agency -eq "OSHA")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=OSHA,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.OSHA'
			#$AzGroup = 'avd-Stage-osha-users'
		}
		if ($Agency -eq "MSHA")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=MSHA,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.MSHA'
			#$AzGroup = 'avd-Stage-msha-users'
		}
		if ($Agency -eq "WHD")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=WHD,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.WHD'
			#$AzGroup = 'avd-Stage-whd-users'
		}
		if ($Agency -eq "OWCP")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=OWCP,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.OWCP'
			#$AzGroup = 'avd-Stage-owcp-users'
		}
		if ($Agency -eq "OFCCP")
		{
			$DomainOU = 'OU=Win10Stageusers,OU=OFCCP,OU=Accounts,DC=Stage-ent,DC=Stage-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.Stageusers.OFCCP'
			#$AzGroup = 'avd-Stage-OFCCP-users'
		}
	}
	
}
Disconnect-AzAccount | Out-Null
Connect-AzAccount -SubscriptionId $AZsubs -Force -Credential $AzCred -ErrorAction Stop -Tenant $AZTenantID | Out-Null
Set-AzContext -Subscription $AZsubs -Tenant $AZTenantID | Out-Null
[securestring]$newuserpass = (Get-AzKeyVaultSecret -VaultName oasam-dev-ocio-avd-kv -Name useraccountpass).secretValue
[securestring]$credpass = (Get-AzKeyVaultSecret -VaultName oasam-dev-ocio-avd-kv -Name $credsecretname).secretValue
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $creduser, $credpass
if ($ProvisioningMode -ne 'AVD_Only')
{
	$COEENVDCIP = (Resolve-DnsName -Name $COEENVENT -Server $LBIP -Type "A" | Select-Object -First 1).IpAddress
	$ProdADDetails = get-aduser -filter { mail -eq $prodemail } -Server ent.dir.labor.gov -Properties *
	[Array]$getUserinENV = (get-adforest -Server $COEENVDCIP -Credential $Cred).domains | ForEach-Object {
		$s = (Resolve-DnsName -Name $PSItem -Server $LBIP -Type "A").IpAddress | %{ if (Test-Connection $PSItem -Quiet -count 2) { $PSItem } } | select -First 1
		get-aduser -filter { Employeenumber -eq $prodemail } -Server $s -Credential $cred -Properties Employeenumber -erroraction silentlycontinue
	}
	if ($getUserinENV.count -gt 1)
	{
		Write-Output "Multiple Accounts Exist  $COEENV Environment - $(($getUserinENV).DistinguishedName)"
		Write-Output "..............................."
		Write-Output "The Script will Exit"
		break
	}
	
	if ($getUserinENV.count -eq 1 -and $getUserinENV.Enabled)
	{
		Write-Output "The User Already exist in the $COEENV Environment - $(($getUserinENV).DistinguishedName)"
		#$getUserinENV
		Write-Output "..............................."
		Write-Output "The Script will Exit"
		break
	}
}
function Add-COEuser()
{
	param (
		[string]$OUPath,
		[String]$COEENV,
		[string]$AgencyWKSAdminGroup,
		[string]$Dserver,
		[System.Management.Automation.PSCredential]$Cred,
		[Microsoft.ActiveDirectory.Management.ADAccount]$ProdADDetails,
		[securestring]$passwd,
		[string]$domainprefix,
		[string]$description
	)
	#
	$starttime = Get-Date
	if ($COEENV -eq 'COE-DEV') { $user = 'z-' + $ProdADDetails.SamAccountName }
	else { $user = $ProdADDetails.SamAccountName }
	if ($user.Length -gt 20) { $user = $user.Substring(0, 20) }
	if ($user[-1] -eq '.') { $user = $user.Substring(0, 19) }
	#Write-Output "Working on $user in $COEENV Domain" 
	try
	{
		Get-ADUser $user -Server $Dserver -Credential $cred
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
		New-aduser -SamAccountName $user -Name $ProdADDetails.Name -Server $Dserver -Enabled:$true -AccountPassword $passwd -Path $OUpath -Credential $cred
	}
	finally
	{
		Set-ADUser -Identity $user -Description $description -Server $Dserver -Credential $cred -EmployeeNumber $ProdADDetails.mail -UserPrincipalName $ProdADDetails.UserPrincipalName -DisplayName $ProdADDetails.DisplayName -Surname $ProdADDetails.Surname -GivenName $ProdADDetails.GivenName -Department $ProdADDetails.Department
		Add-ADPrincipalGroupMembership -Identity $user -Server $Dserver -MemberOf $AgencyWKSAdminGroup -Credential $cred
		if (!((get-aduser $user -Server $Dserver -Properties Enabled -Credential $cred).Enabled))
		{
			Set-ADAccountPassword -Identity $user -Reset -NewPassword $passwd -Server $Dserver -Confirm:$false -Credential $cred
			Set-ADUser -Identity $user -Description $description -ChangePasswordAtLogon:$true -Enabled:$true -Server $Dserver -Credential $cred
			Move-ADObject (Get-Aduser $user -Server $Dserver -Credential $cred) -Server $Dserver -TargetPath $OUpath -Confirm:$false -Credential $cred
		}
	}
	$finishTime = Get-Date
	$UserSummary = [PSCustomObject]@{
		DeveloperSamAccount = $domainprefix + '\' + $user
		Environment		    = $COEENV
		DevAgency		    = $AgencyWKSAdminGroup -replace "ent.devusers." -replace "ent.Stageusers." -replace "ent.testusers."
		ProdEmailAddress    = $ProdADDetails.mail
		CreatedBy		    = $cred.UserName
		ScriptRanFrom	    = $env:COMPUTERNAME
		ScriptRanAccount    = (Get-AzAccessToken).userID
		"UserDeploymentDuration(Seconds)" = [int](New-TimeSpan $starttime $finishTime).TotalSeconds
	}
	return $UserSummary
	
	
}
function Add-AVDVM()
{
	param (
		[string]$VMNAME,
		[String]$Agency,
		[string]$resourcegroup,
		[string]$hostpool,
		[string]$useremail,
		[string]$fedleademail,
		[string]$subnetname = 'oasam-dev-ocio-avd-ue-subnet1',
		[string]$devuser,
		[string]$developerSamAccount,
		[string]$templatefile,
		[string]$parameterfile,
		[securestring]$devuserpass,
		[securestring]$secpwd,
		[string]$CompObjOUPath
	)
	#Write-Output "Your Current Variables: VM Name: $vmName Domain: $VMDomain, Resource Group: $resourcegroup, Security Group $AzGroup, Host Pool: $hostpool, User Email: $useremail, Fed Lead Email: $fedleademail"
	$starttime = Get-Date
	$tags = @{
		DevVMUser	     = $useremail
		DevVMFedlead	 = $fedleademail
		DevVMAgency	     = $Agency
		ProvisioningMode = "Script"
		ProvisionedBy    = (Get-AzAccessToken -WarningAction SilentlyContinue).userID
	}
	$datestring = (Get-Date).ToString("s").Replace(":", "-")
	[string]$deploymentname = $vmName + "_" + $datestring
	[string]$vmNwInterfaceName = "NIC-" + $VMNAME
	$hostpooltoken = (New-AzWvdRegistrationInfo -ResourceGroupName $resourcegroup -HostPoolName $hostpool -ExpirationTime $((get-date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))).token
	#-HostPoolToken $hostpooltoken `
	$AZRStuff = New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup `
											  -TemplateFile $templatefile `
											  -TemplateParameterFile $Parameterfile `
											  -HostPoolToken $hostpooltoken `
											  -domainUsername $devuser `
											  -domainPassword $devuserpass `
											  -adminPassword $secpwd `
											  -ouPath $CompObjOUPath `
											  -networkInterfaceName $vmNwInterfaceName `
											  -name $deploymentname `
											  -virtualMachineRG $resourcegroup `
											  -virtualMachineName $vmName `
											  -virtualMachineComputerName $vmName `
											  -resourceTags $tags `
											  -subnetName $subnetname `
											  -hostPoolName $hostpool
	#Write-Output "Assigning $useremail to $vmname" 
	[string]$sessionhostname = $vmname + ".dev-ent.DEV-DIR.LABOR.GOV"
	Update-AzWvdSessionHost -HostPoolName $hostpool -Name $sessionhostname -ResourceGroupName $resourcegroup -AssignedUser $useremail | Out-Null
	$IP = (Get-AzNetworkInterface -Name $vmNwInterfaceName -ResourceGroupName $resourcegroup).IpConfigurations.PrivateIpAddress
	#Write-OutPut "$vmName - $ip deployed and assigned to $useremail"
	$finishTime = Get-Date
	$VMSummary = [PSCustomObject]@{
		VMNAME			    = $VMNAME
		UserEmail		    = $useremail
		FedLeadEmail	    = $fedleademail
		Agency			    = $Agency
		DeveloperSamAccount = if ($developerSamAccount) { $developerSamAccount }else{ "Script is Running in AVD Mode" }
		Subnetname		    = $subnetname
		HostPool		    = $hostpool
		IpAddress		    = $IP
		CreatedBy		    = (Get-AzAccessToken -WarningAction SilentlyContinue).userID
		ScriptRanFrom	    = $env:COMPUTERNAME
		"VMDeploymentDuration(Seconds)" = [int](New-TimeSpan $starttime $finishTime).TotalSeconds
	}
	return $VMSummary
}
Start-Sleep -Seconds 1
if ($ProvisioningMode -ne 'AVD_Only')
{
	$userProv = Add-COEuser -COEENV $COEENV -Cred $cred -Dserver $COEENVDCIP -ProdADDetails $ProdADDetails -OUPath $DomainOU -AgencyWKSAdminGroup $DomainAdminGroup -description "$COEENV User Account-$Ticket" -passwd $newuserpass -domainprefix $domainprefix
	
	if ($COEENV -eq 'COE-DEV')
	{
		Write-Output "Adding Azure Group Membership"
		$ProdADDetails | Add-ADPrincipalGroupMembership -MemberOf $AzGroup -PassThru | out-null
	}
	else
	{
		Write-Output "$COEENV User Created and  Group Membership Added"
	}
}
if ($ProvisioningMode -ne 'User_Only')
{
<#
$Parameterfile =((New-Object System.Net.WebClient).DownloadString('https://gitlab.dol.gov/WindowsAdminTeam/script/-/raw/main/AVD/parameters.json'))
$templatefile =((New-Object System.Net.WebClient).DownloadString('https://gitlab.dol.gov/WindowsAdminTeam/script/-/raw/main/AVD/template.json'))
$templatefile | add-content $("$env:TEMP\Templatefile.json") -Force
$Parameterfile | add-content $("$env:TEMP\Parameterfile.json") -Force
$templatefile = "$env:TEMP\Templatefile.json"
$Parameterfile = "$env:TEMP\Parameterfile.json"
#>
	$templatefile = "\\Silentfs01.ent.dir.labor.gov\mgtops\Scrips_Certs\AVD-Scripted\template.json"
	$Parameterfile = "\\Silentfs01.ent.dir.labor.gov\mgtops\Scrips_Certs\AVD-Scripted\parameters.json"
	[securestring]$secpwd = (Get-AzKeyVaultSecret -VaultName oasam-dev-ocio-avd-kv -Name devlocaladmin).SecretValue
	#Write-Output "Retreiving AVD Instances"
	$AZVMDATA = Get-AzVM -Name "AVD*"
	$lastVMIncrement = ($AZVMDATA | Where-Object{ $PSItem.Tags.ProvisioningMode -eq 'Script' }).Name | ForEach-Object{ if ($PSItem -match "\d{3}") { $matches.Values } } | Sort-Object -Descending | Select-Object -First 1
	$ALLVMNumbers = ($AZVMDATA).Name | ForEach-Object{ if ($PSItem -match "\d{3}") { $matches.Values } }
	[int]$VMNumber = $lastVMIncrement
	do
	{
		$VMNumber++
	}
	while ($ALLVMNumbers -contains $VMNumber)
	[string]$VMNumber = "{0:000}" -f $VMNumber
	$VMNAME = "AVD" + $Agency + "D" + $VMNumber
	$devsamaccount = $userProv.DeveloperSamAccount
	write-output "Creating AVD-$VMNAME for $ProdEmail"
	$VMProvDetails = Add-AVDVM -VMNAME $VMNAME -Agency $Agency -resourcegroup $resourcegroup -hostpool $hostpool -useremail $ProdEmail -fedleademail $FedLeadEmail -CompObjOUPath $CompObjOUPath -devuser $creduser -devuserpass $credpass -secpwd $newuserpass -developerSamAccount $devsamaccount -templatefile $templatefile -parameterfile $Parameterfile
}
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
$CCEMAILDL = "zzoasam-ocio-itos-ops-vm-provisioning@dol.gov", "zzoasam-ocio-itos-ops-windows-admins@dol.gov"
#$CCEMAILDL = "surapaneni.venu@dol.gov"
$VMProv = $VMProvDetails | Select-Object VMNAME, UserEmail, FedLeadEmail, Agency, DeveloperSamAccount, Subnetname, HostPool, IpAddress, CreatedBy, ScriptRanFrom, "VMDeploymentDuration(Seconds)"
$uProv = $userProv | select-object DeveloperSamAccount, DevAgency, ProdEmailAddress, CreatedBy, ScriptRanFrom, ScriptRanAccount, "UserDeploymentDuration(Seconds)"
if ($ProvisioningMode -eq 'User_With_AVD')
{
	$subj = "[Informational]User and VDI Provisioned for Ticket  $Ticket "
	$emailDL = "Flaim.Bruno.I@dol.gov", "Anderson.Ravan@dol.gov", "Hargrove.Deon.E@dol.gov","schmelzer.daniel.f@dol.gov”,“vasquez.jose.j@dol.gov”
	$email_UserFrag = $uProv | ConvertTo-Html -As List -Fragment -PreContent "<h2>User Provisioning Details</h2>" | Out-String
	$email_VMFrag = $VMProv | ConvertTo-Html -As List -Fragment -PreContent "<h2>VM Provisioning Details</h2>" | Out-String
	$body = ConvertTo-HTML @convertParams -PreContent $email_VMFrag, $email_UserFrag -Title "<h2>AVD User and VM Provisioning Summary</h2>" -PostContent "<p class='footer'>This is an automated Email generated as part of the VDI Provisioing . Please Contact VM Provisioing Team (via ESD) for further Information.</p>"
}
if ($ProvisioningMode -eq 'AVD_Only')
{
	$subj = "[Informational]VDI Provisioned for Ticket  $Ticket "
	$emailDL = "Flaim.Bruno.I@dol.gov", "Anderson.Ravan@dol.gov", "Hargrove.Deon.E@dol.gov","schmelzer.daniel.f@dol.gov”,“vasquez.jose.j@dol.gov”
	$email_VMFrag = $VMProv | ConvertTo-Html -As List -Fragment -PreContent "<h2>VM Provisioning Details</h2>" | Out-String
	$body = ConvertTo-HTML @convertParams -PreContent $email_VMFrag -Title "<h2>AVD Provisioning Summary</h2>" -PostContent "<p class='footer'>This is an automated Email generated as part of the VDI Provisioing . Please Contact VM Provisioing Team (via ESD) for further Information.</p>"
}
if ($ProvisioningMode -eq 'User_Only')
{
	$subj = "[Informational]User Provisioned for Ticket  $Ticket "
	$emailDL = $CCEMAILDL
	$email_UserFrag = $uProv | ConvertTo-Html -As List -Fragment -PreContent "<h2>User Provisioning Details</h2>" | Out-String
	$body = ConvertTo-HTML @convertParams -PreContent $email_UserFrag -Title "<h2>User Provisioning Summary</h2>" -PostContent "<p class='footer'>This is an automated Email generated as part of the User Provisioning . Please Contact Windows Server Administrator Team (via ESD) for further Information.</p>"
}
$mstatus = Send-EmailMessage -To $EmailDL -CC $CCEMAILDL -From 'AVD-Provisioning-COE-NonProduction@dol.gov' -Server 'dc1-smtp.dol.gov' -Subject $subj -DeliveryNotificationOption Never -Verbose -Port 25 -HTML $body -ErrorVariable MSGERR
$MSGID = $mstatus.Message -match "\d+" | ForEach-Object { $Matches.Values }
"Sent  Email with Subject $subj and  MessageID -$MSGID - to $emailDL and CC'd - $CCEMAILDL"
#"Sent  Email with MessageID -$MSGID - $(get-date -f MMM-dd-yyyy-hh-mm)" | Add-Content "\VDI-MailTracking.txt"
