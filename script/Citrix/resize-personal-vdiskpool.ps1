$SCVMM2012Module = "VirtualMachineManager"

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
		}
	}else
	{
		# Older version of SCVMM. Try loading the snapin
		Add-PsSnapin $snapin  -ErrorVariable err -errorAction SilentlyContinue
		if($err -ne $null)
		{
			Write-Host -ForegroundColor Red "$snapin toolkit could not be loaded: $err"
		}
	}
}

LoadSnapin "Citrix.*"
LoadSnapin "PvsPsSnapIn"

$cwd = get-location;
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

	$pools = @()
	while ($PoolName -eq "")
	{
		
		Write-Host -ForegroundColor Yellow "Please select a catalog (by number) from the following list:"
		$ct=0
		foreach($Catalog in get-brokermachine -MaxRecordCount 100000 | select -unique CatalogName)
		{
			$ct++;
			$CatNam = $Catalog.CatalogName
			$pools += $CatNam
			Write-Host -ForegroundColor Gray "$ct : $CatNam"
		}

        if ($ct -le 0)
        {
            Write-Host
            Write-Host -ForegroundColor Red "No catalogs found"
            Write-Host
            Exit
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

					if ($SelCat.CatalogKind -eq "Pvs" -and $SelCat.AllocationType -eq "Random")
					{
						Write-Host -ForegroundColor Yellow "Citrix Personal vDisk requires that the selected catalog be converted to support private desktops."
						Write-Host -ForegroundColor Yellow "Answer 'Y' to convert the catalog."
						$MachinesInCatalog = Get-BrokerMachine -CatalogName $pools[$SelIdx] -MaxRecordCount 100000
						$Desktops = Get-BrokerDesktop
						$AffectedDesktopGroups = @()
						foreach ($Machine in $MachinesInCatalog)
						{
							foreach ($Desktop in $Desktops)
							{
								if ($Desktop.MachineName -eq $Machine.MachineName)
								{
									$AffectedDesktopGroup = $Desktop.DesktopGroupName
									$FoundDG=$false
									foreach ($DG in $AffectedDesktopGroups)
									{
										if ($DG -eq $AffectedDesktopGroup)
										{
											$FoundDG = $true
										}
									}

									if ($FoundDG -eq $false)
									{
										$AffectedDesktopGroups += $AffectedDesktopGroup
									}
								}
							}
						}

						if ($AffectedDesktopGroups.count -gt 0)
						{
							Write-Host -ForegroundColor Red "The following desktop group(s) contain desktops from the selected catalog."
							Write-Host -ForegroundColor Red "You will need to delete the following desktop group(s) before the catalog you"
							Write-Host -ForegroundColor Red "have selected can be used with personal vDisk. Delete the group(s) shown below and then"
							Write-Host -ForegroundColor Red "run this script again."
							foreach ($AffectedDesktopGroup in $AffectedDesktopGroups)
							{
								Write-Host -ForegroundColor Red $AffectedDesktopGroup
							}
							Exit	
						}
						else
						{
							Write-Host -ForegroundColor Red -NoNewLine   "This action is irreversible - Are you sure you want to continue (Y/N) ? "
						}
						$ConvCatYN = Read-Host
						if ($ConvCatYN -match "y")
						{
							$PoolName = $pools[$SelIdx]
						
							Write-Host
							Write-Host
							Write-Host

							Write-Host "Converting Catalog $PoolName ..."
							$ExistingCatalog = Get-BrokerCatalog -name $PoolName
							
							Write-Host "Removing VMs ..."
							$MachinesInCatalog | Remove-BrokerMachine -Force
							Write-Host "Removing Catalog ..."
							Remove-BrokerCatalog -Name $PoolName
							Write-Host "Recreating Catalog ..."
							$NewCatalog = New-BrokerCatalog -Name $PoolName -CatalogKind 'Pvs' -AllocationType 'Permanent' -PvsDomain $ExistingCatalog.PvsDomain -PvsAddress $ExistingCatalog.PvsAddress -Description $ExistingCatalog.Description -MachinesArePhysical $ExistingCatalog.MachinesArePhysical
							Write-Host "Adding VMs ..."
							if ($ExistingCatalog.MachinesArePhysical)
							{
								foreach ($Machine in $MachinesInCatalog)
								{
									$m = New-BrokerMachine -MachineName $Machine.MachineName -CatalogUid $NewCatalog.Uid
								}
							}
							else
							{
								foreach ($Machine in $MachinesInCatalog)
								{
									$m = New-BrokerMachine -MachineName $Machine.MachineName -CatalogUid $NewCatalog.Uid -HostedMachineId $Machine.HostedMachineId -HypervisorConnectionUid $Machine.HypervisorConnectionUid
								}
							}
						
						}
					}
					else
					{
						$PoolName = $pools[$SelIdx]
					}
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
	foreach($d in (Get-BrokerMachine -CatalogName $PoolName))
	{
		if(!($ConnectionNames -contains $d.HypervisorConnectionName))
		{
			$ConnectionNames += $d.HypervisorConnectionName
		}
	}
	
	$Connections = @()
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
	
	
	$ConnectionURL = $Connections[0].HypervisorAddress
	$ConnectionType = $Connections[0].ConnectionType
	$ConnectionDefaultUser = $Connections[0].UserName	
	$HostURL = $ConnectionURL[0]

	# Load the correct snap-in based on the connection type
	if ($ConnectionType -eq "XenServer")
	{
		LoadXenServerSnapin
	}elseif ($ConnectionType -eq "SCVMM")
	{
		LoadSCVMM
	}
	elseif ($ConnectionType -eq "VCenter")
	{
		LoadVMwareSnapin
	}
	
	Set-Location $cwd

	$SizeOK = $false
	$oldSize = 10000000000
	
	while($SizeOK -eq $false)
	{
		Write-Host
		Write-Host
		Write-Host
		Write-Host -ForegroundColor Yellow "Please enter the new size for the personal vDisk disk:"
		Write-Host -ForegroundColor Yellow "(Size in bytes with optional multiplier (KB, MB, GB, TB) factor -"
		Write-Host -ForegroundColor Yellow " for example, to select a disk size of 10GB, you may enter"
		Write-Host -ForegroundColor Yellow " 10GB, 10000MB, or 10000000000)"
		Write-Host -ForegroundColor Yellow "Note : The minimum personal vDisk workspace disk size is 3GB."
		Write-Host
		if ($OldSize -ne "")
		{
			Write-Host -ForegroundColor White -noNewLine "Disk Size ($OldSize)> "
		}
		else
		{
			Write-Host -ForegroundColor White -noNewLine "Disk Size> "
		}
		$Size = Read-Host

		if ($Size -eq "" -and $OldSize -ne "")
		{
			$Size = $OldSize
		}
		else
		{
			$SizeQty=""

			if($Size -match "\.\d+")
			{
				$SizeQty = $matches[0]
			}
			elseif($Size -match "\d+")
			{
				$SizeQty = $matches[0]
			}

			if($SizeQty -ne "")
			{
				$Mult = 1

				if($Size -match "KB$" -or $Size -match "K$")
				{
					$Mult = 1024
				}

				if($Size -match "MB$" -or $Size -match "M$")
				{
					$Mult = 1048576
				}

				if($Size -match "GB$" -or $Size -match "G$")
				{
					$Mult = 1073741824
				}

				if($Size -match "TB$" -or $Size -match "T$")
				{
					$Mult = 1099511627776
				}

				$Size = $Mult * (0 + $SizeQty)
			}
		
		}

		$OldSize = $Size
		$SizeGB = $Size / 1073741824
		
		if($Size -lt 3221225472)
		{
			Write-Host
			Write-Host -ForegroundColor Red "The minimum capacity of the personal vDisk workspace disk is 3GB."
			Write-Host
		}
		else
		{
			$SizeOK = $true
		}
	}

	Write-Host
	Write-Host
	Write-Host
	Write-Host -ForegroundColor Yellow "Selection Summary"
	Write-Host -ForegroundColor Gray -NoNewLine "Catalog Name:     "
	Write-Host -ForegroundColor White $PoolName
	Write-Host -ForegroundColor Gray -NoNewLine "Personal vDisk Disk Size : "
	Write-Host -ForeGroundColor White "$Size ($SizeGB GB)"

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
$XenSnapinVer = 1

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
        if (Get-Command Get-XenVM -ea SilentlyContinue) 
        { 
            $Ses = Connect-XenServer -url $HostURL -UserName $UserName -Password $PTPassword -SetDefaultSession -PassThru
        }elseif (Get-Command Get-XenServer:VM -ea SilentlyContinue)
        {
            $XenSnapinVer = 0
        }
	}
	elseif ($ConnectionType -eq "VCenter")
	{
		$URLComps = $HostURL -Split "/"
	
		$Ses = Connect-VIServer -Server $URLComps[2] -User $UserName -Password $PTPassword
	}
	elseif ($ConnectionType -eq "SCVMM")
	{
		if((Get-Module -Name $SCVMM2012Module) -ne $null)
		{
			$Ses = Get-SCVMMServer -ComputerName $HostURL -ConnectAs Administrator -Credential $Credential
		}else
		{
			$Ses = Get-VMMServer -ComputerName $HostURL -ConnectAs Administrator -Credential $Credential
		}
	}

	if ($Ses -ne $null)
	{
		$SuccessfulConnection = "yes"
	}else
    {
        Write-Host "Connection unsuccessful. Try again."
    }
}

