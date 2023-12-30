$Domains = (get-adforest).Domains -notmatch "bls.dir.labor.gov|oig.dir.labor.gov"
$fulldata = @()
foreach($domain in $domains){
Write-Output "Working on $domain at $(Get-Date)"
$serverdata = Get-adcomputer -server $domain -filter {OperatingSystem -like "*Server*"} -Properties *
        foreach($server in $serverdata) {
        $object = New-Object psobject
        $object | Add-Member -MemberType NoteProperty -Name "Domain" -Value "$domain"
        $object | Add-Member -MemberType NoteProperty -Name "Host Name" -Value $server.Name
        $object | Add-Member -MemberType NoteProperty -Name "IPv4 Address" -Value $server.IPv4Address
        $object | Add-Member -MemberType NoteProperty -Name "Operating System" -Value $server.OperatingSystem
        $fulldata += $object
        }#for Servers
}#For Domain
$fulldata | Export-csv C:\Exports\HDDump\ProdServers.csv -NoTypeInformation -Force