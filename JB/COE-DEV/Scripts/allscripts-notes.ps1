Set-ADUser z-Wishinsky-Neil -server dev-EBSA.dev-dir.labor.gov -Employeenumber "Wishinsky.Neil@dol.gov"
get-ADUser z-hwhyte -server dev-esa.dev.dir.labor.gov -properties EmployeeNumber

repadmin /replsummary

get-aduser

 #get ad attrubute name

get-aduser z-Katram.Manisha.R -server dev-osha.dev-dir.labor.gov -properties proxyaddresses | Select-Object Name,ProxyAddresses |fl


get-ADUser z-hwhyte -server dev-esa.dev.dir.labor.gov -properties DisplayName
Get-ADUser z-Mosienko.Evgeniy -Server dev-ent.dev-dir.labor.gov -Properties displayname

$displayname = "Mosienko, Evgeniy (Jake) - OASAM OCIO CTR"

set-ADUser z-Mosienko.Evgeniy -Server dev-ent.dev-dir.labor.gov -DisplayName $displayname


(Get-ADForest).Domains | %{ Get-ADDomainController -Filter * -Server $_ }| Format-Table -Property Name,ComputerObjectDN,Domain,Forest,IPv4Address,OperatingSystem,OperatingSystemVersion

Get-ADObject -LDAPFilter "(&(CN=TermServLicensing)(objectClass=serviceConnectionPoint))"
Get-ADObject -Filter {objectClass -eq 'serviceConnectionPoint' -and Name -eq 'TermServLicensing'}

Set-RDLicenseConfiguration -LicenseServer @("DC1VWENTRDSD01") -Mode PerUser -ConnectionBroker "Rdcb.Contoso.com"

Get-RDLicenseConfiguration -ConnectionBroker "DC1VWENTRDSD01"