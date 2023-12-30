$ForestInfo=Get-ADForest
$Domains =$forestInfo.domains
$FileName =$ForestInfo.RootDomain+"Active"+"$(get-date -Format MM-dd-yyyy)"+".csv" #"stage-oalj.stage-dir.labor.gov","stage-apps.dir.labor.gov","bls.dir.labor.gov","dir.labor.gov","EBSADOL.dir.labor.gov","ent.dir.labor.gov","esa.dir.labor.gov","eta.dir.labor.gov","msha.dir.labor.gov","oasam.dir.labor.gov","oig.dir.labor.gov","osha.dir.labor.gov" #"esa.dol.gov","esadev.dol.gov"#
$FilePath = "c:\temp"
$Daysactive = 60
$lastactive=(get-date).AddDays(-($Daysactive))
foreach($domain in $domains){
Write-Output "Working on $domain"
Get-ADComputer -Filter {OperatingSystem -like "*server*" -and lastlogondate -gt $lastactive -and enabled -eq $true } -Property Name,DNSHostName,OperatingSystem,OperatingSystemServicePack,IPv4Address,LastLogonDate,Modified,Description,DistinguishedName,Created -Server $domain| select Name,DNSHostName,OperatingSystem,OperatingSystemServicePack,IPv4Address,LastLogonDate,Modified,Description,DistinguishedName,Created | Export-Csv -NoTypeInformation $FilePath\$FileName -append
} 
