$ForestInfo = Get-ADForest
$Domains = $forestInfo.domains

# Create filename with current date
$FileName = $ForestInfo.RootDomain + "-Forest_Windows_Servers_270_Days_Active-" + (Get-Date -Format MM-dd-yyyy) + ".csv"

# Set output folder path
$FilePath = "c:\temp"

# Define threshold for last active date
$DaysActive = 270
$LastActive = (Get-Date).AddDays(-$DaysActive)

foreach ($domain in $domains) {
    # Informational message
    Write-Output "Working on domain: $domain"

    # Filter for Windows Servers with last logon within threshold
    Get-ADComputer -Filter {
        OperatingSystem -like "*server*"
        -and LastLogonDate -gt $LastActive
        -and Enabled -eq $true
    } -Property Name, DNSHostName, OperatingSystem, OperatingSystemServicePack, IPv4Address, LastLogonDate, Modified, Description, DistinguishedName, Created -Server $domain |
    Select-Object Name, DNSHostName, OperatingSystem, OperatingSystemServicePack, IPv4Address, LastLogonDate, Modified, Description, DistinguishedName, Created |
    Export-Csv -NoTypeInformation -Path "$FilePath\$FileName" -Append
}