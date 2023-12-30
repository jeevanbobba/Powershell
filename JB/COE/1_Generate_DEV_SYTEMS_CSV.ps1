#read script folder
#$scriptpath = $MyInvocation.MyCommand.Path
#$dir = Split-Path $scriptpath
#Write-host "My directory is $dir"
################################################
#$file = '\\mgtutils01\dml\COE-DEV\RDP_Files\Ref\Scripts\Final\Dev_Systems.csv'
$file = "C:\Scripts\DEV-Scripts\Dev_systems.csv"
#$textemaildata  = '\\mgtutils01.oasam.dir.labor.gov\DML\COE-DEV\RDP_Files\Ref\Scripts\Final\devuseremail.txt'
$textemaildata  = "C:\Scripts\dev-scripts\email.txt"
Rename-Item $file $($file -replace ".csv","_$(Get-Date -Format hhmm-MM-dd-yyyy).csv" ) -ErrorAction Stop | Out-Null
function usertrim($username) { if ($username.length -le 18) {$username} else {$username.substring(0, 18)}} 
gc $textemaildata  | %{
#Get-ADUser -Filter {EmailAddress -like $PSItem} -Properties Department -Server ent.dir.labor.gov:3268 | select @{l="ComputerName";e={}},@{l="IPAddress";;e={}},@{l="FolderName";;e={}},@{l="DEVUserName";e={"z-"+$(usertrim -username $_.SamAccountName)}},Name,@{l="Agency";e={$_.Department}},@{l="DevUserDomain";e={"DEV-"+(((($_.DistinguishedName -Split "," | ? {$_ -like "DC=*"})  -replace ("DC=", ""))[0]).toupper())}},@{l="DEVEmail";e={($_.UserPrincipalName) -replace "@dol.gov","@dev.dol.gov"}},@{l="Status";e={}},@{l="ProdUserName";e={$_.SamAccountName}},@{l="ProdEmail";e={$_.UserPrincipalName}},@{l="ProdUserDomain";e={((($_.DistinguishedName -Split "," | ? {$_ -like "DC=*"})  -replace ("DC=", ""))[0]).toupper()}},@{l="Distributed";;e={}},@{l="Notes";;e={}} | Export-csv $file -NoTypeInformation -Append
Get-ADUser -Filter {EmailAddress -like $PSItem} -Properties Department -Server ent.dir.labor.gov:3268 | select @{l="ComputerName";e={}},@{l="IPAddress";;e={}},@{l="FolderName";;e={($_.Department)+"-Maint"}},@{l="Agency";e={$_.Department}},Name,@{l="FirstName";e={$_.GivenName}},@{l="LastName";e={$_.Surname}},@{l="DisplayName";e={$_.DisplayName}},@{l="DEVUserName";e={$(usertrim -username $_.SamAccountName)}},@{l="DevDomain";e={"DEV-"+(((($_.DistinguishedName -Split "," | ? {$_ -like "DC=*"})  -replace ("DC=", ""))[0]).toupper())}},@{l="DEVEmail";e={($_.UserPrincipalName) -replace "@dol.gov","@dev.dol.gov"}},@{l="ProdUserName";e={$_.SamAccountName}},@{l="ProdEmail";e={$_.UserPrincipalName}},@{l="ProdDomain";e={((($_.DistinguishedName -Split "," | ? {$_ -like "DC=*"})  -replace ("DC=", ""))[0]).toupper()}},@{l="Distributed";;e={}},@{l="Notes";;e={}},@{l="Status";e={}} | Export-csv $file -NoTypeInformation -Append
}