$file = "D:\JB\COEDEV\Dev_systems.csv"
# Do not Edit Below this Line
if ($env:USERDNSDOMAIN -like "*dev-dir*")
{
	$VMCSVDATA = import-csv $file
}
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://dc1vwentexcd01.dev-ent.dev-dir.labor.gov/PowerShell/" -Authentication Kerberos
Import-PSSession $Session
Set-ADServerSettings -ViewEntireForest $true
foreach ($Data in $VMCSVDATA){
Enable-RemoteMailbox $DATA.devUserName -Verbose -Alias  ($Data.devEmail -replace "@dev.dol.gov") 
}
#To check all mailboxes are created
$VMCSVDATA.DevUserName | %{get-mailbox $PSItem}