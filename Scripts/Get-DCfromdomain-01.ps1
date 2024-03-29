# Ensure the Active Directory module is loaded
Import-Module ActiveDirectory

# Get all domains in the forest
$domains = Get-ADForest | Select-Object -ExpandProperty Domains

# Enumerate all DCs across all domains
$allDCs = $domains | ForEach-Object { Get-ADDomainController -Filter * -Server $_ }

# Display the list of DCs (Hostname)
$domains= $allDCs | Select-Object Domain, Name, HostName, IPV4Address, Forest, OperatingSystem, Site
$domains| export-csv  c:\temp\domaincontroller.csv
