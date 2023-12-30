$computers= gc C:\temp\Servers.txt

function Stop-PendingService {
<#
.SYNOPSIS
    Stops one or more services that is in a state of 'stop pending'.
.DESCRIPTION
     Stop-PendingService is a function that is designed to stop any service
     that is hung in the 'stop pending' state. This is accomplished by forcibly
     stopping the hung services underlying process.
.EXAMPLE
     Stop-PendingService
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>
    $Services = Get-WmiObject -Class win32_service -Filter "state = 'stop pending'"
    if ($Services) {
        foreach ($service in $Services) {
            try {
                Stop-Process -Id $service.processid -Force -PassThru -ErrorAction Stop
            }
            catch {
                Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message"
            }
        }
    }
    else {
        Write-Output "There are currently no services with a status of 'Stopping'."
    }
}

Foreach ($computer in $computers)
{
#Stop-Service -InputObject $(Get-Service -ComputerName $computer -Name BESClient)
#Start-Service -InputObject $(Get-Service -ComputerName $computer -Name BESClient)
Get-Service -ComputerName $computer -Name BESClient
$action = Get-Service -ComputerName $computer -Name BESClient
#IF($action.Status -eq 'stopping')
IF($action.Status -eq 'Running')
{
Invoke-Command -ComputerName $computer -ScriptBlock ${Function:\Stop-PendingService}
}
Else
{
Get-Service -ComputerName $computer -Name BESClient #| Select-Object status,  Name , $_
#Start-Service -InputObject $(Get-Service -ComputerName $computer -Name BESClient)
}}
#Get-Process -ComputerName $computers -Name BESClient
<#

Invoke-Command -ComputerName $computers -ScriptBlock ${Function:\Stop-PendingService} 


function kill-process
{

[cmdletbinding()]
param(
  $ComputerName=$env:COMPUTERNAME,
  [parameter(Mandatory=$true)]
  $ProcessName
)
$Processes = Get-WmiObject -Class Win32_Process -ComputerName $ComputerName -Filter "name='$ProcessName'"
 
foreach ($process in $processes) {
  $returnval = $process.terminate()
  $processid = $process.handle
 
if($returnval.returnvalue -eq 0) {
  write-host "The process $ProcessName `($processid`) terminated successfully"
}
else {
  write-host "The process $ProcessName `($processid`) termination has some problems"
}
}
}

kill-process -ComputerName $computers -ProcessName BESClient

#>