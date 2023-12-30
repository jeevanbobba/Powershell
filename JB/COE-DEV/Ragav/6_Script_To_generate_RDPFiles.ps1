#read script folder
#$scriptpath = $MyInvocation.MyCommand.P
#$dir = Split-Path $scriptpath
#Write-host "My directory is $dir"
################################################
$CSVFile= "D:\JB\FInal\Dev_systems.csv"
$MySingleRDP = '\\mgtutils01.oasam.dir.labor.gov\dml\COE-DEV\RDP_Files\Ref\Reference_SingleMon.rdp'
#$MyMultiMonRDP = '\\mgtutils01.oasam.dir.labor.gov\dml\COE-DEV\RDP_Files\Ref\Reference.rdp'
$fullpath = '\\mgtutils01.oasam.dir.labor.gov\DML\COE-DEV\RDP_Files\To Agency'
#Do Not Edit Below This Line
$RDPData = Import-csv $CSVFile
ForEach($Data in $RDPData)
{
	$agency = $data.Agency
	$userName = ($Data.DEVUserName -split "\\")[-1]
	$DName = $Data.Computername
    if($agency -match "BTS|DCMWC|DEEOIC|DLHWC|DFEC"){$filename = "$fullpath\OWCP\$Agency\$userName-$DName" + ".rdp"}
	else{$filename = "$fullpath\$Agency\$userName-$DName" + ".rdp"}
	$SingleMonRDP = Get-Content $MySingleRDP
	#$MultiMonRDP = Get-Content $MyMultiMonRDP
	$RDPIP = "full address:s:" + $Data.IPAddress
	$RDPDomain = "username:s:" + $Data.DevDomain +"\"+$Data.DevUserName
	$SingleMonRDP, $RDPIP, $RDPDomain | Out-File $filename -ErrorAction Stop
	#$MultiMonRDP, $RDPIP, $RDPDomain | Out-File ($filename -replace "\.rdp","-Multimon.rdp") -ErrorAction Stop
	Set-ItemProperty -Path $filename -Name IsReadOnly -Value $true
}