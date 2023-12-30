$SCVMM2012Module = "VirtualMachineManager"

$URLComps = $null
$HostURL = $null

$cwd = get-location;

Function ExitScript
{
    $PTPassword = ""

    cd $cwd

    if ($ConnectionType -eq "XenServer")
    {
        if ($HostURL -ne $null)
        {
    	    DisConnect-XenServer -url $HostURL 
        }
    }
    elseif ($ConnectionType -eq "VCenter")
    {
        if ($URLComps -ne $null)
        {
    	    DisConnect-VIServer -Server $URLComps[2] -Confirm:$false -force
        }
    }

   Exit
}

Function LoadSnapin
{
	param($toolkit)
	
	$err = $null
	
	if ( (Get-PSSnapin -Name $toolkit -ErrorAction SilentlyContinue) -eq $null )
	{
		Add-PsSnapin $toolkit  -ErrorVariable err -errorAction SilentlyContinue
	}

	if($err -ne $null)
	{
		Write-Host -ForegroundColor Red "$toolkit toolkit could not be loaded: $err"
        return $err
	}
    return ""
}

Function LoadVMwareSnapin
{
    if (LoadSnapin "VMware.vimautomation.core" -ne "")
    {
        cd $cwd
        Exit
    }
}

Function LoadXenServerSnapin
{
	$toolkit = "XenServerPSSnapIn"
    $err = $null
	
    if ( (Get-PSSnapin -Name $toolkit -Registered -ErrorAction SilentlyContinue) -eq $null )
	{
		$os = Get-WmiObject -Class Win32_OperatingSystem -ea 0
		if($os.OSArchitecture -eq '64-bit')
		{
			$proc=[diagnostics.process]::GetCurrentProcess()
			if (!($proc.path -match '\\syswow64\\'))
			{
				# 64bit process on 64bit. Currently there's no XenServerPSSnapIn available for 64bit
				Write-Host -ForegroundColor Red "XenServerPSSnapIn is not registered. It may only be available for 32bit. Please try running the script in a 32bit PowerShell console."
			}
		}
        Write-Host -ForegroundColor Red "$toolkit toolkit may not installed."
		Write-Host -ForegroundColor Green "The PowerShell SnapIn for XenServer can be downloaded from: http://community.citrix.com/display/xs/Download+SDKs"  
        cd $cwd
        Exit		
	}
	if ( (Get-PSSnapin -Name $toolkit -ErrorAction SilentlyContinue) -eq $null )
	{
		Add-PsSnapin $toolkit  -ErrorVariable err -errorAction SilentlyContinue
	}

	if($err -ne $null)
	{
		Write-Host -ForegroundColor Red "$toolkit toolkit could not be loaded: $err"
		Write-Host -ForegroundColor Green "The PowerShell SnapIn for XenServer can be downloaded from: http://community.citrix.com/display/xs/Download+SDKs"
        cd $cwd
        Exit
	}
}

Function LoadSCVMM
{	
	$snapin = "Microsoft.SystemCenter.VirtualMachineManager"
	
	$err = $null
	
	if ( ((Get-PSSnapin -Name $snapin -ErrorAction SilentlyContinue) -ne $null ) -or 
		 ((Get-Module -Name $SCVMM2012Module) -ne $null) )
	{
		# Module or snapin is loaded. We're done.
		return
	}
	
	if ((Get-Module -ListAvailable -Name $SCVMM2012Module) -ne $null)
	{
		# SCVMM 2012 or newer
		Import-Module $SCVMM2012Module -ErrorVariable err -errorAction SilentlyContinue
		if($err -ne $null)
		{
			Write-Host -ForegroundColor Red "SCVMM module ($SCVMM2012Module) could not be loaded: $err"
            cd $cwd
            Exit
		}
	}else
	{
		# Older version of SCVMM. Try loading the snapin
		Add-PsSnapin $snapin  -ErrorVariable err -errorAction SilentlyContinue
		if($err -ne $null)
		{
			Write-Host -ForegroundColor Red "$snapin toolkit could not be loaded: $err"
            cd $cwd
            Exit
		}
	}
}