Write-Host
Write-Host


$ProcessedVMs=@()
$SkippedVMs=@()
$FailedVMs=@()
$DidResize=$false

Write-Host "Processing VMs..."

foreach ($vm in get-brokermachine -CatalogName $PoolName -MaxRecordCount 100000)
{
	$vmName = $vm.HostedMachineName
	$vmMachineName = $vm.MachineName
	$vmId = $vm.HostedMachineId;
	$PvDDiskPresent=$false
	$needReboot=$false
	$needTurnOn=$false
	$needResize = $false
	$resizeVdi = $null
	$notResizing = $false
	if($vmName -eq $null)
	{
		Write-Host -ForegroundColor Red	"WARNING: Hosted machine name is null for the following Virtual Machine: ID=$vmId!"
		$FailedVMs += "Virtual Machine ID: $vmId"
		continue
	}
	Write-Host "Processing VM $vmName"
	if ($ConnectionType -eq "XenServer")
	{
        $vbds = @()
        if ($XenSnapinVer -lt 1)
        {
            $vbds = get-xenserver:vm.vbds -vm $vmName
        }else
        {
            $vmVbds = (Get-XenVM -Name $vmName).VBDs
            foreach ($vbd in $vmVbds) { $vbds += Get-XenVBD $vbd }
        }
        
		foreach($vbd in $vbds)
		{
			if ($vbd.type -eq "Disk")
			{
                $vdi = ""
                if ($XenSnapinVer -lt 1)
                {
                    $vdi = get-xenserver:vbd.vdi -vbd $vbd.uuid
                }else
                {
                    $vdi = Get-XenVDI -Ref $vbd.VDI
                }
				if ($vdi.name_label -match "_pvdisk")
				{
					$PvDDiskPresent=$true
					if ($vdi.virtual_size -lt $Size)
					{
						if ($vm.Powerstate -eq "Off")
						{
							$vdiSize = $vdi.virtual_size
							$needResize = $true;
							$resizeVdi = $vdi
							Write-Host -ForegroundColor White "Disk will be resized from $vdiSize to $Size ..."
						}
						else
						{
							Write-Host -ForegroundColor White "$vmName is currently powered on, cannot resize disk ..."
							$notResizing = $true
							$skippedVMs += $vmName
						}
					}
					break
				}
			}
		}
		if($PvDDiskPresent -eq $false)
		{
			# The disk should always be present
			Write-Host -ForegroundColor Red	"WARNING: The PvD disk is not configured for VM $vmName !"
			$FailedVMs += $vmName
		}
		elseif ($needResize -eq $true)
		{
			$resizeUUID = $resizeVdi.uuid
            if ($XenSnapinVer -lt 1)
            {
                invoke-xenserver:vdi.resize -vdi $resizeUUID -Size $Size
            }else
            {
                Invoke-XenVDI -VDI $resizeVdi -XenAction Resize -Size $Size
            }
			
			Write-host "Resizing of disk to $Size bytes completed ..."
			$DidResize=$true
			$ProcessedVMs += $vmName
		}
		elseif ($notResizing -eq $false)
		{
			Write-Host -ForegroundColor White "$vmName was already configured for personal vDisk, skipping ..."
			$SkippedVMs += $vmName
		}
	}
	elseif ($ConnectionType -eq "VCenter")
	{
		$ResizeDisk=$null
		$DidResize = $false
		$alreadyConfigured = $false
		$SizeKB = $Size / 1024

		$v = VMware.VIMautomation.Core\Get-VM $vmName
		if ($v.ExtensionData.Config.guestId -eq "winXPProGuest")
		{
			Write-Host -ForegroundColor White "$vmName skipped. Resize is not supported on Windows XP"
			$SkippedVMs += $vmName
		}else
		{
			$disks = Get-Harddisk -VM $vmName
			foreach($disk in $disks)
			{
				if ($disk.Filename -match  "_pvdisk")
				{
					$alreadyConfigured = $true;
					
					if ($disk.CapacityKB -lt $SizeKB)
					{
						$ResizeDisk = $disk
						$Cap = $disk.CapacityKB
						Write-Host -ForegroundColor White "Resizing disk from $Cap KB to $SizeKB KB"
						Set-HardDisk -HardDisk $ResizeDisk -CapacityKB $SizeKB -Confirm:$false
						$DidResize=$true
						$ProcessedVMs += $vmName
					}else
					{
						Write-Host -ForegroundColor White "$vmName was already configured for personal vDisk"
					}
					
					break
				}
			}
		
			if ($alreadyConfigured -eq $false)
			{
				Write-Host -ForegroundColor Red	"WARNING: The PvD disk is not configured for VM $vmName !"
				$FailedVMs += $vmName
			}else
			{
				if ($DidResize -eq $false)
				{
					$SkippedVMs += $vmName
				}
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
		if ($v.Status -eq "Running")
		{
			Write-Host -ForegroundColor White "Cannot process $vmName since it is currently running ..."
			$SkippedVMs += $vmName
		}
		else
		{

			$ResizeDisk=$null
			$DidResize = $false
			$SizeMB = $Size / 1048576 -as "int"
			$SizeGB = $SizeMB / 1024            

			if((Get-Module -Name $SCVMM2012Module) -ne $null)
			{
				$disk = Get-SCVirtualDiskDrive -VM $vmName | where {$_.VirtualHardDisk -match "_pvdisk"}
			}else
			{
				$disk = Get-VirtualDiskDrive -VM $vmName | where {$_.VirtualHardDisk -match "_pvdisk"}
			}
			
			if($disk -ne $null)
			{
				Write-Host
				Write-Host -ForegroundColor White "$vmName was already configured for personal vDisk"
				if ($disk.VirtualHardDisk.MaximumSize -lt $Size)
				{	

					$ResizeDisk = $disk
					$Cap = $disk.VirtualHardDisk.MaximumSize / 1048576
					Write-Host -ForegroundColor White "Resizing disk from $Cap MB to $SizeMB MB"
					if((Get-Module -Name $SCVMM2012Module) -ne $null)
					{
						Expand-SCVirtualDiskDrive -VirtualDiskDrive $disk -Size $SizeGB
					}else
					{
						Expand-VirtualDiskDrive -VirtualDiskDrive $disk -Size $SizeGB
					}
					$DidResize=$true
					$ProcessedVMs += $vmName
				}

				if ($DidResize -eq $false)
				{
					$SkippedVMs += $vmName
				}
			}
			else
			{
				Write-Host -ForegroundColor Red	"WARNING: The PvD disk is not configured for VM $vmName !"
				$FailedVMs += $vmName
			}
		}
	}

	if ($needTurnOn -eq $true)
	{
		Write-Host "Starting $vmName ..."
		$PA = New-BrokerHostingPowerAction -MachineName $vmMachineName -Action TurnOn -ActualPriority 1
	}

	if ($needReboot -eq $true)
	{
		Write-Host "Restarting $vmName ..."
		$PA = New-BrokerHostingPowerAction -MachineName $vmMachineName -Action Restart -ActualPriority 1
	}

	Write-host
	write-host
}

$ProcessedCt = $ProcessedVMs.count
$SkippedCt = $SkippedVMs.count
$FailedCt = $FailedVMs.count
Write-Host "Reconfigured $ProcessedCt VM(s), Skipped $SkippedCt VM(s)"
if($FailedCt -gt 0)
{
	Write-Host -ForegroundColor Red "**WARNING:  The following $FailedCt VM(s) failed to configure properly :"
	foreach ($failedVM in $FailedVMs)
	{
		Write-Host -ForegroundColor Red $failedVM
	}
}
	
if ($DidResize -eq $true)
{
	Write-Host
	Write-Host
	Write-Host -ForegroundColor White "**One or more personal vDisk persistent user disks were resized. This change"
	Write-Host -ForegroundColor White "  will be visible to users only after pool restart occurs."
	Write-Host
}

Write-Host "DONE processing."

if ($ConnectionType -eq "XenServer")
{
    Disconnect-XenServer
}
elseif ($ConnectionType -eq "VCenter")
{
	DisConnect-VIServer -Server $URLComps[2] -Confirm:$false -force
}

$PTPassword = ""

cd $cwd

# SIG # Begin signature block
# MIIXyAYJKoZIhvcNAQcCoIIXuTCCF7UCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7fMn3bZUEoricyuXwWi2UDBs
# w3igghL2MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQ8Rt2K2/FZvHaC
# gcyR4bAx414f2zANBgkqhkiG9w0BAQEFAASCAQABA1QNllRWcm21e+NiZFvbtUMz
# haU2DXSQw34C6YIVeObuApo2fcJ29MJSlMaNZxyeeeSAF0bLVrKeMCalyjhRZxNp
# zkXnjFqLanYhRB1t+MiQDP5Yu02uUlcjYSIcBGFO52EjJ9E2SopT6bpNPCizavkF
# /n3/Mq0ud8uG6EBZ+Kl10+umCgeJfG2VpFk90IVZSBtzJFsHgLo4ooa9BDkKCTM8
# l/HTds1NKuDpmpYHcf1A2Dz6ZEZt94tjI3x4DhZruQKTZd7ZJ8bKvc7qxNDzjI5f
# Au4vc8cjV1Fb4faYKT39emv6sZry8GbuxeTFzgnKHJOxC7sOe8tb5JBm4hduoYIC
# CzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMCVVMxHTAb
# BgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBU
# aW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTYapgbGlAw
# CQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTE3MDQwNzA2MzcxMlowIwYJKoZIhvcNAQkEMRYEFH/S65W9obWTeUui
# RnduWSegoMMhMA0GCSqGSIb3DQEBAQUABIIBAGBxyuvEFy5Buxtf6LTjsMt3Qelz
# IiDLDXZtZ7kQFuJ93Lwx77SDybOunM+EYTuMhzCT53FjeNRkiU4/Cklti1+Q7x9C
# YFKQ2oFy+mK1djzMAQCA6Qf0aHRxE3IHx+DUrrhIE1hTAh0O5X1q+8fwv935mk8n
# V+mXhOREFvgQ+L+2PlLZRPCvApV1xDnQkClMuaI1od1rrh2TrbrFL+6ADwSiZcaD
# X8+vFwz6G3Yz2E0PSxvrq3UBaHiVq3WMZWT5LhQvm2pkGgW61PG3U3BHxxWKraNv
# UzlRjj1drk6PJEjDkwb7L4tYVXrHHwRdHLnBxAcTL4tZ+O5ncMnEHWN97Hw=
# SIG # End signature block
