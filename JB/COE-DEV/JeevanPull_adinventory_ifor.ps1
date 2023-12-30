### this script pull then information  from all the vm's 

$ForestInfo=Get-ADForest
$Domains =$forestInfo.domains
$FileName =$ForestInfo.RootDomain+"$(get-date -Format MM-dd-yyyy)"+".csv"
$FilePath = "c:\temp"
$Daysactive = 60
$lastactive=(get-date).AddDays(-($Daysactive))
foreach($domain in $domains){
Write-Output "Working on $domain"
Get-ADComputer -Filter {OperatingSystem -like "*" -and lastlogondate -gt $lastactive -and enabled -eq $true } -Property Name,DNSHostName,OperatingSystem,OperatingSystemServicePack,IPv4Address,LastLogonDate,Modified,Description,DistinguishedName,Created -Server $domain| select Name,@{n='domainame';E={$(($_.dnshostname -split '\.(.*)',"")[1])}},DNSHostName,OperatingSystem,OperatingSystemServicePack,IPv4Address,LastLogonDate,Modified,Description,DistinguishedName,Created | Export-Csv -NoTypeInformation $FilePath\$FileName -append
}

Function Get-JeevanPullInfo {
    
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline = $True,ValueFromPipeLineByPropertyName = $True)]
        [Alias('CN','__Server','IPAddress','Server')]
        [string[]]$Computername = $Env:Computername,
        
        [parameter()]
        [Alias('RunAs')]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,       
        
        [parameter()]
        [int]$Throttle = 15
    )
    Begin {
        #Function that will be used to process runspace jobs
        Function Get-RunspaceData {
            [cmdletbinding()]
            param(
                [switch]$Wait
            )
            Do {
                $more = $false         
                Foreach($runspace in $runspaces) {
                    If ($runspace.Runspace.isCompleted) {
                        $runspace.powershell.EndInvoke($runspace.Runspace)
                        $runspace.powershell.dispose()
                        $runspace.Runspace = $null
                        $runspace.powershell = $null
                        $Script:i++                  
                    } ElseIf ($runspace.Runspace -ne $null) {
                        $more = $true
                    }
                }
                If ($more -AND $PSBoundParameters['Wait']) {
                    Start-Sleep -Milliseconds 100
                }   
                #Clean out unused runspace jobs
                $temphash = $runspaces.clone()
                $temphash | Where {
                    $_.runspace -eq $Null
                } | ForEach {
                    Write-Verbose ("Removing {0}" -f $_.computer)
                    $Runspaces.remove($_)
                }             
            } while ($more -AND $PSBoundParameters['Wait'])
        }
            
        Write-Verbose ("Performing inital Administrator check")
        $usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                   
        
        #Main collection to hold all data returned from runspace jobs
        $Script:report = @()    
        
        Write-Verbose ("Building hash table for WMI parameters")
        $WMIhash = @{
            Class = "Win32_OperatingSystem"
            ErrorAction = "Stop"
        } 
        
        #Supplied Alternate Credentials?
        If ($PSBoundParameters['Credential']) {
            $wmihash.credential = $Credential
        }
        
        #Define hash table for Get-RunspaceData function
        $runspacehash = @{}

        #Define Scriptblock for runspaces
        $scriptblock = {
                Param(
                $Computer,
                $wmihash
                    )           
            Write-Verbose ("{0}: Checking network connection" -f $Computer)
            If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                #Check if running against local system and perform necessary actions
                Write-Verbose ("Checking for local system")
                If ($Computer -eq $Env:Computername) {
                    $wmihash.remove('Credential')
                } Else {
                    $wmihash.Computername = $Computer
                }
                        $az=$false
                        Try {                       
                        $os = gwmi @wmihash
                        $OutputObj  = New-Object -Type PSObject
                        $OutputObj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $os.PScomputerName
                        $OutputObj | Add-Member -MemberType NoteProperty -Name Build -Value $os.BuildNumber
                        $az =$true                          
                        } 
                            Catch {
                            Write-Warning ("{0}: {1}" -f $Computer,$_.Exception.Message)
                            Break
                            }
                           if($az=$true){          
                            $sysinfo = Get-WmiObject Win32_computerSystem -Computername $Computer
                            $Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $Computer | Where-Object {$_.IPEnabled}| ?{$_.ServiceName -notlike "*vmnet*"}
                            $IPAddress  = $Networks.IpAddress[0]
                            $MACAddress  = $Networks.MACAddress
                            $SubnetMask  = $Networks.IPSubnet[0]
                            $DNSServers  = $Networks.DNSServerSearchOrder
                            $defaultgetway =$Networks.DefaultIPGateway -join','

                            #$driveSpace = Get-WMIObject Win32_Logicaldisk -filter "deviceid='C:'" -ComputerName $computer|Select PSComputername,DeviceID,@{Name="DriveSizeGB";Expression={$_.Size/1GB -as [int]}},@{Name="DriveFreeGB";Expression={[math]::Round($_.Freespace/1GB,2)}},@{Name="CFreePercent";Expression={[math]::Round("{0:P2}" -f ($_.FreeSpace / $_.Size))}}
                            $driveSpace = Get-WMIObject Win32_Logicaldisk -filter "deviceid='C:'" -ComputerName $computer|Select PSComputername,DeviceID,@{Name="DriveSizeGB";Expression={$_.Size/1GB -as [int]}},@{Name="DriveFreeGB";Expression={[math]::Round($_.Freespace/1GB,2)}},@{Name="CFreePercent";Expression={[int]($_.Freespace*100/$_.Size)}}
                            $totalMemory = [math]::round($sysinfo.TotalPhysicalMemory/1024/1024/1024, 2 ) 
                            $DNSSuffix =  $Networks.DNSDomainSuffixSearchOrder -join','
                            $lastBoottime = $os | select @{LABEL=’LastBootUpTime’ ;EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
                            $uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
                            $allservices = Get-WmiObject win32_service -ComputerName $computer 
                            $Build = $os.buildnumber

                            If ([int]$Build -ge '6001'){
                            $Win32User = Get-WmiObject -Class Win32_UserProfile -ComputerName $Computer
                            $Win32User = $Win32User | Where-Object {($_.SID -notmatch "^S-1-5-\d[18|19|20]$")}
                            $Win32User = $Win32User | Sort-Object -Property LastUseTime -Descending
                            $LastUsers = $Win32User | Select-Object -First 3

                            foreach($LastUser in $LastUsers){
                            $Loaded = $LastUser.Loaded
                            $Time = ([WMI] '').ConvertToDateTime($LastUser.LastUseTime)
                            $UserSID = New-Object System.Security.Principal.SecurityIdentifier($LastUser.SID)
                            $User = $UserSID.Translate([System.Security.Principal.NTAccount])
                            $rest = ""|select Username,LastLogonTime,Loaded
                            $rest.Username = $($User.Value)
                            $rest.LastLogonTime = $time
                            $rest.Loaded = $Loaded
                            $info +=$rest
                            }
                        }


                            $OutputObj | Add-Member -MemberType NoteProperty -Name Domain -Value $sysinfo.Domain
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Model -Value $sysinfo.Model
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Operating_System -Value $OS.Caption
                            $OutputObj | Add-Member -MemberType NoteProperty -Name OSVersion -Value $OS.version
                            $OutputObj | Add-Member -MemberType NoteProperty -Name NetworkAdapter -Value $Networks.Description
                            $OutputObj | Add-Member -MemberType NoteProperty -Name IP_Address -Value $IPAddress
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Subnet -Value $SubnetMask
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Primary_DNS -Value $DNSServers[0]
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Secondary_DNS -Value $DNSServers[1]
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Teritiary_DNS -Value $DNSServers[2]
                            $OutputObj | Add-Member -MemberType NoteProperty -Name Default_Gateway -Value $defaultgetway
                            $OutputObj | Add-Member -MemberType NoteProperty -Name C_driveFree_GB -Value $driveSpace.DrivefreeGB
                            $OutputObj | Add-Member -MemberType NoteProperty -Name C_size_GB -Value $driveSpace.DriveSizeGB
                            $OutputObj | Add-Member -MemberType NoteProperty -Name C_FreePercent -Value $driveSpace.CFreePercent
                            $OutputObj | Add-Member -MemberType NoteProperty -Name RAM_GB -Value $totalMemory
                            $OutputObj | Add-Member -MemberType NoteProperty -Name DNS_Suffix -Value $DNSSuffix
                            $outputobj | Add-Member -MemberType NoteProperty -Name Up_time -Value "$($uptime.Days + " Days " + $uptime.Hours + " Hours " + $uptime.Minutes + " Minutes")"
                            #$outputobj | Add-Member -MemberType NoteProperty -Name Up_time -Value "$("Uptime   : " + $uptime.Days + " Days " + $uptime.Hours + " Hours " + $uptime.Minutes + " Minutes")"
                            #$outputobj | Add-Member -MemberType NoteProperty -Name 'McAfee Services' -Value $(if($allservices | ? {$_.Name -like "masv*"}){$mt = $_.state}else{$mt ='Service Not installed'};$mt)
                            $outputobj | Add-Member -MemberType NoteProperty -Name 'McAfee Services' -Value $(if($ms = $allservices |? {$_.name -like "*Masv*"} |select -ExpandProperty State){$ms}else{'Service Not Installed'})
                            $outputobj | Add-Member -MemberType NoteProperty -Name 'BigFix Services' -Value $(if($ms = $allservices |? {$_.name -like "*BES*"} |select -ExpandProperty State){$ms}else{'Service Not Installed'})
                            $outputobj | Add-Member -MemberType NoteProperty -Name 'SCCM' -Value $(if($ms = $allservices |? {$_.name -like "*CCM*"} |select -ExpandProperty State){$ms}else{'Service Not Installed'})
                            $outputobj | Add-Member -MemberType NoteProperty -Name 'Splunk' -Value $(if($ms = $allservices |? {$_.name -like "*splunk*"} |select -ExpandProperty State){$ms}else{'Service Not Installed'})    
                            #$outputobj | Add-Member -MemberType NoteProperty -Name 'BigFix Services' -Value $(if($allservices | ? {$_.Name -like "BESClient"}){$mt = $_.state}else{$mt ='Service Not installed'};$mt)
                            #$outputobj | Add-Member -MemberType NoteProperty -Name 'SCCM_Services' -Value $(if($allservices | ? {$_.Name -like "CcmEx*"}){$mt = $_.state}else{$mt ='Service Not installed'};$mt)
                            #$outputobj | Add-Member -MemberType NoteProperty -Name 'Splunk_Services' -Value $(if($allservices | ? {$_.Name -like "*Splu*"}){$mt = $_.state}else{$mt ='Service Not installed'};$mt)
                            $outputobj | Add-Member -MemberType NoteProperty -Name LastLogonUser1_UserName -Value $($info |select -First 1 |select -ExpandProperty Username)
                            $outputobj | Add-Member -MemberType NoteProperty -Name LastLogonUser1_time -Value $($info |select -First 1|select -ExpandProperty lastlogonTime)
                            $outputobj | Add-Member -MemberType NoteProperty -Name LastLogonUser1_Loaded -Value $($info |select -First 1|select -ExpandProperty loaded)
                            $outputobj | Add-Member -MemberType NoteProperty -Name LastLogonUser2_UserName -Value $($info |select -Last 1 |select -ExpandProperty Username)
                            $outputobj | Add-Member -MemberType NoteProperty -Name LastLogonUser2_time -Value $($info |select -Last 1|select -ExpandProperty lastlogonTime)
                            $outputobj | Add-Member -MemberType NoteProperty -Name LastLogonUser2_Loaded -Value $($info |select -Last 1|select -ExpandProperty loaded)
                            $OutputObj
                            }

            } Else {
                Write-Warning ("{0}: Unavailable!" -f $Computer)
                Break
            }        
        }
        
        Write-Verbose ("Creating runspace pool and session states")
        $sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
        $runspacepool.Open()  
        
        Write-Verbose ("Creating empty collection to hold runspace jobs")
        $Script:runspaces = New-Object System.Collections.ArrayList        
    }
    Process {        
        $totalcount = $computername.count
        Write-Verbose ("Validating that current user is Administrator or supplied alternate credentials")        
        If (-Not ($Computername.count -eq 1 -AND $Computername[0] -eq $Env:Computername)) {
            #Now check that user is either an Administrator or supplied Alternate Credentials
            If (-Not ($IsAdmin -OR $PSBoundParameters['Credential'])) {
                Write-Warning ("You must be an Administrator to perform this action against remote systems!")
                Break
            }
        }
        ForEach ($Computer in $Computername) {
           #Create the powershell instance and supply the scriptblock with the other parameters 
           $powershell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($computer).AddArgument($wmihash)
           
           #Add the runspace into the powershell instance
           $powershell.RunspacePool = $runspacepool
           
           #Create a temporary collection for each runspace
           $temp = "" | Select-Object PowerShell,Runspace,Computer
           $Temp.Computer = $Computer
           $temp.PowerShell = $powershell
           
           #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
           $temp.Runspace = $powershell.BeginInvoke()
           Write-Verbose ("Adding {0} collection" -f $temp.Computer)
           $runspaces.Add($temp) | Out-Null
           
           Write-Verbose ("Checking status of runspace jobs")
           Get-RunspaceData @runspacehash
        }                        
    }
    End{                     
        Write-Verbose ("Finish processing the remaining runspace jobs: {0}" -f (@(($runspaces | Where {$_.Runspace -ne $Null}).Count)))
        $runspacehash.Wait = $true
        Get-RunspaceData @runspacehash
        
        Write-Verbose ("Closing the runspace pool")
        $runspacepool.close()               
        }
}
<#
$infor =@()
$dircred= Get-Credential -UserName "dev-dir\jbobba" -Message "dircred"
$entcred= Get-Credential -UserName "dev-ent\z-bobba-jeevan" -Message "entcred"
$oasamcred = Get-Credential -UserName "dev-oasam\z-bobba-jeevan" -Message "oasamcred"