#LoadSnapin "Citrix.Broker.Admin.V1"
#LoadSnapin "Citrix.Configuration.Admin.V1"
#LoadSnapin "Citrix.Host.Admin.V1"
#LoadSnapin "Citrix.MachineCreation.Admin.V1"
#LoadSnapin "Citrix.MachineIdentity.Admin.V1"
#LoadSnapin "Citrix.ADIdentity.Admin.V1"
LoadSnapin "PvsPsSnapIn"
LoadSnapin "*Citrix*"

try
{
	add-psSnapin "*Citrix*" -ErrorAction SilentlyContinue
}
catch {}



#
# Create log file
#

$timeStampYear = (Get-Date).Year
$timeStampMonth =(Get-Date).Month
$timeStampDay = (Get-Date).Day
$timeStampHour = (Get-Date).Hour
$timeStampMin = (Get-Date).Minute
$timeStampSec = (Get-Date).Second
$logfile = $cwd.Path + "\" + "PvD-Backup-" + $timeStampYear + "-" + $timeStampMonth + "-" + $timeStampDay + "-" + $timeStampHour + "-" + $timeStampMin + "-" + $timeStampSec + "-log.txt"

# Log Function

Function Write-Log
{
   Param ([string]$logString)
   $time = (Get-Date).ToString()
   $str = "[" + $time + "]" + $logString
   Add-content $logfile -value $str
}

Write-Log "****** Start Logging ******"

#create a template for XML 
$template = @'
<PVDMigration>
<hypervisor>
<type></type>
</hypervisor>

<PVD>

<DiskId></DiskId>
<DiskName></DiskName>
<SRName></SRName>
<SRID></SRID>
<UserName></UserName>
<UserSid></UserSid>
<State></State>
</PVD>

</PVDMigration>
'@

$templateFile = "$cwd\MigrationTemplate.xml" 
$template | Out-File $templateFile -encoding UTF8
$xml = New-Object xml

$xml.Load("$templateFile")


$AcceptedParameters="no"
$OldPoolName=""
$OldStorageLoc=""
$OldSize=""
$thinProv=""
$catalogIsPvs = $false

