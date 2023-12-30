$folder = "\\ers1srvc01.oasam.dir.labor.gov\CSD\"
$files = (robocopy $folder NULL /l /s /ndl /xx /nc /ns /njh /njs /fp) | ForEach-Object {$_.trim()} | Select-Object -Skip 1 #to Get all files
[System.Collections.ArrayList]$report = $files | ForEach-Object -Parallel {(Get-NTFSAccess $psitem -ErrorAction SilentlyContinue).Account.AccountName} -ThrottleLimit 100
$emailreport = new-object System.Collections.ArrayList
$uq = $report  | select-object -Unique
$cleaneduq = $uq -notmatch "\\z-|^BUILTIN|^NT Auth|domain admins" 
foreach($item in $cleaneduq){
$domain = ($item -split "\\")[0]
$obj = ($item -split "\\")[1]
     try {get-adgroup $obj -Server $domain  | Get-ADGroupMember -Recursive -Server $domain | ForEach-Object{get-aduser $psitem.SamAccountName -Properties DisplayName,Mail,SamAccountName} | Select-Object DisplayName,Mail,SamAccountName | ForEach-Object{$emailreport.Add($psitem)}
         get-aduser $obj -Server $domain    -Properties DisplayName,Mail,SamAccountName | Select-Object DisplayName,Mail,SamAccountName | ForEach-Object{$emailreport.Add($psitem)}
}
catch {}
}
$emailreport | Select-Object -Property DisplayName,Mail,SamAccountName -Unique | export-csv "\\silentfs01\Reports\Temp\CSDShare.csv" 
