# .SYNOPSIS
#  Set up persistent collection of Citrix trace messages into a cyclic buffer
#
# .DESCRIPTION
#  The New-XdLogTrace script uses the built in 'logman' tool to configure
#  a collection of trace messages emitted by Citrix components (CDF traces)
#  to a cyclic buffer with a specified maximum buffer size. All installed
#  CDF traces are captured by default, with the exception of some specified
#  CDF module name patterns. The tracing job will persist even after reboots and
#  continue to capture logs, though logs from before the reboot will be
#  overwritten. Compatible with PowerShell 2.0 and up.
#
# .PARAMETER FileName
#  The name and path of the circular buffer in which to collect the trace data.
#  This defaults to 'C:\logs\XdLogs.etl'. The directory will be created if it does
#  not exist. If the file already exists, it will be overwritten. Note, however,
#  that if this file is currently in use by an existing log job other than the one
#  specified with -Name, the command will fail. 
#
# .PARAMETER LogLevel
#  Defines what verbose level is the threshold to be used for collecting or
#  discarding the tracing messages. Traces generated at a log level higher than
#  this are discarded, whereas traces at or below this level are collected. This
#  defaults to 5 (verbose).
#
# .PARAMETER MaxSizeMB
#  The maximum size, in megabytes, allowed for the circular buffer file. This
#  defaults to 100.
#
# .PARAMETER Name
#  The name of the persistent trace job that will be set up to capture the traces.
#  This name will appear in windows control panels etc. This defaults to
#  'XenDesktopLog'.
#
# .PARAMETER Whitelist
#  A list of patterns to match against the names of CDF modules. Traces from 
#  CDF modules whose names match any of these patterns will be included in the
#  trace collection unless the module is excluded via the blacklist. This
#  defaults to a single entry list '*'.
#
# .PARAMETER Blacklist
#  A list of patterns to match against the names of CDF moudules. Traces from 
#  CDF modules whose names match any of these patterns will be excluded in the
#  trace collection. Wildcards may be used. 
#  This defaults to the list '*ServiceDAL','*ServiceFiltering','*ServiceTracking'.
#
# .PARAMETER CtlLocations
#  A list of locations for CTL files, which specify additional traceable Citrix
#  modules not listed in the registry. This defaults to the single-item list
#  'C:\Program Files (x86)\Citrix\ICA Client\IcaClientTraceProviders.ctl'. You
#  could also use the CDFControl tool to manually pick out modules and export a
#  CTL file for this script to use.
#
# .PARAMETER PreserveOldLogs
#  A switch that causes logs collected from any currently set up trace capture to
#  be preserved, rather than the default action of being deleted.
#
# .PARAMETER Stop
#  A switch that causes the named log collection to be stopped and the persistent
#  job to be deleted. No further processing or log job creation will take place.
#
# .PARAMETER Help
#  A switch that causes the basic help for the script to be displayed.
#
# .PARAMETER ShowParams
#  A switch that causes the script to output the values that it is using, some
#  of which may be defaults or may have been overridden.
#
# .PARAMETER UseCtlOnly
#  A switch that causes modules to only be loaded from the specified CTL file(s),
#  without looking in the registry.

# Copyright 2014 Citrix Systems, Inc.  All Rights Reserved.
# Version: 1.9

[CmdletBinding()]
param(
    [string]    $fileName = 'C:\logs\XdLogs.etl',
    [int]       $logLevel = 5,
    [int]       $maxSizeMb = 100,
    [string]    $name = 'XenDesktopLog',
    [String[]]  $whitelist = @('*' ),
    [String[]]  $blacklist = @('*ServiceDAL','*ServiceFiltering','*ServiceTracking' ),
    [String[]]  $ctlLocations = @('C:\Program Files (x86)\Citrix\ICA Client\IcaClientTraceProviders.ctl'),
    [switch]    $preserveOldLogs,
    [switch]    $stop,
    [switch]    $help,
    [switch]    $showParams,
    [switch]    $useCtlOnly
    )

# Check the script is being run with elevated privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole( [Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $isAdmin)
{
    Write-Error "You must run this script as an Administrator."
    return
}