While ($AcceptedParameters -eq "no")
{

	$PoolName=""
	$StorageLoc=""
	$Size=""

	while ($PoolName -eq "")
	{
		$pools = @()
		
		Write-Host -ForegroundColor Yellow "Please select a catalog (by number) from the following list:"
		$ct=0
		
		try {
			foreach($Catalog in Get-BrokerCatalog | Select -unique Name)
			{
				$ct++;
				$CatNam = $Catalog.Name
				$pools += $CatNam
				Write-Host -ForegroundColor Gray "$ct : $CatNam"
			}
		}
		catch {
			Write-Log "Failed to get Broker catalog"
			Write-Log $_.Exception.ToString()
			ExitScript
		}

        if ($ct -le 0)
        {
            Write-Host -ForegroundColor Red "No catalogs found"
            Write-Log "No catalogs found"
            ExitScript
        }

		Write-Host
		if ($OldPoolName -ne "")
		{
			Write-Host -ForegroundColor White -NoNewLine "Catalog Selection ($OldPoolName)> "
		}
		else
		{
			Write-Host -ForegroundColor White -NoNewLine "Catalog Selection> "
		}

		$Selection = Read-Host
		if($Selection -eq "" -and $OldPoolName -ne "")
		{
			$PoolName = $OldPoolName
		}
		else
		{
			if($Selection -match "^\d+$")
			{
				$SelIdx = $Selection - 1

				if($SelIdx -lt 0 -or $SelIdx -ge $pools.count)
				{
					Write-Host
					Write-Host -ForegroundColor Red "No such catalog"
					Write-Host
				}
				else
				{
					$SelCat = Get-BrokerCatalog $pools[$SelIdx]
					if ($SelCat.CatalogKind -eq "Pvs")
					{
						$catalogIsPvs = $true
					}

					$PoolName = $pools[$SelIdx]
					Write-Log "Catalog Selected: $PoolName"
				}
			}
			else	
			{	
				Write-Host
				Write-Host -ForegroundColor Red "Invalid input"
				Write-Host
			}
		}

		$OldPoolName = $PoolName
		
	}

	Write-Host
	Write-Host
	Write-Host
	
	#
	# Retrieve the hypervisor name for the selected catalog
	#
	$ConnectionNames = @()
	try {		
        foreach($d in (Get-BrokerMachine -CatalogName $PoolName))
		{
			if(!($ConnectionNames -contains $d.HypervisorConnectionName))
			{
				$ConnectionNames += $d.HypervisorConnectionName
			}
		}
	}
	catch
	{
		Write-Log "Failed to get broker desktop for catalog $PoolName"
		Write-Log "$_.Exception.ToString()"
		ExitScript
	}
	
	$Connections = @()
	try {
		set-location XDHyp:\Connections
		foreach ($connection in Get-ChildItem XDHyp:\Connections )
		{
			set-location $connection
			if($ConnectionNames -contains $connection.PSChildName)
			{
				$Connections += $connection;
			}
			set-location XDHyp:\Connections
		}
	}
	catch
	{
		Write-Log "Failed to get Xen Desktop Connections"
		Write-Log "$_.Exception.ToString()"
		ExitScript
	}
	
	$ConnectionURL = $Connections[0].HypervisorAddress
	$ConnectionType = $Connections[0].ConnectionType
	$ConnectionDefaultUser = $Connections[0].UserName	
	$HostURL = $ConnectionURL[0]

	try {
		# Load the correct snap-in based on the connection type
		if ($ConnectionType -eq "XenServer")
		{
			$os = Get-WmiObject -Class Win32_OperatingSystem -ea 0
			if($os.OSArchitecture -eq '64-bit')
			{
				$proc=[diagnostics.process]::GetCurrentProcess()
				if (!($proc.path -match '\\syswow64\\'))
				{
					# 64bit process on 64bit. Currently there's no XenServerPSSnapIn available for 64bit
					Write-Host -ForegroundColor Red "XenServerPSSnapIn is only available for 32bit. Please run the script in a 32bit PowerShell console."
					Set-Location $cwd
					Exit
				}
			}
			
			LoadXenServerSnapin
		}elseif ($ConnectionType -eq "SCVMM")
		{
			LoadSCVMM
		}
		elseif ($ConnectionType -eq "VCenter")
		{
			LoadVMwareSnapin
		}
	}
	catch
	{
		Write-Log "Failed to Load the hypervisor snapin"
		Write-Log "$_.Exception.ToString()"
		ExitScript
	}
	Set-Location $cwd	

	Write-Host
	Write-Host
	Write-Host
	Write-Host -ForegroundColor Yellow "Selection Summary"
	Write-Host -ForegroundColor Gray -NoNewLine "Catalog Name:     "
	Write-Host -ForegroundColor White $PoolName

	Write-Host
	Write-Host
	Write-Host -ForegroundColor White -NoNewLine "Proceed (Y/N)? "
	$YN = Read-Host

	if ($YN -match "y")
	{
		$AcceptedParameters = "yes"
	}
	else
	{
		Write-Host
		Write-Host
		Write-Host
	}
}

$SuccessfulConnection = "no"

