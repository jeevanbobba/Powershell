# Get the current domain name
#$domainName = (Get-ADDomain).Name
$domainName = (Get-ADDomain).DNSRoot

# Get all domain controllers with specific properties
$domainControllers = Get-ADDomainController -Filter * -Server $domainName | Select-Object Name, HostName, OperatingSystem, IPv4Address, Domain, Forest, Site

# Display the information in a formatted table
$domainControllers | Format-Table -AutoSize

# Optional: Export the information to a CSV file
 #$domainControllers | Export-Csv -Path "C:\temp\domain_controllers.csv" -NoTypeInformation
#Get-ADDomainController -Filter * -Server dexter.dexteraxle.com | Select-Object Name, OperatingSystem, IPv4Address

