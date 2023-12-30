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
[array]$StoppedAzVMs = Get-AzVM -status | Where-Object {$_.PowerState -eq "VM stopped"}
if($StoppedAzVMs) {
    ForEach($StoppedAzVM in $StoppedAzVMs) {
        Stop-AzVM -Name $StoppedAzVM.Name -ResourceGroupName $StoppedAzVM.ResourceGroupName -Force
    }
}