while ($SuccessfulConnection -eq "no")
{
	Write-Host
	Write-Host
	Write-Host -ForegroundColor Green "Enter username for authenticating to $HostURL"
	Write-Host -ForegroundColor Green -NoNewLine "Username ($ConnectionDefaultUser)> "
	$UserName = Read-Host
	if ($UserName -eq "")
	{
		$UserName = $ConnectionDefaultUser
	}

	try {
	
		if ($ConnectionType -ne "SCVMM")
		{
			Write-Host -ForegroundColor Green "Enter password for $UserName @ $HostURL :"
			Write-Host -ForegroundColor Green -NoNewLine "Password> "
			$Password = Read-Host -AsSecureString
			$Marshal = [Runtime.InteropServices.Marshal]
			$PTPassword = $Marshal::PtrToStringAuto($Marshal::SecureStringToBSTR($Password))
		}
		else
		{
			$Credential = Get-Credential -Credential $UserName
		}

		Write-Host
		Write-Host
		Write-Host -ForegroundColor Green "Attempting to connect to $HostURL .."
		Write-Host
		Write-Host

		$Ses = $null

		if ($ConnectionType -eq "XenServer")
		{
			$Ses = Connect-XenServer -url $HostURL -UserName $UserName -Password $PTPassword 
		}
		elseif ($ConnectionType -eq "VCenter")
		{
			$URLComps = $HostURL -Split "/"
		    if ($URLComps[2] -ne $null) 
	        {   
			  $Ses = Connect-VIServer -Server $URLComps[2] -User $UserName -Password $PTPassword
	        }
	        else
	        {
	    		$URLComps = $HostURL -Split "\\"
	    		$Ses = Connect-VIServer -Server $URLComps[2] -User $UserName -Password $PTPassword
	        }
		}
		elseif ($ConnectionType -eq "SCVMM")
		{
            $URLComps = $HostURL -Split ":"
			if ($URLComps[1] -ne $null)
			{
				$HostURL = $URLComps[0]
				if((Get-Module -Name $SCVMM2012Module) -ne $null)
				{
					$Ses = Get-SCVMMServer -ComputerName $HostURL -ConnectAs Administrator -Credential $Credential -TCPPort $URLComps[1]
				}else
				{
					$Ses = Get-VMMServer -ComputerName $HostURL -ConnectAs Administrator -Credential $Credential -TCPPort $URLComps[1]
				}

			}
 	        else
            {
			    if((Get-Module -Name $SCVMM2012Module) -ne $null)
			    {
				    $Ses = Get-SCVMMServer -ComputerName $HostURL -ConnectAs Administrator -Credential $Credential
			    }else
			    {
				    $Ses = Get-VMMServer -ComputerName $HostURL -ConnectAs Administrator -Credential $Credential
			    }
		    }
        }

		if ($Ses -ne $null)
		{
			$SuccessfulConnection = "yes"
	        $newhyp = (@($xml.PVDMigration.hypervisor)[0]).Clone()
	        $newhyp.type = $ConnectionType.ToString()
	        $xml.PVDMigration.AppendChild($newhyp) > $null
			Write-Log "Successfully connected to $ConnectionType Server: $HostURL"
		}
		else
		{
			Write-Log "Failed to Connect to the $ConnectionType Server: $HostURL"
		}
	}
	catch
	{
		Write-Log "Failed Connection to the server"
		Write-Log "$_.Exception.ToString()"
		ExitScript
	}
}

Write-Host
Write-Host


$ProcessedVMs=@()
$SkippedVMs=@()
$FailedVMs=@()
$DidResize=$false

Write-Host "Backing up Catalog Data..."
Write-Log "Backing up Catalog Data..."


