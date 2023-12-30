#Requires -RunAsAdministrator
function Install-Agent
{
	param
	(
		[Parameter(Mandatory = $True, ValueFromPipeline = $True,
				   ValueFromPipelinebyPropertyName = $true)]
		$AgentName,
		$AgentServiceNames,
		$Arguments,
		$AgentPath,
		$LogDirectory,
		$installedversions,
		$AgentVersion,
		$sleepseconds = 0
	)
	begin
	{
		$runningagent = Get-Service $AgentServiceNames -ErrorAction SilentlyContinue
	}
	process
	{
		if ($runningagent -and $([system.version]($installedversions -match $AgentName).Version -ge $AgentVersion))
		{
			Write-Output "The Agent  $agentName Already is the Latest Version - $AgentVersion..Skipping $AgentName Install"
		}
		else
		{
			Write-Output "Installing Agent - $AgentName"
			if ($AgentPath -match ".msi$")
			{
				$params = "/i" + " " + $AgentPath + " " + $Arguments
				$status = (start-process -FilePath msiexec.exe -ArgumentList $params -Wait).waitforexit
			}
			else
			{
				$status = start-process $AgentPath -ArgumentList $Arguments -Wait -NoNewWindow
			}
			Write-Output "Completed Installing Agent- $AgentName"
			Start-Sleep -Seconds $sleepseconds
			if ($status) { $status | Add-Content "$LogDirectory\$AgentName-Issues.txt" }
		}
	}
	end
	{
		
	}
}
function Verify-Agents
{
	param
	(
		[Parameter(Mandatory = $True, ValueFromPipeline = $True,
				   ValueFromPipelinebyPropertyName = $true)]
		$Services
	)
	$InstallInfo = Get-CimInstance -Class Win32_Product | Where-Object{ $psitem.Name -match 'bigfix client|Configuration Manager Client|UniversalForwarder|Microsoft Monitoring Agent|RSA Authentication Agent|Solarwinds' } | Select-Object Name, Version
	$ATP = Get-CimInstance -Class MSFT_MpComputerStatus -Namespace "root\microsoft\windows\defender" -ErrorAction SilentlyContinue | Select-Object AMProductVersion, AntivirusSignatureVersion, AntivirusSignatureLastUpdated, AMRunningMode, AMServiceEnabled, AntivirusEnabled
	$report = new-object System.Collections.ArrayList
	foreach ($service in $services)
	{
		$SStatus = Get-Service -Name $service -ErrorVariable NotFound -ErrorAction SilentlyContinue
		if ($notfound) { $Status = "Not Installed" }
		else { $Status = $SStatus.Status }
		switch ($service)
		{
			'SplunkForwarder'{
				$Name = "UniversalForwarder"
				$ApplicationName = "Splunk Agent"
			}
			"SENSE"{
				$Name = "MDE/ATP"
				$ApplicationName = "ATP Agent"
			}
			"WINDEFEND"{
				$Name = "MDE"
				$ApplicationName = "MDE Status"
			}
			'BESClient'{
				$Name = "IBM BigFix Client"
				$ApplicationName = "BigFix Agent"
			}
			'CCMEXEC'{
				$Name = "Configuration Manager Client"
				$ApplicationName = "SCCM Agent"
			}
			'HealthService'{
				$Name = "Microsoft Monitoring Agent"
				$ApplicationName = "SCOM Agent"
			}
			'RSA SecurID PIN Unlock Service'{
				$Name = "RSA Authentication Agent"
				$ApplicationName = "RSA Agent"
			}
			'SolarwindsAgent64'{
				$Name = "SolarWinds Agent 2.0.70.0"
				$ApplicationName = "Solarwinds Agent"
			}
		}
		if ($service -notmatch 'SENSE|WINDEFEND')
		{
			$r = [pscustomobject]@{
				'Agent/Client' = $ApplicationName
				Status		   = $Status
				Version	       = ($InstallInfo | Where-Object{ $PSItem.Name -eq $Name }).Version
			}
		}
		else
		{
			$r = [pscustomobject]@{
				'Agent/Client' = $ApplicationName
				Status		   = $Status
				Version	       = "See Additional Table"
			}
		}
		$report.add($r) | Out-Null
	}
	$report
	if ($ATP)
	{
		Write-Output "`n`n`n`r`r ATP Additional Information"
		$ATP | Format-Table -AutoSize
	}
	else
	{
		Write-Output "`n`n`n`r`r ATP and MDE Not Enabled"
	}
}
#Get Domain Name
$starttime = get-date
$ErrorActionPreference = 'SilentlyContinue'
$domainName = (([System.Net.Dns]::GetHostByName($env:computerName)).HostName -split "\.")[1 .. 5] -join "."
if ($domainName -match "DEV-") { $COEENV = "COE-DEV" }
if ($domainName -match "TEST-") { $COEENV = "COE-TEST" }
if ($domainName -match "STAGE-") { $COEENV = "COE-STAGE" }
if ($domainName -like "*.dir.labor.gov") { $COEENV = "COE-Prod" }
if ((Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain -eq $false) { $COEENV = "DMZ" }
$agentspath = "C:\temp\Agents"
$logpath = "c:\temp\agentlogs"
$DMZSource = "C:\temp\Agents"
if (!(Test-Path $agentspath)) { New-Item -ItemType Directory -Path $agentspath -Force | Out-Null }
if (!(Test-Path $logpath)) { New-Item -ItemType Directory -Path $logpath -Force | Out-Null }
Write-Output  "Starting the Client Agents Install - Press Press CTRL + C to Cancel the Client Agents Installation"
Write-Output "Copying Agents from DFS Share for $COEENV Environment .. This Script will Install all the Required Agents"
if ($COEENV -ne 'DMZ') { robocopy "\\$domainName\itos\Agents"  C:\Temp\Agents /MT:128 /e /j /zb /ns /nc /nfl /ndl /np /njh /njs }
New-Item -ItemType Directory -Path $logpath -Force | Out-Null
##Client Verisions,Paths and Args
#RSA
$RSAVersion = [system.version]"7.4.5"
$RSAPath = (Get-ChildItem "$agentspath\Prod\RSA" -filter "*.msi").FullName
$RSAProdArgs = "/qn /norestart"
$RSAProdUpgradeArgs = "/quiet /norestart REINSTALL=ALL REINSTALLMODE=vomus"
#$RSAInstallCert = (Get-ChildItem "$agentspath\Prod\RSA" -filter "*.cer").FullName
#Splunk
$SplunkVersion = [system.version]"8.2.4"
$splunkpath = (Get-ChildItem "$agentspath\Shared\SplunkFwd" -filter "*.msi").FullName
$splunkProdArgs = 'DEPLOYMENT_SERVER="10.48.44.42:8089" AGREETOLICENSE=yes /quiet'
$SplunkNPVersion = [system.version]"9.0.0"
$splunkNpath = (Get-ChildItem "$agentspath\Shared\SplunkFwdNP" -filter "*.msi").FullName
$splunkNProdArgs = 'DEPLOYMENT_SERVER="10.50.12.91:8089" AGREETOLICENSE=yes /quiet'
#BigFix
$BigFixVersion = [System.Version]"9.5.12.68"
$BigFixPath = (Get-ChildItem "$agentspath\Prod\BigFix" -filter "BigFixAgent.msi").FullName
$BigFixArgs = '/qn'
$BigFixDPath = (Get-ChildItem "$agentspath\Dev\Bigfix_Dev_Installer\Dev_Installer" -Filter "setup.exe").FullName
$BigFixTPath = (Get-ChildItem "$agentspath\Test\Bigfix_Test_Installer\Test_Installer" -Filter "setup.exe").FullName
$BigFixSPath = (Get-ChildItem "$agentspath\Stage\Bigfix_Stage_Installer\Stage_Installer" -Filter "setup.exe").FullName
$BigFixNPArgs = '/s /v/qn'
#SCCM
$SCCMVersion = [System.Version]"5.00.9068.1000"
$SCCMPath = (Get-ChildItem "$agentspath\Shared\SCCM" -Filter "ccmsetup.exe").FullName
$SCCMProdArgs = 'SMSSITECODE=P12 SMSMP=CM12PS01 SMSSLP=CM12PS01 FSP=CM12SUP01 RESETKEYINFORMATION=TRUE DNSSUFFIX=OASAM.DIR.LABOR.GOV'
$SCCMDevArgs = 'SMSSITECODE=D12 SMSMP=DEVCMPS12 FSP=DEVCMSUP RESETKEYINFORMATION=TRUE DNSSUFFIX=DEV-OASAM.DEV-DIR.LABOR.GOV'
$SCCMTestArgs = 'SMSSITECODE=TPS SMSMP=TESTCMPS01 SMSSLP=TESTCMPS01 FSP=TESTCMDP01 RESETKEYINFORMATION=TRUE DNSSUFFIX=Test-ENT.Test-Dir.Labor.Gov'
#SCOM
$SCOMVersion = [System.Version]"10.19.10014.0"
$SCOMPath = (Get-ChildItem "$agentspath\Shared\OpsMgrAgent2019\amd64" -Filter "MOMAgent.msi").FullName
$SCOMPatches = (Get-ChildItem "$agentspath\Shared\OpsMgrAgent2019\patches" -Filter "KB*.msp" | sort -Property LastWriteTime).FullName
$SCOMProdArgs = '/qn USE_SETTINGS_FROM_AD=0 USE_MANUALLY_SPECIFIED_SETTINGS=1 MANAGEMENT_GROUP=OCIO_OpsMgr_1801 MANAGEMENT_SERVER_DNS=mgtomms04.ent.dir.labor.gov MANAGEMENT_SERVER_AD_NAME=mgtomms04.ent.dir.labor.gov ACTIONS_USE_COMPUTER_ACCOUNT=1 AcceptEndUserLicenseAgreement=1'
$SCOMTestArgs = '/qn USE_SETTINGS_FROM_AD=0 USE_MANUALLY_SPECIFIED_SETTINGS=1 MANAGEMENT_GROUP=TEST_OM_1801 MANAGEMENT_SERVER_DNS=TESTOMMS04.Test-Ent.Test-Dir.Labor.Gov MANAGEMENT_SERVER_AD_NAME=TESTOMMS04.Test-Ent.Test-Dir.Labor.Gov ACTIONS_USE_COMPUTER_ACCOUNT=1 AcceptEndUserLicenseAgreement=1'
#ATP
$ATPScript = (Get-ChildItem "$agentspath\Shared\ATP" -Filter "DefenderATPOnboarding.cmd").FullName
$ATPUP1 = (Get-ChildItem "$agentspath\Shared\ATP" -Filter "*updateplatform*").FullName
$ATPUp2 = (Get-ChildItem "$agentspath\Shared\ATP" -Filter "MPAM_FE.EXE").FullName
#SolarWinds
$SolarwindsVersion = [system.version]"2.0.70.0"
$SolarWindsPath = (Get-ChildItem "$agentspath\Shared\SolarWindsAgent" -Filter "SolarWinds-Agent.msi").FullName
$solarwindsArgs = '/qn'
#HostsFile
$nonprodHostsfile = (get-content $((Get-ChildItem "$agentspath\Shared\SCCM" -Filter "sccm and scom hosts.txt").FullName)).trim() | ?{ $PSItem -notmatch "^#" } | ? { $_.trim() -ne "" }
#$cert = New-SelfSignedCertificate -NotAfter (Get-Date).AddYears(5) -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2,1.3.6.1.5.5.7.3.1") -KeyExportPolicy Exportable -FriendlyName "SCOMCertificate" -DnsName "$env:COMPUTERNAME" -KeyLength 4096
#$pwd = ConvertTo-SecureString -String 'passw0rd!' -Force -AsPlainText
#$path = 'cert:\localMachine\my\' + $cert.thumbprint
#$filepath = 'c:\temp\cert.pfx'
#Export-PfxCertificate -cert $path -FilePath $filepath -Password $pwd
#Import-PfxCertificate -FilePath $filepath -CertStoreLocation Cert:\LocalMachine\Root\ -Password 'passw0rd!'
#MOMCertImport.exe $filepath /Password 'passw0rd!'
#Remove EPO Products McAfeeEndpointProductRemoval_21.8.0.99.exe --accepteula --all --noreboot
switch ($COEENV)
{
	'COE-Prod' {
		#Import-Certificate $RSAInstallCert -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
		Write-Output "Starting $COEENV -Agent Installs"
		$services = "RSA SecurID PIN Unlock Service", "SplunkForwarder", "BESClient", "ccmexec", "HealthService", "SENSE", "WINDEFEND"
		$installedversions = Verify-Agents -Services $services
		"#####################################################################`n#####################################################################`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Started Installation on $starttime" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"Versions Before Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$installedversions | out-file "$logpath\AgentInstallationSummary.txt" -Encoding ascii -Append
		if ([system.version]($installedversions -match "RSA").Version -eq $null) { $RSAProdArgs = $RSAProdArgs }
		else { $RSAProdArgs = $RSAProdUpgradeArgs }
		Install-Agent -AgentName 'RSA' -AgentServiceNames 'RSA SecurID PIN Unlock Service' -Arguments $RSAProdArgs -AgentPath $RSAPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $RSAVersion
		Install-Agent -AgentName 'Splunk' -AgentServiceNames 'SplunkForwarder' -Arguments $splunkProdArgs -AgentPath $splunkpath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SplunkVersion
		& $ATPScript
		start-process $ATPUP1 -NoNewWindow -Wait
		start-process $ATPUP2 -NoNewWindow -Wait
		Update-MpSignature -UpdateSource MicrosoftUpdateServer -asjob | Out-Null
		Install-Agent -AgentName 'BigFix' -AgentServiceNames 'BESClient' -Arguments $BigFixArgs -AgentPath $BigFixPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $BigFixVersion
		Install-Agent -AgentName 'SCCM' -AgentServiceNames 'ccmexec' -Arguments $SCCMProdArgs -AgentPath $SCCMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCCMVersion -sleepseconds 240
		Install-Agent -AgentName 'SCOM' -AgentServiceNames 'HealthService' -Arguments $SCOMProdArgs -AgentPath $SCOMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCOMVersion -sleepseconds 300
		$SCOMPatches | %{ Start-Process -FilePath msiexec.exe -ArgumentList "/update $PSItem /qn" -Wait -NoNewWindow }
		$finalversions = Verify-Agents -Services $services
		#$finalversions
		"Versions After Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$finalversions | Out-file "$logpath\AgentInstallationSummary.txt" -Append -Encoding ascii
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Completed Agent Installation on $(Get-date)" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"#####################################################################`n#####################################################################`r`n`n`n" | Add-Content "$logpath\AgentInstallationSummary.txt"
		Remove-Item -Recurse -Force -Path $agentspath | Out-Null
		start-process -FilePath "notepad.exe" -ArgumentList "$logpath\AgentInstallationSummary.txt"
		#Remove-Item -Recurse -Force -Path $logpath | Out-Null
	}
	'COE-DEV' {
		Write-Output "Starting $COEENV -Agent Installs"
		$services = "SplunkForwarder", "BESClient", "ccmexec", "SENSE", "WINDEFEND"
		$installedversions = Verify-Agents -Services $services
		"#####################################################################`n#####################################################################`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Started Installation on $starttime" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"Versions Before Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$installedversions | out-file "$logpath\AgentInstallationSummary.txt" -Encoding ascii -Append
		Install-Agent -AgentName 'Splunk' -AgentServiceNames 'SplunkForwarder' -Arguments $splunkNProdArgs -AgentPath $splunkNpath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SplunkNPVersion
		& $ATPScript
		start-process $ATPUP1 -NoNewWindow -Wait
		start-process $ATPUP2 -NoNewWindow -Wait
		Update-MpSignature -UpdateSource MicrosoftUpdateServer -asjob | Out-Null
		Install-Agent -AgentName 'BigFix' -AgentServiceNames 'BESClient' -Arguments $BigFixNPArgs -AgentPath $BigFixDPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $BigFixVersion
		$nonprodHostsfile | %{ Add-Content C:\Windows\System32\drivers\etc\hosts -Value $PSItem -PassThru; Start-Sleep -Seconds 1 }
		Install-Agent -AgentName 'SCCM' -AgentServiceNames 'ccmexec' -Arguments $SCCMDevArgs -AgentPath $SCCMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCCMVersion -sleepseconds 240
		$finalversions = Verify-Agents -Services $services
		#$finalversions
		"#####################################################################`n#####################################################################`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Started Installation on $starttime" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"Versions Before Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$installedversions | out-file "$logpath\AgentInstallationSummary.txt" -Encoding ascii -Append
		"Versions After Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$finalversions | Out-file "$logpath\AgentInstallationSummary.txt" -Append -Encoding ascii
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Completed Agent Installation on $(Get-date)" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"#####################################################################`n#####################################################################`r`n`n`n" | Add-Content "$logpath\AgentInstallationSummary.txt"
		Remove-Item -Recurse -Force -Path $agentspath | Out-Null
		start-process -FilePath "notepad.exe" -ArgumentList "$logpath\AgentInstallationSummary.txt"
		#Remove-Item -Recurse -Force -Path $logpath | Out-Null
	}
	'COE-TEST' {
		Write-Output "Starting $COEENV -Agent Installs"
		$services = "SplunkForwarder", "BESClient", "ccmexec", "HealthService", "SENSE", "WINDEFEND"
		$installedversions = Verify-Agents -Services $services
		"#####################################################################`n#####################################################################`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Started Installation on $starttime" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"Versions Before Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$installedversions | out-file "$logpath\AgentInstallationSummary.txt" -Encoding ascii -Append
		Install-Agent -AgentName 'Splunk' -AgentServiceNames 'SplunkForwarder' -Arguments $splunkNProdArgs -AgentPath $splunkNpath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SplunkNPVersion
		& $ATPScript
		start-process $ATPUP1 -NoNewWindow -Wait
		start-process $ATPUP2 -NoNewWindow -Wait
		Update-MpSignature -UpdateSource MicrosoftUpdateServer -asjob | Out-Null
		$nonprodHostsfile | %{ Add-Content C:\Windows\System32\drivers\etc\hosts -Value $PSItem -PassThru; Start-Sleep -Seconds 1 }
		Install-Agent -AgentName 'BigFix' -AgentServiceNames 'BESClient' -Arguments $BigFixNPArgs -AgentPath $BigFixTPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $BigFixVersion
		Install-Agent -AgentName 'SCCM' -AgentServiceNames 'ccmexec' -Arguments $SCCMTestArgs -AgentPath $SCCMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCCMVersion -sleepseconds 240
		Install-Agent -AgentName 'SCOM' -AgentServiceNames 'HealthService' -Arguments $SCOMTestArgs -AgentPath $SCOMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCOMVersion -sleepseconds 300
		$SCOMPatches | %{ Start-Process -FilePath msiexec.exe -ArgumentList "/update $PSItem /qn" -Wait -NoNewWindow }
		$finalversions = Verify-Agents -Services $services
		#$finalversions
		"Versions After Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$finalversions | Out-file "$logpath\AgentInstallationSummary.txt" -Append -Encoding ascii
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Completed Agent Installation on $(Get-date)" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"#####################################################################`n#####################################################################`r`n`n`n" | Add-Content "$logpath\AgentInstallationSummary.txt"
		start-process -FilePath "notepad.exe" -ArgumentList "$logpath\AgentInstallationSummary.txt"
		Remove-Item -Recurse -Force -Path $agentspath | Out-Null
		#Remove-Item -Recurse -Force -Path $logpath | Out-Null
	}
	'COE-STAGE' {
		Write-Output "Starting $COEENV -Agent Installs"
		$services = "SplunkForwarder", "BESClient", "ccmexec", "HealthService", "SENSE", "WINDEFEND"
		$installedversions = Verify-Agents -Services $services
		"#####################################################################`n#####################################################################`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Started Installation on $starttime" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"Versions Before Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$installedversions | out-file "$logpath\AgentInstallationSummary.txt" -Encoding ascii -Append
		Install-Agent -AgentName 'Splunk' -AgentServiceNames 'SplunkForwarder' -Arguments $splunkNProdArgs -AgentPath $splunkNpath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SplunkNPVersion
		& $ATPScript
		start-process $ATPUP1 -NoNewWindow -Wait
		start-process $ATPUP2 -NoNewWindow -Wait
		Update-MpSignature -UpdateSource MicrosoftUpdateServer -asjob | Out-Null
		Install-Agent -AgentName 'BigFix' -AgentServiceNames 'BESClient' -Arguments $BigFixNPArgs -AgentPath $BigFixSPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $BigFixVersion
		$nonprodHostsfile | %{ Add-Content C:\Windows\System32\drivers\etc\hosts -Value $PSItem -PassThru; Start-Sleep -Seconds 1 }
		Install-Agent -AgentName 'SCCM' -AgentServiceNames 'ccmexec' -Arguments $SCCMProdArgs -AgentPath $SCCMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCCMVersion -sleepseconds 240
		Install-Agent -AgentName 'SCOM' -AgentServiceNames 'HealthService' -Arguments $SCOMProdArgs -AgentPath $SCOMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCOMVersion -sleepseconds 300
		$SCOMPatches | %{ Start-Process -FilePath msiexec.exe -ArgumentList "/update $PSItem /qn" -Wait -NoNewWindow }
		$finalversions = Verify-Agents -Services $services
		#$finalversions
		"Versions After Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$finalversions | Out-file "$logpath\AgentInstallationSummary.txt" -Append -Encoding ascii
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Completed Agent Installation on $(Get-date)" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"#####################################################################`n#####################################################################`r`n`n`n" | Add-Content "$logpath\AgentInstallationSummary.txt"
		start-process -FilePath "notepad.exe" -ArgumentList "$logpath\AgentInstallationSummary.txt"
		Remove-Item -Recurse -Force -Path $agentspath | Out-Null
		#Remove-Item -Recurse -Force -Path $logpath | Out-Null
	}
	'DMZ' {
		Write-Output "Starting $COEENV -Agent Installs"
		$services = "SplunkForwarder", "SolarWindsAgent64", "BESClient", "ccmexec", "HealthService", "SENSE", "WINDEFEND"
		$installedversions = Verify-Agents -Services $services
		"#####################################################################`n#####################################################################`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Started Installation on $starttime" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"Versions Before Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$installedversions | out-file "$logpath\AgentInstallationSummary.txt" -Encoding ascii -Append
		Install-Agent -AgentName 'Splunk' -AgentServiceNames 'SplunkForwarder' -Arguments $splunkProdArgs -AgentPath $splunkpath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SplunkVersion
		& $ATPScript
		start-process $ATPUP1 -NoNewWindow -Wait
		start-process $ATPUP2 -NoNewWindow -Wait
		Update-MpSignature -UpdateSource MicrosoftUpdateServer -asjob | Out-Null
		Install-Agent -AgentName 'SolarWinds' -AgentServiceNames 'SolarWindsAgent64' -Arguments $SolarWindsArgs -AgentPath $SolarWindsPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SolarwindsVersion
		Install-Agent -AgentName 'BigFix' -AgentServiceNames 'BESClient' -Arguments $BigFixArgs -AgentPath $BigFixPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $BigFixVersion
		$nonprodHostsfile | %{ Add-Content C:\Windows\System32\drivers\etc\hosts -Value $PSItem -PassThru; Start-Sleep -Seconds 1 }
		Install-Agent -AgentName 'SCCM' -AgentServiceNames 'ccmexec' -Arguments $SCCMProdArgs -AgentPath $SCCMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCCMVersion -sleepseconds 240
		Install-Agent -AgentName 'SCOM' -AgentServiceNames 'HealthService' -Arguments $SCOMProdArgs -AgentPath $SCOMPath -LogDirectory $logpath -installedversions $installedversions -AgentVersion $SCOMVersion -sleepseconds 300
		$SCOMPatches | %{ Start-Process -FilePath msiexec.exe -ArgumentList "/update $PSItem /qn" -Wait -NoNewWindow }
		$finalversions = Verify-Agents -Services $services
		#$finalversions
		"Versions After Running `n`r" | Add-Content "$logpath\AgentInstallationSummary.txt"
		$finalversions | Out-file "$logpath\AgentInstallationSummary.txt" -Append -Encoding ascii
		"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)  Completed Agent Installation on $(Get-date)" | Add-Content "$logpath\AgentInstallationSummary.txt"
		"#####################################################################`n#####################################################################`r`n`n`n" | Add-Content "$logpath\AgentInstallationSummary.txt"
		start-process -FilePath "notepad.exe" -ArgumentList "$logpath\AgentInstallationSummary.txt"
		Remove-Item -Recurse -Force -Path $agentspath | Out-Null
		#Remove-Item -Recurse -Force -Path $logpath | Out-Null
	}
}