if ($help)
{
    Get-Help($MyInvocation.MyCommand.Path) -detailed
    return
}

if ($showParams)
{
    Write-Host "FileName $fileName"
    Write-Host "LogLevel $logLevel"
    Write-Host "MaxSizeMB $maxSizeMb"
    Write-Host "Name $name"
    Write-Host "BlackList $blackList"
    Write-Host "Whitelist $whitelist"
    Write-Host "CtlLocations $ctlLocations"
    Write-Host "PreserveOldLogs $preserveOldLogs"
}

# Get full filepath in case a relative path has been specified (unlike
# Resolve-Path, the following works even if the file doesn't exist yet)
$fileName = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($fileName)
Write-Verbose "Interpreting FileName as '$fileName'"

# Assume we don't need to set permissions on the directory
$fullName = 'autosession\'+$name
$filePattern = $fileName -replace '(\.\w+)$'
$filePattern = $filePattern + '*'
Write-Verbose "FilePattern is $filePattern"

# Logman behaves differently in versions of Windows prior to 2008 (e.g. XP)
$is2k8orLater = ([Environment]::OSVersion.Version.Major) -gt 5

# Define array for storing information about log jobs in
$allJobInfo = @()
Write-Verbose "Discovering existing log jobs..."

# Get information on all existing jobs
if ($is2k8orLater)
{
    # In Win2k8+, log job information is stored in the registry with the job
    # name as the key name and the output file path as one of the values.
    $allLogs = Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger
    $allLogs | Get-ItemProperty -Name "FileName","PSChildName" -ErrorAction SilentlyContinue |
    foreach {
        if ($_.FileName)
        {
            # Define properties of the job objects
            $jobInfo = @{"outputFile"=""; "jobName"=""}
            # expand environment variables in the filepath, e.g. %SYSTEMROOT%
            $jobInfo.outputFile = [System.Environment]::ExpandEnvironmentVariables($_.FileName) 
            $jobInfo.jobName = $_.PSChildName
            $allJobInfo += $jobInfo
        }
    }
} 
else
{
    # In WinXP, log job information is stored in a different place in the
    # registry, with a random GUID as the key name for each job, and output
    # file path, job names, etc., stored as values within those keys.
    $allLogs = (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\SysmonLog\Log Queries\' |
    Get-ItemProperty -Name "Current Log File Name","Collection Name" -ErrorAction SilentlyContinue)
    $allLogs | foreach {
        if ($_."Collection Name" -and $_."Current Log File Name")
        {
            # Define properties of the job objects
            $jobInfo = @{"outputFile"=""; "jobName"=""}
            # expand environment variables in the filepath, e.g. %SYSTEMROOT%
            $jobInfo.outputFile = [System.Environment]::ExpandEnvironmentVariables($_."Current Log File Name") 
            $jobInfo.jobName = $_."Collection Name"
            $allJobInfo += $jobInfo
        }
    }
}

Write-Verbose "All running log jobs on the system:"

# Check the input parameters against list of existing job names and output file
# paths to ensure there won't be any clashes or unintended side-effects
$jobNameInUse = $false # Whether the job name is taken
$fileNameInUse = $false # Whether the file is in use by an existing job
$jobAndFileMatch = $false # Whether a single job exists which has the same name AND target file as the one being created
$fileMatchJobName = "" # The name of the existing job with matching file name, if it exists

$allJobInfo | foreach {
    Write-Verbose "Name: $($_.jobName)   File: $($_.outputFile)"
    $nameMatch = $false
    $fileMatch = $false 
    if (($_.jobName -like $fullName) -or ($_.jobName -like $name))
    {
        $nameMatch = $true
    }
    if ($_.outputFile -like $filePattern)
    {
        $fileMatch = $true
        $fileMatchJobName = $_.jobName
    }
    $jobNameInUse = ($nameMatch -or $jobNameInUse)
    $fileNameInUse = ($fileMatch -or $fileNameInUse)
    $jobAndFileMatch = (($fileMatch -and $nameMatch) -or $jobAndFileMatch)
}

