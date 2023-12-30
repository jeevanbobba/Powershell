$users =import-csv -Path C:\temp\upn.csv
#$allobjects=@()
foreach ($user in $users)
{
$username = $user.DEVAccount
$updatedUPN = $user.UPN
(Get-ADForest).domains |% { get-ADuser -filter {samaccountname -eq $USERNAME} -server $psitem |?{$psitem.distinguishedname -notmatch "_exclude-migrated"} | Set-ADUser -UserPrincipalName $updatedUPN -Verbose}
#(Get-ADForest).domains |% { get-ADuser -filter {samaccountname -eq $USERNAME} -server $psitem  -Properties Name, PasswordExpired, PasswordLastSet,employeenumber|Export-Csv c:\temp\upnupdate.csv -NoTypeInformation}
}


Get-ADUser "z-Gaddam-Anvesh" -Server dev-ent.dev-dir.labor.gov -Properties Name, PasswordExpired, PasswordLastSet,employeenumber


$username = "z-Gaddam-Anvesh"
$updatedUPN = ""

(Get-ADForest).domains |% { get-ADuser -filter {samaccountname -eq $USERNAME} -server $psitem -Properties Name, PasswordExpired, PasswordLastSet,employeenumber |?{$psitem.distinguishedname -notmatch "_exclude-migrated"}}| Set-ADUser -UserPrincipalName $updatedUPN -EmployeeNumber $updatedupn -Verbose}



