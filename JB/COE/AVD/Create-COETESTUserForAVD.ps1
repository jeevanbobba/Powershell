function add-testuser
{
<#	
	.NOTES
	===========================================================================
	 Created on:   	04/11/2022
	 Created by:   	Jeevan Bobba
	 Organization: 	OASAM/OCIO/WindowsServerTeamOperations
	 Filename:  Create-COETESTUserForAVD.ps1
     ===========================================================================
	.DESCRIPTION
		This Script Creates the user account in Test , Need Agency and Ticket Information 
               if user already exists in Test (Checking by comparing the Employeenumber attrib to prod email account)  ..this script will not do anything
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
      #.\Create-COETESTUserForAVD.ps1 -Agency OASAM -Ticket "CRQ165421" -Prodemail "LastName.FirstName@dol.gov" 

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
        [Parameter(Mandatory=$false,Position = 3,HelpMessage = "Provide Test domain Credential")]
        [System.Management.Automation.PSCredential]
        $Cred= $(Get-Credential -Message "Enter Test-Domain Credentials" -UserName "Test-DIR\")

    )
#$cred =Get-Credential -Message "Enter Test-Domain Credentials" -UserName "Test-DIR\"  #Development Credential
# Do not Edit Below this Line
$TESTENTDCIP = (Resolve-DnsName -Name "Test-ent.TEST-dir.labor.gov" -Server "10.52.13.16" -Type "A" | Select-Object -First 1).IpAddress
$ProdADDetails = get-aduser -filter { mail -eq $prodemail } -Server ent.dir.labor.gov -Properties *
#
$getUserinTest = (get-adforest -Server $TestENTDCIP -Credential $Cred ).domains| %{
$s = (Resolve-DnsName -Name $PSItem -Server "10.52.13.16" -Type "A" | Select-Object -First 1).IpAddress
get-aduser -filter { Employeenumber -eq $prodemail } -Server $s -Credential $cred}
if($getUserinTest){
Write-Output "The User Already exist in the TEST Environment - $(($getUserinTest).DistinguishedName)"
Write-Output "..............................."
Write-Output "The Script will Exit"
break
}

function Add-COETestuser() {
    param (
        [string]$OUPath,
        [string]$AgencyWKSAdminGroup,
        [string]$Dserver,
        $Cred,
        $ProdADDetails,
        $passwd = $(ConvertTo-SecureString 'TestAZ@W1n10' -AsPlainText -Force),
        [string]$description = 'AVD Test User Account'
    )
    #$user = 'z-' + $ProdADDetails.SamAccountName
    $user = $ProdADDetails.SamAccountName
    if ($user.Length -gt 20) { $user = $user.Substring(0, 20) }
    Write-Output "Working on $user in COE-TEST ENT Domain" 
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
    $DomainOU = 'OU=Win10Testusers,OU=ETA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.ETA'
    #$AzGroup = 'avd-Test-eta-users'
}
if ($Agency -eq "OASAM") {
    $DomainOU = 'OU=Win10Testusers,OU=OASAM_OCIO,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.OASAM'
    #$AzGroup = 'avd-Test-itos-users'
}
if ($Agency -eq "AE") {
    $DomainOU = 'OU=Win10Testusers,OU=OASAM_OCIO,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.OASAM'
    $AzGroup = 'avd-Test-ae-users'
}
if ($Agency -eq "ET") {
    $DomainOU = 'OU=Win10Testusers,OU=OASAM_OCIO,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.OASAM'
    #$AzGroup = 'avd-Test-et-users'
}
if ($Agency -eq "EBSA") {
    $DomainOU = 'OU=Win10Testusers,OU=EBSA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.EBSA'
    #$AzGroup = 'avd-Test-ebsa-users'
}
if ($Agency -eq "OSHA") {
    $DomainOU = 'OU=Win10Testusers,OU=OSHA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.OSHA'
    #$AzGroup = 'avd-Test-osha-users'
}
if ($Agency -eq "MSHA") {
    $DomainOU = 'OU=Win10Testusers,OU=MSHA,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.MSHA'
    #$AzGroup = 'avd-Test-msha-users'
}
if ($Agency -eq "WHD") {
    $DomainOU = 'OU=Win10Testusers,OU=WHD,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.WHD'
    #$AzGroup = 'avd-Test-whd-users' 
}
if ($Agency -eq "OWCP") {
    $DomainOU = 'OU=Win10Testusers,OU=OWCP,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.OWCP'
    #$AzGroup = 'avd-Test-owcp-users' 
}
if ($Agency -eq "OFCCP") {
    $DomainOU = 'OU=Win10Testusers,OU=OFCCP,OU=Accounts,DC=Test-ent,DC=Test-DIR,DC=LABOR,DC=GOV'
    $DomainAdminGroup = 'ent.testusers.OFCCP'
    #$AzGroup = 'avd-Test-OFCCP-users'
}
Start-Sleep -Seconds 1 
Add-COETestuser -Cred $cred -Dserver $TestENTDCIP -ProdADDetails $ProdADDetails -OUPath $DomainOU  -AgencyWKSAdminGroup $DomainAdminGroup -description "AVD TEST User Account-$Ticket"
#$ProdADDetails | Add-ADPrincipalGroupMembership -MemberOf $AzGroup -PassThru
}