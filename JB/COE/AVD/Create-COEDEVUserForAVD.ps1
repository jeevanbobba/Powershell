<#	
	.NOTES
	===========================================================================
	 Created on:   	03/24/2022
	 Created by:   	Venu Surapaneni
	 Organization: 	OASAM/OCIO/WindowsServerTeamOperations
	 Filename:  Create-COEDEVUserForAVD.ps1
     Sha1Value: 66E49E8BBA200AC5F96D3850401B6652A6C68A91
	===========================================================================
	.DESCRIPTION
		This Script Creates the user account in DEV , Need Agency and Ticket Information 
               if user already exists in DEV (Checking by comparing the Employeenumber attrib to prod email account)  ..this script will not do anything
               Also adds the EmployeeNumber as prod email to help reset the password
               Also adds the User to the AZ groups in Prod. for Billing
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


    .EXAMPLE
     Typical Usage
      #.\Create-COEDEVUserForAVD.ps1 -Agency OASAM -Ticket "CRQ165421" -Prodemail "LastName.FirstName@dol.gov" 

      The above command will ask for Development Credentails
#>
[CmdletBinding()]
Param(
        [Parameter(Mandatory=$true,Position = 0,HelpMessage = "Agency that user is Supporting")]
        [ValidateSet("ETA","OASAM","AE","ET","EBSA","OSHA","MSHA","WHD","OWCP","OFCCP")]
        [String]$Agency,
        [Parameter(Mandatory=$true,Position = 1,HelpMessage = "TicketNumber")]
        [string]$Ticket,
        [Parameter(Mandatory=$true,Position = 2,HelpMessage = "Production Email Address")]
        [string]$Prodemail,
        [Parameter(Mandatory=$false,Position = 3,HelpMessage = "Provide Development Credential")]
        [System.Management.Automation.PSCredential]
        $Cred= $(Get-Credential -Message "Enter Dev-Domain Credentials" -UserName "DEV-DIR\")

    )
#$cred =Get-Credential -Message "Enter Dev-Domain Credentials" -UserName "DEV-DIR\"  #Development Credential
# Do not Edit Below this Line
$DEVENTDCIP = (Resolve-DnsName -Name "dev-ent.dev-dir.labor.gov" -Server "10.50.14.28" -Type "A" | Select-Object -First 1).IpAddress
$ProdADDetails = get-aduser -filter { mail -eq $prodemail } -Server ent.dir.labor.gov -Properties *
#
$getUserinDEV = (get-adforest -Server $DEVENTDCIP -Credential $Cred ).domains| %{
$s = (Resolve-DnsName -Name $PSItem -Server "10.50.14.28" -Type "A" | Select-Object -First 1).IpAddress
get-aduser -filter { Employeenumber -eq $prodemail } -Server $s -Credential $cred}
if($getUserinDEV){
Write-Output "The User Already exist in the Development Environment - $(($getUserinDEV).DistinguishedName)"
Write-Output "..............................."
Write-Output "The Script will Exit"
break
}

function Add-COEDEVuser() {
    param (
        [string]$OUPath,
        [string]$AgencyWKSAdminGroup,
        [string]$Dserver,
        $Cred,
        $ProdADDetails,
        $passwd = $(ConvertTo-SecureString 'DevAZ@W1n10' -AsPlainText -Force),
        [string]$description = 'AVD Dev User Account'
    )
    $user = 'z-' + $ProdADDetails.SamAccountName
    if ($user.Length -gt 20) { $user = $user.Substring(0, 20) }
    Write-Output "Working on $user in COE-DEV ENT Domain" 
    try {
        Get-ADUser $user -Server $Dserver  -Credential $cred
    } 
	   catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        New-aduser -SamAccountName $user -Name $ProdADDetails.Name -Server $Dserver -Enabled:$true -AccountPassword $passwd -Path $OUpath -Credential $cred -PassThru
    }
    finally {
        Set-ADUser -Identity $user  -Description $description -Server $Dserver -Credential $cred -EmployeeNumber $ProdADDetails.mail -UserPrincipalName $ProdADDetails.UserPrincipalName -DisplayName $ProdADDetails.DisplayName -Surname $ProdADDetails.Surname -GivenName $ProdADDetails.GivenName -Department $ProdADDetails.Department
        Add-ADPrincipalGroupMembership -Identity $user -Server $Dserver -MemberOf $AgencyWKSAdminGroup -Credential $cred -PassThru
        if (!((get-aduser $user -Server $Dserver -Properties Enabled -Credential $cred).Enabled)) {
            Set-ADAccountPassword  -Identity $user -Reset -NewPassword $passwd -Server $Dserver -Confirm:$false -Credential $cred
            Set-ADUser -Identity $user  -Description $description -ChangePasswordAtLogon:$true -Enabled:$true -Server $Dserver -Credential $cred
            Move-ADObject (Get-Aduser $user -Server $Dserver -Credential $cred)  -Server $Dserver -TargetPath $OUpath -Confirm:$false -Credential $cred
        }
    }
}
if ($Agency -eq "ETA") {
    $DomainOU = 'OU=Win10Developers,OU=ETA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.ETA'
    $AzGroup = 'avd-dev-eta-users'
}
if ($Agency -eq "OASAM") {
    $DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.OASAM'
    $AzGroup = 'avd-dev-itos-users'
}
if ($Agency -eq "AE") {
    $DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.OASAM'
    $AzGroup = 'avd-dev-ae-users'
}
if ($Agency -eq "ET") {
    $DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.OASAM'
    $AzGroup = 'avd-dev-et-users'
}
if ($Agency -eq "EBSA") {
    $DomainOU = 'OU=Win10Developers,OU=EBSA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.EBSA'
    $AzGroup = 'avd-dev-ebsa-users'
}
if ($Agency -eq "OSHA") {
    $DomainOU = 'OU=Win10Developers,OU=OSHA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.OSHA'
    $AzGroup = 'avd-dev-osha-users'
}
if ($Agency -eq "MSHA") {
    $DomainOU = 'OU=Win10Developers,OU=MSHA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.MSHA'
    $AzGroup = 'avd-dev-msha-users'
}
if ($Agency -eq "WHD") {
    $DomainOU = 'OU=Win10Developers,OU=WHD,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.WHD'
    $AzGroup = 'avd-dev-whd-users' 
}
if ($Agency -eq "OWCP") {
    $DomainOU = 'OU=Win10Developers,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.OWCP'
    $AzGroup = 'avd-dev-owcp-users' 
}
if ($Agency -eq "OFCCP") {
    $DomainOU = 'OU=Win10Developers,OU=OFCCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.devusers.OFCCP'
    $AzGroup = 'avd-dev-OFCCP-users'
}
Start-Sleep -Seconds 1 
Add-COEDEVuser -Cred $cred -Dserver $DEVENTDCIP -ProdADDetails $ProdADDetails -OUPath $DomainOU  -AgencyWKSAdminGroup $DomainAdminGroup -description "AVD Dev User Account-$Ticket"
$ProdADDetails | Add-ADPrincipalGroupMembership -MemberOf $AzGroup -PassThru