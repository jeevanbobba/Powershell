Function Change_Owner($FLDR_Full)
{
	$Owner_FLDR = get-ntfsowner -Path $FLDR_Full
	$FLDR_Owner = $Owner_FLDR.Owner.AccountName
	$FLDR_Owner
	if($Owner_FLDR.Owner.AccountName -ne "BUILTIN\Administrators")
	{
		write-host "`nBUILTIN\Administrators group is NOT Owner" -foregroundColor Magenta
		write-host "	- Changing $FLDR_Full Owner to BUILTIN\Administrators group" -foregroundColor Magenta
		set-ntfsowner $FLDR_Full -Account Administrators
	}
}

Function Folder_NOT_Inherited ($FLDR_Full)
{
	$Access = get-ntfsaccess $FLDR_Full
	$Access_Admin = "BUILTIN\Administrators"
	$Access_System = "NT Authority\SYSTEM"
	$Access_UNI = "DIR\UNI_OCIO_WindowsDomainAdmins"
	write-host "Checking Permissions on Disabled Inheritance folder $FLDR_Full" -foregroundColor Yellow
		
	# Checking for existence of BUILTIN\Administrators group on ACL
	if($Access_Admin -in $Access.Account)
	{
		write-host "`nBUILTIN\Administrators in ACL (Disabled Inheritance)" -foregroundColor Yellow
		$Admin_ACL = get-NTFSAccess -Path $FLDR_Full -Account BUILTIN\Administrators
		$Admin_ACL
		If($Admin_ACL.AccessRights -ne "FullControl")
		{
			write-host "`	- Administrators group does NOT have FullControl (Disabled Inheritance).  Changing to FullContol..." -foregroundColor Yellow
			# add-NTFSAccess for the ADministrators group here
			Add-NTFSAccess -path $FLDR_Full -Account "BUILTIN\Administrators" -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
			get-NTFSAccess -Path $FLDR_Full -Account BUILTIN\Administrators
		}
	}
	else
	{
		write-host "`nBUILT\Administrators NOT in ACL (Disabled Inheritance)" -foregroundColor Yellow
		write-host "`nBUILIN\Administrators group not on ACL (Disabled Inheritance)...Adding acct to ACL." -foregroundColor Yellow
		Add-NTFSAccess -path $FLDR_Full -Account "BUILTIN\Administrators" -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
		get-NTFSAccess -Path $FLDR_Full -Account BUILTIN\Administrators
	}
		
	# Checking for existence of NT Authority\SYSTEM account on ACL
	if($Access_System -in $Access.Account)
	{
		write-host "`nNT Authority\SYSTEM account in ACL (Disabled Inheritance)" -foregroundColor Yellow 
		$System_ACL = get-NTFSAccess -Path $FLDR_Full -Account "NT Authority\SYSTEM"
		$System_ACL
		If($System_ACL.AccessRights -ne "FullControl")
		{
			write-host "	- SYSTEM Acct does NOT have FullControl (Disabled Inheritance).  Changing to FullContol..." -foregroundColor Yellow
			# add-NTFSAccess for the SYSTEM account here
			Add-NTFSAccess -path $FLDR_Full -Account SYSTEM -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
			get-NTFSAccess -Path $FLDR_Full -Account SYSTEM
		}
	}
	else
	{
		write-host "`nNT Authority\SYSTEM account NOT in ACL (Disabled Inheritance)" -foregroundColor Yellow
		write-host "	- NT Authority\SYSTEM group not on ACL (Disabled Inheritance)...Adding acct to ACL." -foregroundColor Yellow
		Add-NTFSAccess -path $FLDR_Full -Account 'NT Authority\SYSTEM' -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
		get-NTFSAccess -Path $FLDR_Full -Account SYSTEM
	}
		
	# Checking for existence of DIR\UNI_OCIO_WindowsDomainAdmins group
	if($Access_UNI -in $Access.Account)
	{
		write-host "`nDIR\UNI_OCIO_WindowsDomainAdmins group in ACL (Disabled Inheritance)" -foregroundColor Yellow
		$UNI_ACL = get-NTFSAccess -Path $FLDR_Full -Account DIR\UNI_OCIO_WindowsDomainAdmins
		# $UNI_ACL
		If($UNI_ACL.AccessRights -ne "FullControl")
		{
			write-host "	- DIR\UNI_OCIO_WindowsDomainAdmins group does NOT have FullControl (Disabled Inheritance).  Changing to FullContol..." -foregroundColor Yellow
			# add-NTFSAccess for the DIR\UNI_OCIO_WindowsDomainAdmins group here
			Add-NTFSAccess -path $FLDR_Full -Account DIR\UNI_OCIO_WindowsDomainAdmins -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
			get-NTFSAccess -Path $FLDR_Full -Account DIR\UNI_OCIO_WindowsDomainAdmins
		}
	}
	else
	{
		write-host "`nDIR\UNI_OCIO_WindowsDomainAdmins group NOT in ACL (Disabled Inheritance)" -foregroundColor Yellow
		write-host "	- DIR\UNI_OCIO_WindowsDomainAdmins group not on ACL (Disabled Inheritance)...Adding group to ACL." -foregroundColor Yellow
		Add-NTFSAccess -path $FLDR_Full -Account 'DIR\UNI_OCIO_WindowsDomainAdmins' -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
		get-NTFSAccess -Path $FLDR_Full -Account DIR\UNI_OCIO_WindowsDomainAdmins
	}
		
	get-NTFSOrphanedAccess -path $FLDR_Full -ExcludeInherited | Remove-NTFSAccess
	# get-NTFSAccess -path $Folder.FullName -ExcludeInherited | where {$_.Account -like "S-1-5-21*"} | Remove-NTFSAccess
	get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -like "OASAM\z-*" -or $_.Account -like "ent\z-*" -or $_.Account -like "z-*" -or $_.Account -like "ESA-EWDS\z-*"} | Remove-NTFSAccess
	get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -like "*Domain Admins"} | Remove-NTFSAccess
		
	if(get-NTFSAccess -path $FLDR_Full | where {$_.Account -like "Creator Owner"})
	{
		write-host "`nCreator Owner exists (Disabled Inheritance)" -foregroundColor Yellow
		write-host "	- Creator Owner acct on ACL (Disabled Inheritance)...Removing acct in ACL." -foregroundColor Yellow
		add-ntfsaccess -path $FLDR_Full -Account "Creator Owner" -AccessRights Modify
		Get-NTFSAccess -Path $FLDR_Full -Account "Creator Owner" | Remove-NTFSAccess
	}
		
	$Full_Control = get-ntfsaccess -Path $FLDR_Full | where {$_.accessrights -eq "FullControl"}
		
	foreach($Full_Access in $Full_Control)
	{
		if(($Full_Access.account -ne "DIR\UNI_OCIO_WindowsDomainAdmins") -and ($Full_Access.account -ne "SYSTEM") -and ($Full_Access.account -ne "BUILTIN\Administrators") -and ($Full_Access.Account.AccountName -ne ""))
		{
				
			$Full_Access.Account
			$ACL_Acct = $Full_Access.Account
			$User_SID = $Full_Access.Account.Sid
			write-host "`n$ACL_Acct has FullControl access in ACL (Disabled Inheritance)" -foregroundColor Yellow
			write-host "	- Changing user account to Modify permissions (Disabled Inheritance)" -foregroundColor Yellow
			remove-ntfsaccess -path $FLDR_Full -Account $User_SID -AccessRights FullControl
			Add-NTFSAccess -path $FLDR_Full -Account $User_SID -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
		}
	}
}
Function Folder_Inherited ($FLDR_Full)
{
	get-NTFSOrphanedAccess -path $FLDR_Full -ExcludeInherited | Remove-NTFSAccess
	get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -like "OASAM\z-*" -or $_.Account -like "ent\z-*" -or $_.Account -like "z-*" -or $_.Account -like "ESA-EWDS\z-*"} | Remove-NTFSAccess
		
	if(get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -eq "NT Authority\SYSTEM"})
	{
		Get-NTFSAccess -Path $FLDR_Full -Account "NT Authority\SYSTEM" -ExcludeInherited | Remove-NTFSAccess	
	}
	if(get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -eq "BUILTIN\Administrators"})
	{
		Get-NTFSAccess -Path $FLDR_Full -Account "BUILTIN\Administrators" -ExcludeInherited | Remove-NTFSAccess	
	}
	if(get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -eq "DIR\UNI_OCIO_WindowsDomainAdmins"})
	{
		Get-NTFSAccess -Path $FLDR_Full -Account "DIR\UNI_OCIO_WindowsDomainAdmins" -ExcludeInherited | Remove-NTFSAccess	
	}
		
	if(get-NTFSAccess -path $FLDR_Full -ExcludeInherited | where {$_.Account -like "Creator Owner"})
	{
		write-host "`nCreator Owner exists" -foregroundColor Yellow
		write-host "	- Creator Owner acct on ACL...Removing acct in ACL." -foregroundColor Magenta
		Get-NTFSAccess -Path $FLDR_Full -Account "Creator Owner" -ExcludeInherited | Remove-NTFSAccess
	}
		
	$Full_Control = get-ntfsaccess -Path $FLDR_Full -ExcludeInherited | where {$_.accessrights -eq "FullControl"}
		
	if($Full_Control -ne $null)
	{
		foreach($Full_Access in $Full_Control)
		{
			$Full_Access.Account
			$ACL_Acct = $Full_Access.Account
			$User_SID = $Full_Access.Account.Sid
			write-host "`n$ACL_Acct has FullControl access in ACL" -foregroundColor Magenta
			write-host "	- Changing user account to Modify permissions" -foregroundColor Magenta
			remove-ntfsaccess -path $FLDR_Full -Account $User_SID -AccessRights FullControl
			Add-NTFSAccess -path $FLDR_Full -Account $User_SID -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndfiles -AccessType Allow
		}
	}
}