Write-Verbose "Results: jobNameInUse=$jobNameInUse  fileNameInUse=$fileNameInUse  jobAndFileMatch=$jobAndFileMatch  fileMatchJobName=$fileMatchJobName"

# Find any existing log jobs with the same name, and stop and delete them.
if($is2k8orLater)
{
    if ($jobNameInUse)
    {
        # autosessions
        Write-Verbose "Log autosession job already exists, removing old job '$name'"
        $result = logman delete "autosession\$name"
        Write-Verbose "logman delete autosession result is '$result'"
        
        # ets jobs need to be stopped separately
        # Can't tell whether a log is actually running, so must just try both
        # "stop" and "delete" and ignore any error.
        Write-Verbose "Log ets job already exists, removing old job '$name'"
        $result = logman stop $name -ets
        Write-Verbose "logman stop ets result is '$result'"
        $result = logman delete $name -ets
        Write-Verbose "logman delete ets result is '$result'"
    }
}
# pre-Win2k8
else
{
    if ($jobNameInUse)
    {
        Write-Verbose "Log autosession job already exists, removing old job '$name'"
        # Again, we can't tell whether jobs are running, so attempt to
        # stop anyway and ignore any errors.
        $result = logman stop "autosession\$name"
        Write-Verbose "logman stop result is '$result'"
        # allow the trace to stop before deletion
        Start-Sleep 2
        $result = logman delete "autosession\$name"
        Write-Verbose "logman delete autosession result is '$result'"
    }
    
    # ets jobs are automatically removed as the corresponding autosession is
    # deleted in pre-Win2k8.
}

