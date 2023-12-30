$outputreportforUsers = New-Object System.Collections.ArrayList
$outputreportforComputers = New-Object System.Collections.ArrayList
(get-adforest).domains | %{ 
$domain = $PSItem
$ADUserData = Get-ADuser -filter *  -Server $domain -Properties LastLogonDate,Description,Enabled,MemberOf,Created,HomeDrive,HomeDirectory,Mail | Select @{l="Domain";e={$domain}},Name,Description,DistinguishedName,Enabled,LastLogonDate,Created,@{Label = "Groups";Expression = {%{$PSItem.Memberof -join ','}}},SamAccountName,HomeDirectory,HomeDrive,UserPrincipalName,Mail
$ADCompData = Get-ADComputer -filter *  -Server $domain -Properties LastLogonDate,Description,Enabled,MemberOf,OperatingSystem,IPv4Address,Created | Select @{l="Domain";e={$domain}},Name,Description,DistinguishedName,Enabled,OperatingSystem,LastLogonDate,Created,@{Label = "Groups";Expression = {%{$PSItem.Memberof -join ','}}}
$ADUserData | %{$outputreportforUsers.Add($PSItem)}
$ADCompData | %{$outputreportforComputers.Add($PSItem)}
}
$outputreportforUsers | Export-Clixml "D:\JB\COE-DEV\Inventory\inventory-$(get-date -f MM-dd-yyyy-HH-mm)-AllUsers.xml"
$outputreportforComputers| Export-Clixml "D:\JB\COE-DEV\Inventory\inventory-$(get-date -f MM-dd-yyyy-HH-mm)-AlldevComputers.xml"
#For Combining Audits
$share = "\\COE_DEV_NAS.DEV-ENT.DEV-DIR.LABOR.GOV\ADAuditReports\"
$files = (gci $share  -File | Sort-Object -Property LastWriteTime).FullName
$dataarray = New-Object System.Collections.ArrayList
$datafinalarray = New-Object System.Collections.ArrayList
$reportarray = New-Object System.Collections.ArrayList
$Counter = 1 #For Progress Counter
foreach($file in $files){
$ErrorActionPreference = "SilentlyContinue"
$percentComplete = $(($Counter / $files.Count) * 100 )
    $Progress = @{
        Activity = "Processing File - $file"
        Status = "Processing $Counter of $($files.Count)"
        PercentComplete = $([math]::Round($percentComplete, 2))
    }
Write-Progress  @Progress -Id 1
$unfildata  = (get-excelsheetinfo $file).name | %{if($psitem -eq 'Sheet 0'){import-excel $file -WorksheetName $psitem  -StartRow 11 -DataOnly}else{ import-excel $file -WorksheetName $psitem -DataOnly}}|?{$Psitem.'User Name' -notmatch "^s-"} | %{
$PSItem.Domain = (($PSItem.Domain -split "\.")[0]).ToUpper()
$PSItem.'User Name' = ($PSItem.'User Name').ToUpper()
$PSItem
}| select "Domain","User Name","Client Host Name","Client IP Address","Logon/Logoff Time" 
$userHT = $unfildata | Group-Object  -Property 'Domain','User Name','Client IP Address' -AsHashTable -AsString
$uniqueData = $userHT.Keys | %{$userHT.$PSItem | Sort-Object -Property [Date]'Logon/Logoff Time' -Descending | select -First 1}
$uniqueData | %{$dataarray.Add($PSItem)} | Out-Null
$Counter++
}#ExcelFile
$finalHT = $dataarray | Group-Object  -Property 'Domain','User Name','Client IP Address' -AsHashTable -AsString
$uniqueFinalData = $finalHT.Keys | %{$finalHT.$PSItem | Sort-Object -Property [Date]'Logon/Logoff Time' -Descending | select -Last 1}
$uniqueFinalData | %{$datafinalarray.Add($PSItem)} | Out-Null
$AllUsers = $datafinalarray.'User Name' | select -Unique
$datafinalarray | Export-Clixml "D:\JB\COE-DEV\Inventory\$(get-date -f MM-dd-yyyy-HH-mm)-Until.xml"
$reportarray.Clear()
foreach($user in $AllUsers){
$userunidata = $datafinalarray | ?{$PSItem.'User Name' -eq $user}
$Details = ($userunidata | select @{l="D";e={$PSItem.'Client Host Name',"(",$PSItem.'Client IP Address',")","(",$PSItem.'Logon/Logoff Time',")" -join ""}}).D
$reportarray.Add(
[pscustomobject]@{
 'Domain' = ($userunidata.Domain | select -Unique | select -First 1)
 'User' = $user
'System/IP/RecentLogon'= $Details
}
)|out-null
}
#$reportarray | export-csv -NoTypeInformation -Path C:\Temp\UserLoginData.csv -Force
$reportarray | Export-Clixml "D:\JB\COE-DEV\Inventory\$(get-date -f MM-dd-yyyy-HH-mm)-logindatafromadaudit.xml" -Force
$opobjs = foreach ($r in $reportarray){
$val = ($r.'System/IP/RecentLogon' | %{($PSItem -split "\(")[0]} ) -join ","
$r | Add-Member -Name "System" -MemberType NoteProperty -Value $val -Force
$r | select Domain,User,System
}
$opobjs | %{
$PSItem.System = $PSItem.System -split "," | %{if($psitem -match "[A-Z]" ){($PSItem -split "\.")[0]}else{$PSitem}}
$PSItem
}| Export-Clixml "D:\JB\COE-DEV\Inventory\$(get-date -f MM-dd-yyyy-HH-mm)ForComparsion_Ready.xml"