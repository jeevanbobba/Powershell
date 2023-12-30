#setup azure connection
Disable-AzContextAutosave –Scope Process

$connection = Get-AutomationConnection -Name AzureRunAsConnection

while(!($connectionResult) -and ($logonAttempt -le 10))
{
    $LogonAttempt++
    # Logging in to Azure...
    $connectionResult = Connect-AzAccount `
                            -ServicePrincipal `
                            -Tenant $connection.TenantID `
                            -ApplicationId $connection.ApplicationID `
                            -CertificateThumbprint $connection.CertificateThumbprint

    Start-Sleep -Seconds 30
}

#script
$intDay = (Get-Date).Day
if ($intDay -ge 8 -and $intDay -le 19) {
$strRG = "wvd-pilot-rg"
#get-azvm -ResourceGroupName $strRG | Where-Object {$_.Name -like "OCIO-VDI-DEV*" -or $_.Name -like "OCIOVDID*"} | ForEach-Object -Parallel {Start-AzVm -Name $_.Name -ResourceGroupName "wvd-pilot-rg"} 
#get-azvm -ResourceGroupName $strRG | Where-Object {$_.Name -like "OCIO-VDI-DEV*" -or $_.Name -like "OCIOVDID*"} | ForEach-Object {Start-Job -scriptblock {Write-Host $_.Name}}
#get-azvm -ResourceGroupName $strRG | Where-Object {$_.Name -like "OCIO-VDI-DEV*" -or $_.Name -like "OCIOVDID*"} | ForEach-Object {
#Start-Job -scriptblock {Start-AzVm -Name $args[0] -ResourceGroupName "wvd-pilot-rg"} -ArgumentList $_.Name}

$vms = get-azvm -ResourceGroupName $strRG | Where-Object {$_.Name -like "OCIO-VDI-DEV*" -or $_.Name -like "OCIOVDID*"}
$batch =@{
    Skip = 0
    First = 5
}

Do 
{
    foreach ($vm in ($vms | select-object @batch ))
    { $params = @($vm.Name)
    $job = Start-Job -scriptblock {
        param($computername)
        Start-AzVm -Name $computername -ResourceGroupName $strRG
    } -ArgumentList $params
    }
    
    Wait-Job -Job $job

    Get-Job | Receive-Job

    $batch.skip += 5
}
until(batch.skip -ge $vms.count)
}