try {

	foreach ($vm in get-brokermachine -CatalogName $PoolName)
	{
		$vmName = $vm.HostedMachineName
		$vmMachineName = $vm.MachineName
		$vmId = $vm.HostedMachineId;
		$PvDDiskPresent=$false
	    $vdiId = $null
		$vdiName = $null
	    $srName = $null
		$user = $null
		$userName = $null
		$userSid = $null
	    $srId = $null
	    
	    $alreadyConfigured = $false

		$user = get-BrokerUser -MachineUid $vm.Uid 

	    if($vmName -eq $null)
		{
			Write-Host -ForegroundColor Red	"WARNING: Hosted machine name is null for the following Virtual Machine: ID=$vmId!"
			Write-Log "WARNING: Hosted machine name is null for the following Virtual Machine: ID=$vmId!"
			$FailedVMs += "Virtual Machine ID: $vmId"
			continue
		}

		if($user -eq $null)
		{
			Write-Host "$vmName not assigned. Skipping it"
			Write-Log "$vmName not assigned. Skipping it"
			$SkippedVMs += $vmName
	                continue
		}
		else
		{
			$userName = $user.Name
			$userSid  = $user.sid
		}

		Write-Host "Processing VM $vmName"
		Write-Log "Processing VM $vmName"
		if ($ConnectionType -eq "XenServer")
		{
			Write-Log "Disk attached to the VM $vmName"

			foreach($vbd in get-xenserver:vm.vbds -vm $vmName)
			{
				if ($vbd.type -eq "Disk")
				{
					
					$vdi = get-xenserver:vbd.vdi -vbd $vbd.uuid
					
					Write-Log $vdi.name_label

					if ($vdi.name_label -match "_pvdisk")
					{
	                    $alreadyConfigured = $true;
						$PvDDiskPresent=$true
	                    $vdiId = $vdi.uuid
	                    $vdiName = $vdi.name_label
			    		$sr = get-xenserver:vdi.SR -VDI $vdiId
	                    $srName = $sr.name_label
	                    $srId = $sr.uuid
						break
					}
				}
			}

		}
		elseif ($ConnectionType -eq "VCenter")
		{
			$v = VMware.VIMautomation.Core\Get-VM $vmName
			$disks = Get-Harddisk -VM $vmName
	        $vdiName = $null
	        $vdiId = $null
	        $SrName = $null
	        
			Write-Log "Disk attached to the VM $vmName"

			foreach($disk in $disks)
			{
				Write-Log $disk.Filename
	            if ($disk.Filename -match  "_pvdisk")
				{
	                $alreadyConfigured = $true;
	                $vdiName = $disk.FileName
	                $vdiId = $disk.Id
					try
					{
	                	$SrName = ([regex]::matches($disk.FileName , "\[([^\]]+)\]"))[0].Groups[1].Value
	                }
					catch
					{
						Write-Log "Failed to get SR Name"
					}
					$srId = "id"
	                
				}		
			}
		}
		elseif ($ConnectionType -eq "SCVMM")
		{
			if((Get-Module -Name $SCVMM2012Module) -ne $null)
			{
				$v = Get-SCVirtualMachine -Name $vmName
			}else
			{
				$v = Microsoft.SystemCenter.VirtualMachineManager\Get-VM $vmName
			}


			if((Get-Module -Name $SCVMM2012Module) -ne $null)
			{
				$disk = Get-SCVirtualDiskDrive -VM $vmName | where {$_.VirtualHardDisk -match "_pvdisk"}
			}else
			{
				$disk = Get-VirtualDiskDrive -VM $vmName | where {$_.VirtualHardDisk -match "_pvdisk"}
			}
				
			if($disk -ne $null)
			{
				$alreadyConfigured = $true;
				$vdi = $disk.VirtualHardDisk
                if ($vdi -ne $null)
				{
                    $vdiName = $vdi.Location
                    $vdiId = $disk.ID.ToString()
					if ($vdi.HostVolume -ne $null)
					{
	        	    	$SrName = $vdi.HostVolume.Name
						$srId = $vdi.HostVolumeId.ToString()
					}
					elseif ($vdi.FileShare -ne $null)
					{       
                        $SrName = $vdi.FileShare.SharePath
						$srId = $vdi.FileShare.StorageVolumeID.ToString()	
					}
					else
					{
						$alreadyConfigured = $false
					}
				}
				else
				{
					$alreadyConfigured = $false
				}
			}
			else
			{
				Write-Host -ForegroundColor Red	"WARNING: The PvD disk is not configured for VM $vmName !"
				Write-Log "WARNING: The PvD disk is not configured for VM $vmName !"
				$FailedVMs += $vmName
			}
		}

		if ($alreadyConfigured -eq $false)
		{
			Write-Host -ForegroundColor Red	"WARNING: The PvD disk is not configured for VM $vmName !"
			Write-Log "Failed to find PvD Disk for VM $vmName"
			$FailedVMs += $vmName
		}
		else
		{
            Write-Host -ForegroundColor White "Disk Id:   $vdiId"
            Write-Host -ForegroundColor White "Disk Name: $vdiName"
            Write-Host -ForegroundColor White "Sr Name:   $SrName"
            Write-Host -ForegroundColor White "User Name: $userName"
            Write-Host -ForegroundColor White "User SID:  $userSid"
             
					
			Write-Log "Disk Name: $vdiName"
			Write-Log "SR Name  : $SrName"
			Write-Log "UserName : $userName"
			Write-Log "User SID	: $userSid"
			Write-Log ""
			
            $newpvd = (@($xml.PVDMigration.PVD)[0]).Clone()
            $newpvd.DiskId = $vdiId
            $newpvd.DiskName = $vdiName
            $newpvd.SRName = $SrName
            $newpvd.UserName = $userName
            $newpvd.UserSid = $userSid
            $newpvd.SRID = $srId
			$newpvd.State = "Backed Up"
            $xml.PVDMigration.AppendChild($newpvd) > $null
    
    		$ProcessedVMs += $vmName
		}


		Write-host
		write-host
	}
}
catch
{
	Write-Log "Failed to Backup Catalog"
	Write-Log "$_.Exception.ToString()"
	ExitScript
}

