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
	}
}

LoadSnapin "Citrix.*"
LoadSnapin "PvsPsSnapIn"
Add-PsSnapin "VMware.View.Broker" -errorAction SilentlyContinue

$SnapIns = Get-PSSnapIn

$isView = $false
foreach ($SnapIn in $SnapIns)
{
	if ($SnapIn.Name -eq "VMware.View.Broker")
	{
		$isView = $true
	}
}

$cwd = get-location;

$PoolName=""

Write-Host
	
if ($isView -eq $true)
{
	$Catalogs = get-pool | select -unique pool_id
	$Title = "pool"
}
else
{
	$Catalogs = get-brokermachine -MaxRecordCount 100000 | select -unique CatalogName
	$Title = "catalog"
}

$pools = @()
while ($PoolName -eq "")
{
	Write-Host -ForegroundColor Yellow "Please select a $Title (by number) from the following list:"
	$ct=0
	foreach($Catalog in $Catalogs)
	{
		$ct++;
		if ($isView -eq $true)
		{
			$CatNam = $Catalog.pool_id
		}
		else
		{
			$CatNam = $Catalog.CatalogName
		}
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
			
	Write-Host -ForegroundColor White -NoNewLine "Selection> "
			
	$Selection = Read-Host
			
	if($Selection -match "^\d+$")
	{
		$SelIdx = $Selection - 1

		if($SelIdx -lt 0 -or $SelIdx -ge $pools.count)
		{
			Write-Host
			Write-Host -ForegroundColor Red "No such $Title"
			Write-Host
		}
		else
		{
			$PoolName = $pools[$SelIdx]
		}
	}
	else	
	{	
		Write-Host
		Write-Host -ForegroundColor Red "Invalid input"
		Write-Host
	}
}

Write-Host

$machines=@()
$powerstates=@()
$servicestates=@()
$nativestates=@()
$users=@()
$jobs=@()
$jobids=@()
$ok=@()
$svms=@()
$apppercent=@()
$updatestates=@()
$apptotal=@()
$profpercent=@()
$proftotal=@()

if ($isView -eq $true)
{
	$xvms = get-desktopvm -pool_id $PoolName
}
else
{
	$xvms=get-brokermachine -MaxRecordCount 100000 -CatalogName $PoolName
}

$ct=0

# handle a pool of size 1
if($xvms.count -eq $null)
{
	$svms += $xvms
	$vms = $svms
}
else
{
	$vms = $xvms
}

for($i=0; $i -lt 5; $i++)
{
	$jobs += ""
	$jobids += ""
}

for($i=0; $i -lt $vms.count; $i++)
{
	$servicestates += ""
	$nativestates += ""
	$machines += ""
	$users += ""
	$powerstates += ""
	$apppercent += ""
	$apptotal += ""
	$profpercent += ""
	$proftotal += ""
	$updatestates += ""
	$ok += $true
}

while ($ct -lt $vms.count)
{
	$grpend = $ct + 5
	$grpstart = $ct + 1

	if( $grpend -gt $vms.count )
	{
		$grpend = $vms.count
	}

	Write-Host "Processing VMs $grpstart through $grpend ..."
	# scatter
	for($i=0; $i -lt 5 -and $ct -lt $vms.count; $i++, $ct++)
	{
		if ($isView -eq $true)
		{
			$machines[$ct] = $vms[$ct].Name
			$powerstates[$ct] = "N/A"
			if($vms[$ct].user_displayname -ne $null)
			{
				$users[$ct] = $vms[$ct].user_displayname
			}
			else
			{
				$users[$ct] = "Unassigned"
			}
		}
		else
		{
			$machines[$ct] = $vms[$ct].HostedMachineName
			$powerstates[$ct] =  $vms[$ct].powerstate
			if($vms[$ct].AssociatedUserFullNames[0] -ne $null)
			{
				$users[$ct] = $vms[$ct].AssociatedUserFullNames[0]
			}
			else
			{
				$users[$ct] = "Unassigned"
			}
		}
		if ($powerstates[$ct] -eq "On" -or $isView -eq $true)
		{
			$jobids[$i] = $ct
			$jobs[$i] = start-job -name $machines[$ct] -scriptblock {
				# Script block output is a 5-line tuple:
				#
				# Native Status
				# App % used
				# App Size (bytes)
				# Profile % used
				# Profile Size (bytes)
				# Personal vDisk Status
				# Recompose Status
				# 
				
                $vns = Get-WmiObject -ComputerName $args[0] -Namespace Root\Cimv2 -Class Win32_Service | ?{$_.Name -eq 'CitrixPvD'}
				if($vns -eq $null)
				{
					Write-output "Not Installed"
					Write-output "??"
					Write-output "??"
					Write-output "??"
					Write-output "??"
					Write-output "Not Installed"
					Write-output "Unknown"
				}
				else
				{
					$stat=$vns.state
                    write-output $stat
					$PvDPool=get-wmiobject -ComputerName $args[0] -Namespace root\Citrix -Class Citrix_PvDPool
					$PvDOk=$false
					if ($PvDPool -ne $null) 
					{
						if ( $PvDPool.IsActive -eq $true )
						{
							$PvDPool=get-wmiobject -ComputerName $args[0] -Namespace root\Citrix -Class Citrix_PvDPool
							if ($PvDPool.count -ne $null)
							{
								$PvDPool = $PvDPool[0]
							}
							$pctUsed = $PvDPool.CurrentAppSizeBytes / $PvDPool.TotalAppSizeBytes
							Write-Output $pctused
							Write-Output $PvDPool.TotalAppSizeBytes
							
							$pctUsed = $PvDPool.CurrentProfSizeBytes / $PvDPool.TotalProfSizeBytes
							Write-Output $pctused
							Write-Output $PvDPool.TotalProfSizeBytes
							
							Write-output "Running"
							$PvDOk=$true
						}
						else
						{
							Write-output "??"
							Write-output "??"
							Write-output "??"
							Write-output "??"
							Write-output "No"
						}
					}
					else
					{
						Write-output "??"
						Write-output "??"
						Write-output "??"
						Write-output "??"
						Write-output "No"
					}
						
					# No PvD, check image update state
					if ($PvDOk -eq $false)
					{
						if ($PvDPool.StatusText -ne "") 
						{
							Write-Output $PvDPool.StatusText
						}
						else
						{
							Write-output "Unknown"
						}
					}
					else
					{
						Write-output "OK"
					}
				}
			} -argumentList $machines[$ct]
		
		}
		else
		{
			$servicestates[$ct] = "VM Off"
			$nativestates[$ct] = "VM Off"
			$ok[$ct]="Off"
			$jobs[$i]=$null
			$updatestates[$ct] = "VM Off"
		}
	}

	Write-Host -NoNewLine "Waiting for this group of VMs to respond "
	# gather
	for($i=0; $i -lt 5; $i++)
	{
		if ($jobs[$i] -ne $null -and $jobs[$i] -ne "")
		{
			Write-Host -NoNewLine "."
			wait-job -id $jobs[$i].id -timeout 45 -erroraction silentlycontinue | out-null
		}
	}

	Write-Host
	Write-Host "Summarizing this group of VMs ..."
	for($i=0; $i -lt 5; $i++)
	{
		if ($jobs[$i] -ne $null -and $jobs[$i] -ne "")
		{
			$job=Wait-job -id $jobs[$i].id -timeout 5 -erroraction silentlycontinue
			if($job -ne $null -and $job -ne "")
			{
				$out=$job | receive-job -keep -erroraction silentlycontinue
				if ($out.count -ne $null)
				{
					$servicestates[$jobids[$i]]=$out[0]
					$apppercent[$jobIds[$i]]=$out[1]
					$apptotal[$jobids[$i]]=$out[2]
					$profpercent[$jobids[$i]]=$out[3]
					$proftotal[$jobids[$i]]=$out[4]
					$nativestates[$jobids[$i]]=$out[5]
					if($servicestates[$jobids[$i]].value -ne "Running")
					{
						$ok[$jobids[$i]]=$false
					}
					$updatestates[$jobids[$i]]=$out[6]
				
					if ($nativestates[$jobids[$i]] -ne "Running")
					{
						if ($updatestates[$jobids[$i]] -eq "Unknown" -or $updatestates[$jobids[$i]] -match "Error")
						{
							$ok[$jobids[$i]]=$false
						}
						else
						{
							$ok[$jobids[$i]]=$true
						}
					}
					else
					{
						$ok[$jobids[$i]]=$true
					}
				}
				else
				{
					$servicestates[$jobids[$i]]="Unknown"
					$nativestates[$jobids[$i]]="Unknown"
					$apppercent[$jobids[$i]]="??"
					$apptotal[$jobids[$i]]="??"
					$profpercent[$jobids[$i]]="??"
					$proftotal[$jobids[$i]]="??"
					$ok[$jobids[$i]]=$false
					$updatestates[$jobids[$i]]="Unknown"
				}

				#$job | remove-job -erroraction silentlycontinue
			}
			else
			{
				$servicestates[$jobids[$i]]="Timeout"
				$nativestates[$jobids[$i]]="Timeout"
				$apppercent[$jobids[$i]]="??"
				$apptotal[$jobids[$i]]="??"
				$profpercent[$jobids[$i]]="??"
				$proftotal[$jobids[$i]]="??"
				$ok[$jobids[$i]]=$false
				$updatestates[$jobids[$i]]="Timeout"
			}
		}
	}
	Write-Host
}

# #	     Machine  User  Service Pvd      App    profile  Update
"{0,-4} {1,-16} {2,-18} {3,-13} {4,-13} {5,-16} {6,-16} {7, -14}" -f "#", "Name", "User", "Service", "PvD Status", "Application", "Profile", "Update"
"{0,-4} {1,-16} {2,-18} {3,-13} {4,-13} {5,-7} {6, -8} {7,-7} {8, -8}" -f "","","","","","GB", "%Used","GB", "%Used"

for($i=0; $i -lt $vms.count; $i++)
{
	$ct = $i+1
	$m = $machines[$i]
	if ($m.length -gt 16 )
	{
		$m = $m.substring(0, 16)
	}

	$u = $users[$i]
	if ($u.length -gt 18)
	{
		$u = $u.substring(0, 18)
	}

	$s = $servicestates[$i]
	$n = $nativestates[$i]
	$appf = $apppercent[$i]
	$appt = $apptotal[$i]
	$proff = $profpercent[$i]
	$proft = $proftotal[$i]
	$us= $updatestates[$i]

	if ($appf -eq "??")
	{
		$appf = ""
	}
	
	if ($appt -eq "??")
	{
		$appt = ""
	}
	else
	{
		$appt = $appt / 1073741824
	}
	
	if ($proff -eq "??")
	{
		$proff = ""
	}
	
	if ($proft -eq "??")
	{
		$proft = ""
	}
	else
	{
		$proft = $proft / 1073741824
	}

	$line="{0,-4} {1,-16} {2,-18} {3,-13} {4,-13}" -f $ct,$m,$u,$s,$n
	$line2=" {0,-7:N1} {1,-8:P}" -f $appt, $appf
	$line3=" {0,-7:N1} {1,-8:P}" -f $proft, $proff
	if( $us -eq "")
	{
		$line4=" {0, -14}" -f "-"
	}else
	{
		$line4=" {0, -14}" -f $us
	}
	if( $ok[$i] -eq $true)
	{
		Write-Host -NoNewLine -ForegroundColor Green $line
		if( $appf -gt 0.90 )
		{
			Write-Host -NoNewLine -ForegroundColor Red $line2
		}
		elseif( $appf -gt 0.50)
		{
			Write-Host -NoNewLine  -ForegroundColor Yellow $line2
		}
		elseif( $appf -eq "" )
		{
			$line2=" {0,-7} {1,-8}" -f "-", "-"	
			Write-Host -NoNewLine -ForegroundColor Green $line2
		}else
		{
			Write-Host -NoNewLine -ForegroundColor Green $line2
		}
		if( $proff -gt 0.90 )
		{
			Write-Host -NoNewLine -ForegroundColor Red $line3
		}
		elseif( $proff -gt 0.50)
		{
			Write-Host -NoNewLine  -ForegroundColor Yellow $line3
		}elseif( $proff -eq "" )
		{
			$line3=" {0,-7} {1,-8}" -f "-", "-"	
			Write-Host -NoNewLine -ForegroundColor Green $line3
		}else
		{
			Write-Host -NoNewLine -ForegroundColor Green $line3
		}
		Write-Host -ForegroundColor Green $line4
	}
	elseif( $ok[$i] -eq $false )
	{
		$skip = " {0,-7} {1,-8} {2,-7} {3,-8}" -f "-", "-", "-", "-"
		Write-Host -NoNewLine -ForegroundColor Red $line
		Write-Host -NoNewLine -ForegroundColor Red $skip
		Write-Host -ForegroundColor Red $line4
	}
	else
	{
		$skip = " {0,-7} {1,-8} {2,-7} {3,-8} {4, -14}" -f "-", "-", "-", "-", "-"
		Write-Host -NoNewLine -ForegroundColor Yellow $line
		Write-Host -ForegroundColor Yellow $skip
	}
}

Write-Host
Write-Host "DONE processing."


cd $cwd

# SIG # Begin signature block
# MIIXyAYJKoZIhvcNAQcCoIIXuTCCF7UCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUahqCih1tNf+13z93j4Unjfb
# fr+gghL2MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTISu3Zk1CbHwBV
# BXrawo0bkSyNCTANBgkqhkiG9w0BAQEFAASCAQAeur9HtyDqSBWJonK5Ca3xzdU0
# +XfnDs+POkEW8vt6tGgMohZK8ymXWdiCTqG6VE6K8hvaekBl1DcdLL4/Got6LYOD
# OrbLS86ZNXgzHCtOHFmxg7BNjoSVOCqY2bjjE4+WTnnWlhkmH417bZnIHkI1Rmgm
# Tzqeg5lh9o1+reH8AFCrHpWWnE01DZGqA+YQYpopZTjyuvHhMjtceMVFNcq+GPwE
# oxJ/R4RH3TeTNEodG6X7jyf+29jjcIqURl+oFpNV5rNCzTjiBHZS1Ce3u5NPWUsc
# MGlPmVwM7/q4tfeBjmoDL9oKZ8KhE3ZfoOm/HSmZ3id4n8VFGm6Zy/mxqRamoYIC
# CzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMCVVMxHTAb
# BgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBU
# aW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTYapgbGlAw
# CQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTE3MDQwNzA2MzcxMlowIwYJKoZIhvcNAQkEMRYEFN6HHqgcrUdmCOza
# SBzRQH/SgRtTMA0GCSqGSIb3DQEBAQUABIIBAIcKmknPCJmVg5etJYpCh+WTNVJ4
# xl1vd16K/bGvP1UFw5U/t8XDKQXW3UQ3tr9gB5HfiJuoxKDgazFCSD9sUKCgt7f4
# hYib/TMr6MylglCpaHOf9ZEvkDWM6XhWGcohNTeIYj3i2MVQ1Fl1k/bY6EhfSTMV
# dLw4eHaCnIz5I7YdyHceLc7XsOSIsxZstX0kimTWwQ5tqhtBrEbd5YlBOL08HFBp
# tPDXAeEW9JIt3DyLj+4LhB5EvRcGsOw1y03qslqBJ8PF4uYL7kYaBU/aFTg8M/Dj
# V3S9HRe2yB/rZ8fYmeUBSMSGjiR3xzAMGPCWbQCqgnddLbfqqKsZ79nCfZg=
# SIG # End signature block
