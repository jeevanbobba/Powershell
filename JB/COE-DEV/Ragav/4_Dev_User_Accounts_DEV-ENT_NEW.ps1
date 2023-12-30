#read script folder
#$scriptpath = $MyInvocation.MyCommand.P
#$dir = Split-Path $scriptpath
Write-host "My directory is $dir"
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
            [Parameter(Position = 5, mandatory = $true)]#added Name
            [string]$Name,
			[Parameter(Position = 6, mandatory = $true)]#added Lastname
			[string]$AgencyWKSAdminGroup,
            [Parameter(Position = 7, mandatory = $true)]#added ProdEmail
            [string]$Prodemail,
            [Parameter(Position = 8, mandatory = $true)]#added Displayname
            [string]$DisplayName,
			[string]$hdrivepath = '\\SILVMDEVFILE01.dev-ent.dev-dir.labor.gov\HomeDrives$',
			$passwd = $(ConvertTo-SecureString 'MyDev@W1n10VM' -AsPlainText -Force),
			[string]$description = 'COE DEV Environment Account '
		)
		try
		{
			Get-ADUser $user -Server $DomainName
		} 
	   catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
        {
			New-aduser  -SamAccountName $user -Name $name -GivenName $firstname -Surname $lastname -Server $DomainName -Employeenumber $Prodemail -Enabled:$true -AccountPassword $passwd -Path $OUpath #added Firstname and lastname prod emailid, displayname
		}
		finally
		{
			New-Item -Path "$hdrivepath\$user" -ItemType Directory -ErrorAction SilentlyContinue -Force
			Set-ADUser -Identity $user  -HomeDirectory $hdrivepath\$user -HomeDrive 'H:' -Description $description -Server $DomainName -DisplayName $DisplayName
			Add-ADPrincipalGroupMembership -Identity $user -Server $DomainName  -MemberOf (Get-ADGroup -Identity $AgencyWKSAdminGroup -Server dev-ent.dev-dir.labor.gov)
			if (!((get-aduser $user -Server $DomainName -Properties Enabled).Enabled))
			{
				Set-ADAccountPassword  -Identity $user -Reset -NewPassword $passwd -Server $DomainName -Confirm:$false
				Set-ADUser -Identity $user -Name $name -GivenName $firstname -Surname $lastname -DisplayName $DisplayName -HomeDirectory $hdrivepath\$user -HomeDrive 'H:' -Description $description -ChangePasswordAtLogon:$true -Enabled:$true -Server $DomainName -Employeenumber $Prodemail #added firstname and lastname prod emailid displayname
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
        $name = $data.Name
        $DisplayName = $data.Name
        $Pemail =$data.ProdEmail
		if ($Agency -like "ETA")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'         
			$DomainOU = 'OU=Win10Developers,OU=ETA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.ETA'
		}
		if ($Agency -like "OASAM")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OASAM'
		}
		if ($Agency -like "OCIO")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OASAM'
		}
		if ($Agency -like "OALJ")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OALJ,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OALJ'
		}
		if ($Agency -like "EBSA")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=EBSA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.EBSA'
		}
		if ($Agency -like "OSHA")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OSHA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OSHA'
		}
		if ($Agency -like "MSHA")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=MSHA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.MSHA'
		}
		if ($Agency -like "WHD")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=WHD,OU=ESA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.WHD'
		}
		if ($Agency -like "OFCCP")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OFCCP,OU=ESA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OFCCP'
		}
		if ($Agency -like "OLMS")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OLMS,,OU=ESA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.OLMS'
		}
		if ($Agency -like "BTS")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=BTS,OU=ESA,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.BTS'
		}
		if ($Agency -like "DFEC")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=DFEC,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DFEC'
		}
		if ($Agency -like "DLHWC")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=DLHWC,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DLHWC'
		}
		if ($Agency -like "DCMWC")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=DCMWC,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DCMWC'
		}
		if ($Agency -like "DEEOIC")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=DEEOIC,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.DEEOIC'
        }
        if ($Agency -like "ENT")
		{
			$DomainName = 'dev-ENT.dev-dir.labor.gov'
			$DomainOU = 'OU=Win10Developers,OU=OASAM_OCIO,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
			$DomainAdminGroup = 'ent.devusers.ENT'
        }
       if ($Agency -like "OWCP")
        {
            $DomainName = 'dev-ENT.dev-dir.labor.gov'
            $DomainOU = 'OU=Win10Developers,OU=OWCP,OU=Accounts,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
            $DomainAdminGroup = 'ent.Devusers.DEEOIC'
         }
		Add-COEDEVUSER -DomainName $DomainName -OUPath $DomainOU -AgencyWKSAdminGroup $DomainAdminGroup -User $user -name $name -firstname $fname -lastname $lname -Prodemail $Pemail -DisplayName $DisplayName
	    } 
  }