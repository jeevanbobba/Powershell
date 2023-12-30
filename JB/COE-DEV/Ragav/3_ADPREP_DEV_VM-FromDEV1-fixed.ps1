#read script folder
#$scriptpath = $MyInvocation.MyCommand.P
#$dir = Split-Path $scriptpath
#Write-host "My directory is $dir"
################################################
$file = "D:\JB\Chris\DevTest_Systems.csv" #File path
$VMCSVDATA = import-csv $file
foreach ($VMData in $VMCSVDATA)
{
	$VirtualObj = $VMData.ComputerName
	$Agency = $VMData.Agency
	if ($Agency -like "ETA")
	{
		$OUPATH = 'OU=WIN10,OU=ETA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "OASAM")
	{
		$OUPATH = 'OU=OCIO,OU=NO,OU=OASAM,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "OCIO")
	{
		$OUPATH = 'OU=OCIO,OU=NO,OU=OASAM,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "EBSA")
	{
		$OUPATH = 'OU=WIN10,OU=EBSA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "OSHA")
	{
		$OUPATH = 'OU=WIN10,OU=OSHA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "MSHA")
	{
		$OUPATH = 'OU=WIN10,OU=MSHA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "BTS")
	{
		$OUPATH = 'OU=BTS,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "DFEC")
	{
		$OUPATH = 'OU=DFEC,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "DCMWC")
	{
		$OUPATH = 'OU=DCMWC,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "DLHWC")
	{
		$OUPATH = 'OU=DLHWC,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "OFCCP")
	{
		$OUPATH = 'OU=OFCCP,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "OLMS")
	{
		$OUPATH = 'OU=OLMS,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "OWCP")
	{
		$OUPATH = 'OU=OWCP,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	if ($Agency -like "WHD")
	{
		$OUPATH = 'OU=WHD,OU=WIN10,OU=ESA,OU=DOL Computers,DC=dev-ent,DC=DEV-DIR,DC=LABOR,DC=GOV'
	}
	$ADOBj = Get-ADComputer $VirtualObj -Server dev-ent.dev-dir.labor.gov # changed get-ADobject to get-adcomputer
	Move-ADObject -Identity $ADOBj -TargetPath $OUPATH -Server dev-ent.dev-dir.labor.gov -Verbose -Confirm:$false
	Restart-computer $VirtualObj -Force -confirm:$false -verbose -AsJob
}