$Start_Time = Get-Date
Start-Transcript -Path "\\silentfs01\reports\filemigrationlogs\OASAM_Logs\DOL-SEC-Office-Folder_Permissions-2.txt"
$Fld_Path = "\\dc1ansvmfilp02\DOLSEC-Office\OSEC"
write-host "`nStart time $Start_Time" -foregroundColor Green
write-host "`nRetrieving all share root folders from $Fld_Path..." -foregroundColor Yellow
$Dirs = get-childitem -Path $Fld_Path | where-object{$_.psIsContainer} | select Name,FullName
$Fld_Cnt = 0

foreach($Folder in $Dirs)
{
	$Fld_Cnt++
	$Folder_Name = $Folder.Name
	$Folder_FullName = $Folder.FullName
	write-host "`nFolder Name is $Folder_FullName ... Folder Number: $Fld_Cnt"
	
	Change_Owner $Folder.FullName
	
	$FLDR_Inherit = get-ntfsinheritance -Path $Folder.FullName
	$FLDR_Inherit.AccessInheritanceEnabled
	if($FLDR_Inherit.AccessInheritanceEnabled -eq $True)
	{
		Folder_Inherited $Folder.FullName
	}
	else
	{
		Folder_NOT_Inherited $Folder.FullName
	}
	# the following retrieves all folders under the root folder
	$DIRS_2 = get-childitem -Path $Folder.FullName -recurse | where-object{$_.psIsContainer} | select Name,FullName
	foreach($Folder_2 in $DIRS_2)
	{
		$Fld_Cnt++
		$Folder_2_Name = $Folder_2.Name
		$Folder_2_FullName = $Folder_2.FullName
		write-host "`nFolder Name is $Folder_2_FullName ... Folder Number: $Fld_Cnt"
	
		Change_Owner $Folder_2.FullName
		
		$FLDR_Inherit = get-ntfsinheritance -Path $Folder_2.FullName
		$FLDR_Inherit.AccessInheritanceEnabled
		if($FLDR_Inherit.AccessInheritanceEnabled -eq $True)
		{
			Folder_Inherited $Folder_2.FullName
		}
		else
		{
			Folder_NOT_Inherited $Folder_2.FullName
		}
	}
	
}
write-host "Total Folders = $Fld_Cnt" -foregroundColor Red
$End_Time = get-date
$Time_Span = New-TimeSpan -Start $Start_Time -End $End_Time | ft
write-host "`nScript ran for: " -foregroundColor Red
$Time_Span
Stop-Transcript