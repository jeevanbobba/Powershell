$KCuserlist =Import-Csv C:\Temp\devuserslist.csv
foreach ($KCuser in $KCuserlist)
{
$Kuser = $KCuser.DevUserName #"oasam-testuser"
$KDomain = $KCuser.DevDomain #"dev-oasam.dev-dir.labor.gov"
$KPreEmail = $KCuser.ProdEmail #  katneni.krishna.c@dol.gov
Get-ADUser $Kuser -server $KDomain -Properties SamAccountName,DisplayName,EmailAddress,mail,EmployeeNumber,Enabled,PasswordLastset,PasswordNeverExpires,DistinguishedName | Select SamAccountName,DisplayName,EmailAddress,mail,EmployeeNumber,Enabled,PasswordLastset,PasswordNeverExpires,DistinguishedName | Export-Csv -NoTypeInformation C:\Temp\devuserlist-csv.csv -Append
Write-Output "working on $KDomain\$Kuser "
}

