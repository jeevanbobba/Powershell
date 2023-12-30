#read script folder
#$scriptpath = $MyInvocation.MyCommand.P
#$dir = Split-Path $scriptpath
#Write-host "My directory is $dir"
################################################
$file = "D:\JB\Ragav\DevTest_systems.csv"
# Do not Edit Below this Line
if ($env:USERDNSDOMAIN -like "*dev-dir*")
{
	$VMCSVDATA = import-csv $file
	function Add-COEDEVuser()
	{
		param (
			[Parameter(Position = 0, mandatory = $true)]
			[string]$DomainName,
			[Parameter(Position = 1, mandatory = $true)]
			[string]$OUPath,
			[Parameter(Position = 2, mandatory = $true)]
			[string]$User,
			[Parameter(Position = 3, mandatory = $true)]
            [string]$firstname,
			[Parameter(Position = 4, mandatory = $true)]#added firstname
            [string]$lastname,
			[Parameter(Position = 5, mandatory = $true)]#added Lastname
			[string]$AgencyWKSAdminGroup,
			[string]$hdrivepath = '\\SILVMDEVFILE01.dev-ent.dev-dir.labor.gov\HomeDrives$',
			$passwd = $(ConvertTo-SecureString 'MyDev@W1n10VM' -AsPlainText -Force),
			[string]$description = 'COE DEV Environment Account'
		)
		try
		{
			Get-ADUser $user -Server $DomainName
		} 
	   catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
        {
			New-aduser  -SamAccountName $user -Name $user -GivenName $firstname -Surname $lastname -Server $DomainName -Enabled:$true -AccountPassword $passwd -Path $OUpath #added Firstname and lastname
		}
		finally
		{
			New-Item -Path "$hdrivepath\$user" -ItemType Directory -ErrorAction SilentlyContinue -Force
			Set-ADUser -Identity $user  -HomeDirectory $hdrivepath\$user -HomeDrive 'H:' -Description $description -Server $DomainName
			Add-ADPrincipalGroupMembership -Identity $user -Server $DomainName  -MemberOf (Get-ADGroup -Identity $AgencyWKSAdminGroup -Server dev-ent.dev-dir.labor.gov)
			if (!((get-aduser $user -Server $DomainName -Properties Enabled).Enabled))
			{
				Set-ADAccountPassword  -Identity $user -Reset -NewPassword $passwd -Server $DomainName -Confirm:$false
				Set-ADUser -Identity $user -GivenName $firstname -Surname $lastname -HomeDirectory $hdrivepath\$user -HomeDrive 'H:' -Description $description -ChangePasswordAtLogon:$true -Enabled:$true -Server $DomainName #added firstname and lastname
                Move-ADObject (Get-Aduser $user -Server $DomainName)  -Server $DomainName -TargetPath $OUpath -Confirm:$false
			}
		}
	}
	foreach ($Data in $VMCSVDATA)
	{
		$Agency = $Data.Agency
		$user = $Data.NPUserName
        $fname =$data.FirstName
        $lname = $data.LastName
		if ($Agency -like "ETA")
		{
			$DomainName = 'dev-eta.dev-dir.labor.gov'
			$DomainOU = 'OU=OT-Developers,OU=OT,OU=DC,DC=DEV-ETA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.ETA'
		}
		if ($Agency -like "OASAM")
		{
			$DomainName = 'dev-oasam.dev-dir.labor.gov'
			$DomainOU = 'OU=Delegation,OU=OASAM,OU=National Office,OU=newDesign,DC=DEV-OASAM,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OASAM'
		}
		if ($Agency -like "OALJ")
		{
			$DomainName = 'dev-oalj.dev-dir.labor.gov'
			$DomainOU = 'OU=Win 10 Users,OU=Active,OU=Employees,DC=DEV-OALJ,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OALJ'
		}
		if ($Agency -like "EBSA")
		{
			$DomainName = 'dev-ebsa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10 Users,OU=National Office,OU=EBSA,DC=DEV-EBSA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.EBSA'
		}
		if ($Agency -like "OSHA")
		{
			$DomainName = 'dev-osha.dev-dir.labor.gov'
			$DomainOU = 'OU=WIN10,OU=Z-Accounts,OU=National Office,DC=DEV-OSHA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OSHA'
		}
		if ($Agency -like "MSHA")
		{
			$DomainName = 'dev-msha.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10 Users,OU=MSHA Users & Groups,DC=DEV-MSHA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.MSHA'
		}
		if ($Agency -like "WHD")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.WHD'
		}
		if ($Agency -like "OFCCP")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OFCCP'
		}
		if ($Agency -like "OLMS")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OLMS'
		}
		if ($Agency -like "BTS")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.BTS'
		}
		if ($Agency -like "DFEC")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DFEC'
		}
		if ($Agency -like "DLHWC")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DLHWC'
		}
		if ($Agency -like "DCMWC")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DCMWC'
		}
		if ($Agency -like "DEEOIC")
		{
			$DomainName = 'dev-esa.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=ESA,DC=DEV-ESA,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DEEOIC'
        }
        if ($Agency -like "OWCP")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
            $DomainOU = 'OU=Win10Developers,OU=OWCP,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
            $DomainAdminGroup = 'ent.Devusers.DEEOIC'
        }
		Add-COEDEVUSER -DomainName $DomainName -OUPath $DomainOU -AgencyWKSAdminGroup $DomainAdminGroup -User $user -firstname $fname -lastname $lname
	}
}
#creating Dev.dol.gov mailbox to user
<#
else
{ Write-Output "This Script Should be Running in DEV Environment" }
start-sleep -Seconds 180
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://sildevexch01.dev-ent.dev-dir.labor.gov/PowerShell/" -Authentication Kerberos
Import-PSSession $Session
Set-ADServerSettings -ViewEntireForest $true
foreach ($Data in $VMCSVDATA){
Enable-Mailbox $DATA.UserName -Verbose -Alias  ($Data.DevEmail -replace "@dev.dol.gov") 
}
#To check all mailboxes are created
$VMCSVDATA.DevUserName | %{get-mailbox $PSItem}

#>