$ProcessedCt = $ProcessedVMs.count
$SkippedCt = $SkippedVMs.count
$FailedCt = $FailedVMs.count
Write-Host "Processed $ProcessedCt VM(s), Skipped $SkippedCt VM(s)"
Write-Log "Processed $ProcessedCt VM(s), Skipped $SkippedCt VM(s)"
if($FailedCt -gt 0)
{
	Write-Host -ForegroundColor Red "**WARNING:  The following $FailedCt VM(s) failed to configure properly :"
	Write-Log "**WARNING:  The following $FailedCt VM(s) failed to configure properly :"
	foreach ($failedVM in $FailedVMs)
	{
		Write-Host -ForegroundColor Red $failedVM
		Write-Log "$failedVM"
	}
}
	
Write-Host "DONE processing."
Write-Log "DONE processing."

if ($ConnectionType -eq "XenServer")
{
	DisConnect-XenServer -url $HostURL 
}
elseif ($ConnectionType -eq "VCenter")
{
	DisConnect-VIServer -Server $URLComps[2] -Confirm:$false -force
}

$PTPassword = ""

# if there is only one element in the xml, then the xml parser does not create an array of PVD. Add a dummy element

if ($ProcessedCt -eq 1)
{
	$newpvd = (@($xml.PVDMigration.PVD)[0]).Clone()
    $newpvd.DiskId = "Dummy"
    $newpvd.DiskName = "Dummy"
    $newpvd.SRName = "Dummy"
    $newpvd.UserName = "Dummy"
    $newpvd.UserSid = "Dummy"
    $newpvd.SRID = "Dummy"
	$newpvd.State = "Skip"
    $xml.PVDMigration.AppendChild($newpvd) > $null
}

cd $cwd

$xml.PVDMigration.hypervisor | Where-Object {$_.type -eq ""} | 
ForEach-Object {[void]$xml.PVDMigration.RemoveChild($_) }

$xml.PVDMigration.PVD | Where-Object {$_.DiskName -eq ""} | 
ForEach-Object {[void]$xml.PVDMigration.RemoveChild($_) }


