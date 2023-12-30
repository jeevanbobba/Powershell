$RSAPATH = "\\silentfs01\Reports\RSA"
$GC = "dc1pwdcdiradp01.dir.labor.gov:3268" #GC for AD Query
$RSAAuthFile = "$RSAPATH\RSA_AuthActivity.csv" #Activity Report
$RSAUserFile = "$RSAPATH\RSA_AllUserReports.csv" #user and Token Report
$RSAUserData = import-csv $RSAUserFile
$RSAAuthdata = import-csv $RSAAuthFile
$ReportUsers=$RSAUserData.'User ID'  | Select-Object -Unique
$byGroupRSAAUthreport = $RSAAuthdata | group-object -Property 'User ID'
$multitokenusers = ($RSAUserData | Group-Object 'User ID' | Where-Object {$PSItem.count -gt 1}).Name
$ReportTableforAuth = new-object System.Collections.ArrayList
$j=1
foreach($v in $ReportUsers){
 $rawitem = $byGroupRSAAUthreport | where-object{$Psitem.Name -eq $v}
 $useritem = $RSAUserData | where-object{$PSItem.'User ID' -eq $v}
 if($v -in $multitokenusers){
    $multitokens="True"}else{  $multitokens="False"}
 if($useritem.Count -gt 1){
                           $useritem = $RSAUserData | where-object{$PSItem.'User ID' -eq $v -and [datetime]$psitem.'Token Expiration Date' -gt $(get-date)}
                           if($useritem.Count -gt 1){
                            $useritem = $useritem | Sort-Object -Descending -Property  'Last Used to Authenticate' | Select-Object -First 1                            
                            }
                        }
 $item = $rawitem.Group
 $itemreport = ($item | ForEach-Object {$psitem.'Agent Name'+'/'+$psitem.'Agent IP'+'/'+$psitem.'date and Time'}) -join ";"
 if($v -match "^z-"){
    $ADu = (Get-ADUser -filter {SamAccountName -eq $v} -Server $useritem.'User Identity Source' -Properties Company).Company
    $ADdetails = Get-ADUser -filter {mail -eq $ADU} -Server $GC -Properties GivenName,DisplayName,Department,telephoneNumber,Office,City,State,PostalCode,Mail,Title,StreetAddress,Manager
    Clear-Variable ADU -Force
 }
 else{
 $ADdetails = Get-ADUser -filter {SamAccountName -like $v} -Server $GC -Properties GivenName,DisplayName,Department,telephoneNumber,Office,City,State,PostalCode,Mail,Title,StreetAddress,Manager
 } 
 $obj = [PSCustomObject]@{
        RSAUserID = $v
        TokenSerial = $userItem.'Serial Number'
        LoginCount = $rawitem.Count
        MultipleTokens = $multitokens
        TokenType = $useritem.'Token Type'
        TokenAssignedDate = $useritem.'Token Assigned Date'
        TokenEnabled = $useritem.'Token Enabled'
        TokenExpirationDate= $useritem.'Token Expiration Date'
        TokenLastUsedDate=if($useritem.'Last Used to Authenticate'){$useritem.'Last Used to Authenticate'}else {"None"}
        TokenMethod = $useritem.'PIN Type'
        DisplayName = $ADdetails.DisplayName
        GivenName = $ADdetails.GivenName
        Department= $ADdetails.Department
        "E-Mail"=$ADdetails.Mail 
        UserPrincipalName = $ADdetails.UserPrincipalName
        TelephoneNumber= $ADdetails.telephoneNumber
        Manager = ($ADdetails.Manager -split ",OU" -split "CN=")[1] -replace "\\"
        Office= $ADdetails.Office
        StreetAddress = $ADdetails.StreetAddress
        City = $ADdetails.City
        State = $ADdetails.State
        PostalCode = $ADdetails.PostalCode
        DistinguishedName = $ADdetails.DistinguishedName
        AgencyfromDN = ($ADdetails.DistinguishedName -split ",OU=Accounts,DC=ent,DC=dir,DC=labor,DC=gov" -split ",OU=")[1] -join "-"
        'LoginDetails(AgentName/IP/DateandTime)' = if($itemreport -like '//'){"None"}else{$itemreport}
        }
    Write-Progress -Activity "Compiling RSA Reports Auth Data to Array" -CurrentOperation "$j of $($ReportUsers.length)"  -PercentComplete ($j / $($ReportUsers.Length) * 100) -ErrorAction SilentlyContinue
    $ADdetails = $null
    $ReportTableforAuth.Add($obj)
$j++
}
$ReportTableforAuth | Export-Excel "$RSAPATH\RSA-Token-Usage-Report-$(get-date -f dd-MMMM-yyyy-HH-mm).xlsx" -AutoSize -AutoFilter
