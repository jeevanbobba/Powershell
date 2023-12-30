$file = "D:\JB\Chris\DevTest_systems.csv"
# Do not Edit Below this Line
if ($env:USERDNSDOMAIN -like "*dev-dir*")
{
	$VMCSVDATA = import-csv $file
}
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://dc1vwentexcd01.dev-ent.dev-dir.labor.gov/PowerShell/" -Authentication Kerberos
Import-PSSession $Session
Set-ADServerSettings -ViewEntireForest $true
foreach ($Data in $VMCSVDATA){
Enable-Mailbox $DATA.NPUserName -Verbose -Alias  ($Data.NPEmail -replace "@dev.dol.gov") 
}
#To check all mailboxes are created
$VMCSVDATA.NPUserName | %{get-mailbox $PSItem}