$servers = Import-Csv c:\temp\$filename
$dirservers = $servers|?{$_.domainame -eq "Test-Dir.Labor.Gov"}|select -ExpandProperty IPv4Address
$Entservers = $servers|?{$_.domainame -eq "test-ent.test-dir.labor.gov"}|select -ExpandProperty IPv4Address
$oasamservers = $servers|?{$_.domainame -eq "test-oasam.test-dir.labor.gov"}|select -ExpandProperty IPv4Address
$restservers =  $servers|?{$_.domainame -ne "test-oasam.test-dir.labor.gov" -and $_.domainame -ne "test-ent.test-dir.labor.gov"}|select -ExpandProperty IPv4Address


$infor += $dirservers |Get-JeevanPullInfo -Credential $dircred
$infor += $Entservers |Get-JeevanPullInfo -Credential $entcred
$infor += $oasamservers |Get-JeevanPullInfo -Credential $oasamcred
$infor += $restservers |Get-JeevanPullInfo -Credential $dircred
$infor| Export-Csv c:\temp\inventoryjbservers.csv -NoTypeInformation
#>
$ssservers =Import-Csv c:\temp\$filename|select -ExpandProperty IPv4Address
$ssservers|Get-JeevanPullInfo |Export-Csv c:\temp\allservers.csv -NoTypeInformation