if (-not $stop)
{   
    # Check for case where user is trying to create a new log to a file already
    # in use by another log job.
    if((-not $jobAndFileMatch) -and $fileNameInUse)
    {
        $friendlyJobName = $fileMatchJobName
        if(-not $is2k8orLater)
        {
            $friendlyJobName = $friendlyJobName -replace '^autosession\\'
        }
        Write-Error "The file '$fileName' is already in use by a different existing log job, '$friendlyJobName'. Please specify a different filename using the -filename parameter, or stop the existing job using the command '.\New-XdLogTrace.ps1 -stop -name $friendlyJobName'"
        return
    }
    
    # Check the target directory exists, or create it
    $fileDir = Split-Path -Path $fileName -Parent
    if (!(Test-Path $fileDir -PathType Container))
    {
        Write-Verbose "Creating log directory '$fileDir'."
        [void] (mkdir -Path $fileDir)
    }
    
    # Check whether the specified log output file already exists
    if (Test-Path $filePattern)
    {
        if ($preserveOldLogs)
        {
            # Make a copy of the file to a random file name
            $saveDir = Join-Path $fileDir ([IO.Path]::GetRandomFileName())
            Write-Verbose "Preserving old log files in '$saveDir'."
            [void] (mkdir $saveDir)
            Copy-Item $filePattern -Destination $saveDir
        }
        # Delete the old file
        Write-Verbose "Deleting old log files."
        Remove-Item $filePattern
    }

    # Build a list of modules from all sources
    $allModules = @{} # Hashtable where key = module name, value = module GUID

    if (-not $useCtlOnly)
    {
        Write-Verbose "Looking in the registry for supported Citrix products..."

        # Check whether any CDF-log-able Citrix products are identified in the registry
        $tracingRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Citrix\Tracing\Modules'
        if (Test-Path $tracingRoot)
        {
            $items = @(Get-Item (join-Path $tracingRoot '*'))
            $items | foreach {
                $guid = $_.GetValue('GUID') -replace ",", "-"
                $moduleName = Split-Path $_.PsPath -Leaf
                try {
                    $allModules.Add($moduleName, $guid)
                } catch {} # Can throw an exception if there are duplicate modules - but it doesn't matter
            }
            Write-Verbose "Found $($allModules.Count) modules in the registry."
        } else {
            Write-Verbose "No supported Citrix products found in the registry."
        }
    }
    
    # Check list of CTL files for any further non-registry modules
    $ctlLocations | foreach {
        if (Test-Path $_)
        {
            $ctlCount = 0
            Get-Content $_ | foreach {
                # CTL files contain a GUID and a module name (separated by spaces) on each line.
                # GUIDs are in the standard GUID format and can use commas or hyphens.
                if ($_ -match '^\s*(?<guid>[a-fA-F0-9]{8}[-,][a-fA-F0-9]{4}[-,][a-fA-F0-9]{4}[-,][a-fA-F0-9]{4}[-,][a-fA-F0-9]{12})\s+(?<modname>\w+)\s*$')
                {
                    $guid = $matches['guid'] -replace ",", "-"
                    $moduleName = $matches['modname']
                    try {
                        $allModules.Add($moduleName, $guid)
                        $ctlCount ++
                    } catch {} # Can throw an exception if there are duplicate modules - but it doesn't matter
                }
            }
            Write-Verbose "Found $ctlCount modules in CTL file at '$_'."
        } else {
            Write-Warning "Could not find CTL file at '$_'."
        }
    }

    Write-Verbose "Total number of modules discovered: $($allModules.Count)."
    Write-Verbose "Filtering modules using whitelist and blacklist..."
    Write-Verbose "Filtered list of modules which will be logged:"

    # Create a list of all modules which are compatible with the given filters.
    $filteredModules = @{}
    $allModules.GetEnumerator() | Sort-Object Name | foreach {
        $moduleName = $_.Name
        $guid = $_.Value
        $matchWhitelist = $whitelist | Where-Object {$moduleName -like  $_ }
        $matchBlacklist = $blackList | Where-Object {$moduleName -like  $_ }
        if ($matchWhitelist -ne $null -and $matchBlacklist -eq $null)
        {
            # This time, use the GUID as the Key. This will ensure we don't get any duplicate GUIDs, in the event that a module was recorded twice with different names.
            try {
            $filteredModules.Add($guid, $moduleName)
            Write-Verbose $moduleName
            } catch {}
        }
    }

    # Check that at least 1 module is actually selected
    Write-Verbose "Total number of modules which will be logged: $($filteredModules.Count)."
    if ($filteredModules.Count -le 0)
    {
        Write-Error "No modules were selected. Verify your whitelist and blacklist, CTL file locations (if applicable), and that compatible Citrix products are installed. See help for more information."
        return
    }

    # Write module definitions to temporary file, which logman will use
    Write-Verbose "Creating temporary module definitions file..."
    $defs = $filteredModules.GetEnumerator() | foreach {
        # some pre-win2k8 OSs (such as XP) are intolerant of comments in the provider file
        if ($is2k8orLater) { "# $($_.Value)" }
        "{$($_.Name)}`t0xfffffff`t$logLevel"
    }
    $tmpFile = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    Out-File $tmpFile -Encoding ASCII -InputObject $defs
    Write-Verbose "Temporary file for module definitions saved at $tmpFile."

    # Get the localised time/date format
    $startTime = [DateTime]::Now
    $endTime = $startTime + [TimeSpan]::FromDays(9999)
    $culture = Get-Culture
    $timeFormat = $culture.DateTimeFormat.LongTimePattern
    $dateFormat = $culture.DateTimeFormat.ShortDatePattern
    $dateTimeFormat = $dateFormat + " " + $timeFormat
    Write-Verbose "Localized time/date format is: $dateTimeFormat."
    
    # Create the log
    $result = logman create trace -n $fullName -f bincirc -max $maxSizeMb -pf $tmpFile -o $fileName -bs 32 -ft 10 -b ($startTime.ToString($dateTimeFormat)) -e ($endTime.ToString($dateTimeFormat))
    Write-Verbose "logman create autosession result is '$result'."

    if ($is2k8orLater)
    {
        # for win2k8 and later OSs, must seprately start the first trace session
        $result = logman create trace -ets -n $name -f bincirc -max $maxSizeMb -pf $tmpFile -o $fileName -bs 32 -ft 10
        Write-Verbose "logman create initial trace session result is '$result'."
    }

    Write-Verbose "Started collection as trace item '$fullName'."
}

Write-Verbose "Operation complete."