#
# Save in the XML file
#
if ($ProcessedCt -gt 0)
{
	try {
		Write-Host "Saving it to $cwd\MigrationData-$PoolName.xml"
		Write-Log "Saving it to $cwd\MigrationData-$PoolName.xml"
		$xml.Save("$cwd\MigrationData-$PoolName.xml")

	}
	catch {
		Write-Log "Failed to save in the XML"
		Write-Log "$_.Exception.ToString()"
	}
}
else
{
	Write-Host "Nothing backed up"
	Write-Log "Nothing backed up"
}
# SIG # Begin signature block
# MIIXyAYJKoZIhvcNAQcCoIIXuTCCF7UCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUps2yMUEw4G/jUZkkdDzTXXlT
# iiCgghL2MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggT8MIID5KADAgECAhAtf1hf2lTQCZUe60J87xF6MA0GCSqGSIb3DQEBCwUAMH8x
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0G
# A1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMg
# Q2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENBMB4XDTE2MTEwNjAwMDAwMFoX
# DTE3MTEwNjIzNTk1OVowgZMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9y
# bmlhMRQwEgYDVQQHDAtTYW50YSBDbGFyYTEdMBsGA1UECgwUQ2l0cml4IFN5c3Rl
# bXMsIEluYy4xGzAZBgNVBAsMElhlbkFwcChQb3dlclNoZWxsKTEdMBsGA1UEAwwU
# Q2l0cml4IFN5c3RlbXMsIEluYy4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCpCp3LjS3rsoKAqjTp8aCVHa9Y1OkSVJGy84VnB3fRBP/0pwoa2AIG3IyR
# Mqvqnx45e3wynwKfzL6etRO/25EbpHppibiP797WpdRvf0Nfm3fg2ERIrzBTikYN
# JAZFqIlYV/Xm5qx28XYeBLDfDbRVFhHBkAEz6PT6DPXRi+0odq47oPDoO3zsNH+p
# 0Ull4vOCNXWXeNxmt0DwWwpjZA3vMTQuu6vWcwo13YpLqXZCbvgj/o8ogEW88g5q
# 5H9YUm3zzj7WSS5IxSsqvn9hnZkrSPDcdnTb7iT5bsR7jpdjs6wcRfXLVaTPwoLr
# y9zZ1NoOol8Ghwc3dx4190/LrLdvAgMBAAGjggFdMIIBWTAJBgNVHRMEAjAAMA4G
# A1UdDwEB/wQEAwIHgDArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8vc3Yuc3ltY2Iu
# Y29tL3N2LmNybDBhBgNVHSAEWjBYMFYGBmeBDAEEATBMMCMGCCsGAQUFBwIBFhdo
# dHRwczovL2Quc3ltY2IuY29tL2NwczAlBggrBgEFBQcCAjAZDBdodHRwczovL2Qu
# c3ltY2IuY29tL3JwYTATBgNVHSUEDDAKBggrBgEFBQcDAzBXBggrBgEFBQcBAQRL
# MEkwHwYIKwYBBQUHMAGGE2h0dHA6Ly9zdi5zeW1jZC5jb20wJgYIKwYBBQUHMAKG
# Gmh0dHA6Ly9zdi5zeW1jYi5jb20vc3YuY3J0MB8GA1UdIwQYMBaAFJY7U/B5M5ev
# fYPvLivMyreGHnJmMB0GA1UdDgQWBBQQUjCxrsvZoFDw3ZYdlRiHONi1uDANBgkq
# hkiG9w0BAQsFAAOCAQEANOL+b1tc/fgWk/aX81vFlRFgZ5NX7RCFgXVxD45tHNs6
# bLIjQnHN5XHGtbngqJ60fGAQknuySG2PGY+kgQil3NZkCAp51ItNp3T6mhTf8xQ8
# SKqbt3RiWQanYkoye7/pa+NxDh5Zd6KgAjDfw+YQvfS+AWjP6dd+Zt8l49ISUa23
# ki6H0nhtxkialRzEIFhWymWMSv+rHQ62yXCQ2ArjZty/tUTV7pykEgSvhTEVcTr8
# kY1SBM4KYYT9XyL34HkdYmOP1cnfs4IW9qGqLbNrB1JR4Vtcfe3zBfpU+Oek6nyt
# 6pOMTId7eYUtA4Y0upJsc0qYRYvTfBWuJ6xQ4UvaFjCCBVkwggRBoAMCAQICED14
# 1/l2SWCyYX308B7KhiowDQYJKoZIhvcNAQELBQAwgcoxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3Qg
# TmV0d29yazE6MDgGA1UECxMxKGMpIDIwMDYgVmVyaVNpZ24sIEluYy4gLSBGb3Ig
# YXV0aG9yaXplZCB1c2Ugb25seTFFMEMGA1UEAxM8VmVyaVNpZ24gQ2xhc3MgMyBQ
# dWJsaWMgUHJpbWFyeSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAtIEc1MB4XDTEz
# MTIxMDAwMDAwMFoXDTIzMTIwOTIzNTk1OVowfzELMAkGA1UEBhMCVVMxHTAbBgNV
# BAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVz
# dCBOZXR3b3JrMTAwLgYDVQQDEydTeW1hbnRlYyBDbGFzcyAzIFNIQTI1NiBDb2Rl
# IFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCXgx4A
# Fq8ssdIIxNdok1FgHnH24ke021hNI2JqtL9aG1H3ow0Yd2i72DarLyFQ2p7z518n
# TgvCl8gJcJOp2lwNTqQNkaC07BTOkXJULs6j20TpUhs/QTzKSuSqwOg5q1PMIdDM
# z3+b5sLMWGqCFe49Ns8cxZcHJI7xe74xLT1u3LWZQp9LYZVfHHDuF33bi+VhiXjH
# aBuvEXgamK7EVUdT2bMy1qEORkDFl5KK0VOnmVuFNVfT6pNiYSAKxzB3JBFNYoO2
# untogjHuZcrf+dWNsjXcjCtvanJcYISc8gyUXsBWUgBIzNP4pX3eL9cT5DiohNVG
# uBOGwhud6lo43ZvbAgMBAAGjggGDMIIBfzAvBggrBgEFBQcBAQQjMCEwHwYIKwYB
# BQUHMAGGE2h0dHA6Ly9zMi5zeW1jYi5jb20wEgYDVR0TAQH/BAgwBgEB/wIBADBs
# BgNVHSAEZTBjMGEGC2CGSAGG+EUBBxcDMFIwJgYIKwYBBQUHAgEWGmh0dHA6Ly93
# d3cuc3ltYXV0aC5jb20vY3BzMCgGCCsGAQUFBwICMBwaGmh0dHA6Ly93d3cuc3lt
# YXV0aC5jb20vcnBhMDAGA1UdHwQpMCcwJaAjoCGGH2h0dHA6Ly9zMS5zeW1jYi5j
# b20vcGNhMy1nNS5jcmwwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMDMA4G
# A1UdDwEB/wQEAwIBBjApBgNVHREEIjAgpB4wHDEaMBgGA1UEAxMRU3ltYW50ZWNQ
# S0ktMS01NjcwHQYDVR0OBBYEFJY7U/B5M5evfYPvLivMyreGHnJmMB8GA1UdIwQY
# MBaAFH/TZafC3ey78DAJ80M5+gKvMzEzMA0GCSqGSIb3DQEBCwUAA4IBAQAThRoe
# aak396C9pK9+HWFT/p2MXgymdR54FyPd/ewaA1U5+3GVx2Vap44w0kRaYdtwb9oh
# BcIuc7pJ8dGT/l3JzV4D4ImeP3Qe1/c4i6nWz7s1LzNYqJJW0chNO4LmeYQW/Ciw
# sUfzHaI+7ofZpn+kVqU/rYQuKd58vKiqoz0EAeq6k6IOUCIpF0yH5DoRX9akJYmb
# BWsvtMkBTCd7C6wZBSKgYBU/2sn7TUyP+3Jnd/0nlMe6NQ6ISf6N/SivShK9DbOX
# Bd5EDBX6NisD3MFQAfGhEV0U5eK9J0tUviuEXg+mw3QFCu+Xw4kisR93873NQ9Tx
# TKk/tYuEr2Ty0BQhMYIEPDCCBDgCAQEwgZMwfzELMAkGA1UEBhMCVVMxHTAbBgNV
# BAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVz
# dCBOZXR3b3JrMTAwLgYDVQQDEydTeW1hbnRlYyBDbGFzcyAzIFNIQTI1NiBDb2Rl
# IFNpZ25pbmcgQ0ECEC1/WF/aVNAJlR7rQnzvEXowCQYFKw4DAhoFAKBwMBAGCisG
# AQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTp0/1EU5n6Epg9
# A1eYAPoKwHUFpzANBgkqhkiG9w0BAQEFAASCAQBD1xdypxN0Im+aWOYDeVnXGcTf
# W7+sfbjTVtGavgkzJ4bc5dnFW5+mKOwHaCD6cr97iXFhKY+EUSdC0mrfsKDELuIQ
# kiNL66wzmJSmjDA1GZn5vs4/WaqQ7SF/+YSAYucF7BY5lXueSNxezqwuACHc5qHz
# 6NriGaTDRkK+FyrNdduee0dEaMR5Ge1Ns+RidxP4pSk6wcrbuPIrFvJ6+xYQM7Od
# bywxL9V15yZyvHzvRvnJ292sTAfFvUPfh+Aur/0t+OzBj1ql05jMPT4QyORdbj/I
# 8t9AB2RtKW50xX92eMGfdwPbwY0an0y4mrfQj6kRkcwndXUxTiLsqqbbQL3RoYIC
# CzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMCVVMxHTAb
# BgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBU
# aW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTYapgbGlAw
# CQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTE3MDQwNzA2MzcxMFowIwYJKoZIhvcNAQkEMRYEFAYDSD03Bbdo7w6f
# HgcdbOEE1MaxMA0GCSqGSIb3DQEBAQUABIIBAH0FU/wUiWkNpwi7wQ7X/GyCzDsk
# Jo/CVCk/G4TQCNp5ASsNv/PXQw0bEJ2yLL0tDuGXGv7GQX04sbvfBBHSi1DE4oz9
# B05YzbRQYyqEhpxoaNYSLre6EaDuwMScYjNZWwXD4v8udNOS5Js8YifJkZDML7iY
# cCkVdoEtWdML+J7f3hqjQSWFFIP7f/P5/VA2Jya/c9v4IZxn6CjW0eBVnXWCWXr2
# HfrKYu2Ngs0jLzZz5qyM9HH4oD4dZNId3YBmDDHIv9h66vsKC+xr/NyMYFR8evQ8
# yGOYCF3Q2SYYr4mk6cp7tC0odXynqriHmIfdwByAe/9OjlxP/KDICQn1nvY=
# SIG # End signature block
