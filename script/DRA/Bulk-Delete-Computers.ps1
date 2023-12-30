$DRASERVER = "DC1VWDRAIISP02.ent.dir.labor.gov"
$cred = Get-Credential dir\vsurapaneni
$accounts = (import-excel 'C:\Users\vsurapan\Downloads\ENT Domain Disabled accounts_202204_gw.xlsx' -WorksheetName "FED","CTR").Values.'Sam Account Name' | select -Unique
$enabledaccounts=0
$notfoundaccounts=0 
$NeedtoProcessAccounts   = New-Object System.Collections.Generic.List[System.Object]
foreach($account in $accounts) {
try {
if((Get-ADUser $account).Enabled){
  #Write-Output "$account is Enabled"
  $enabledaccounts++}
  else{
     Get-ADUser $account | Set-ADObject -ProtectedFromAccidentalDeletion:$false -PassThru -Credential $cred
     $NeedtoProcessAccounts.Add($((Get-ADUser $account).DistinguishedName | ?{$PSItem -notmatch "OU=NetIQRecycleBin"}))
  }
}
catch {
 #Write-Output "$account is Already Deleted"
 $notfoundaccounts++
}
}
Write-Output "$enabledaccounts - Enabled Accounts and $notfoundaccounts - Not Found -- Total of $($accounts.count)"
$body=  @"
{
   "userIdentifier": "###UDN###"
  }
"@
foreach($item in $NeedtoProcessAccounts){
$mbody = $body -replace "###UDN###",$item
#$results = Invoke-RestMethod -Method Post -Credential $cred -Uri "https://$DRASERVER`:8755/dra/domains/ent.dir.labor.gov/users/delete" -ContentType 'application/json' -Body $mbody 
}
