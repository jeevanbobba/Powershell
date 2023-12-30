$datas =import-csv -Path C:\temp\dev.csv
#$allobjects=@()
foreach ($Data in $Datas)
{
$username = $data.ProdEmail
$updatedUPN = $data.UPN
$user = $Data.DEVUserName
$firstname =$data.FirstName
$lastname = $data.LastName
$name = $data.Name
$DisplayName = $data.Name
        
(Get-ADForest).domains |% { get-ADuser -filter {EmployeeNumber -eq $USERNAME} -server $psitem |?{$psitem.distinguishedname -notmatch "_exclude-migrated"} | Set-ADUser -Name $name -GivenName $firstname -Surname $lastname -DisplayName $DisplayName -Verbose }
}


Set-ADUser -Identity $user -Name $name -GivenName $firstname -Surname $lastname -DisplayName $DisplayName





Get-ADUser "Z-smpierce" -Server dev-ent.dev-dir.labor.gov -Properties Name, SamAccountName , PasswordExpired, PasswordLastSet, EmployeeNumber

