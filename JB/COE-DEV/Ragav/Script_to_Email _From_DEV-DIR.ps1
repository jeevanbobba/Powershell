#read script folder
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"
################################################
$file = "$dir\Dev_systems.csv"
# Do not Edit Below this Line
$VMCSVDATA = import-csv $file
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://sildevexch01.dev-ent.dev-dir.labor.gov/PowerShell/" -Authentication Kerberos
Import-PSSession $Session
Set-ADServerSettings -ViewEntireForest $true
foreach ($Data in $VMCSVDATA){
Enable-Mailbox $DATA.UserName -Verbose -Alias  ($Data.DevEmail -replace "@dev.dol.gov") 
}
#To check all mailboxes are created
$VMCSVDATA.DevUserName | %{get-mailbox $PSItem}





Set-ADUser -Identity $user -GivenName $firstname -Surname $lastname  -Description $description -Server $DomainName #added firstname and lastname