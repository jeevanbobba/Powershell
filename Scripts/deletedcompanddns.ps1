# Import Active Directory module (if necessary)
Import-Module ActiveDirectory
import-module dnss*
import-module dnsc*
#Get-Module -ListAvailable | Where-Object {$_.Name -eq 'ActiveDirectory'}

# Specify the path to the text file containing the list of computer names
$computerListPath = "C:\Temp\ADobjects.txt"

# Import the list of computer names from the text file
$computerNames = Get-Content $computerListPath

# Iterate through each computer name and perform actions
foreach ($computerName in $computerNames) {
  try {
    # Get the computer object based on the name using the -Filter parameter
    $computerObject = Get-ADObject -Filter { ObjectClass -eq 'computer' -and Name -eq $computerName } -ErrorAction Stop

    # Remove computer object and its subtree from Active Directory
    Remove-ADObject -Identity $computerObject -Recursive -Confirm:$false #  -ErrorAction Stop
    #Remove-ADComputer -Identity $computerObject -Confirm:$false
    #Remove-ADComputer -Identity $computername -Server AZUSEDA22DC1.dexter.dexteraxle.com -Confirm:$false
    # If the above line doesn't throw an error, the computer object and its subtree were found and removed
    #Indicate successful removal with green text
    Write-Host -ForegroundColor Green "Computer object '$computerName' and its subtree removed from Active Directory."
  }
 catch {
    # Handle errors during AD object removal
    if ($_.Exception.GetType().Name -eq "ADIdentityNotFoundException") {
      Write-Host -ForegroundColor Red "Computer object '$computerName' not found in Active Directory."
    } else {
      Write-Host -ForegroundColor Red "Error occurred for '$computerName': $_"
    }
  }

  try {
    # Attempt to remove the DNS entry (adjust the DNS server address as needed)
   # Get-DnsServerResourceRecord -ZoneName "dexter.dexteraxle.com" -ComputerName "AZUSEDA22DC1.dexter.dexteraxle.com" -Node  $computerobject.Name -RRType A
    Remove-DnsServerResourceRecord -ZoneName "dexter.dexteraxle.com" -ComputerName "AZUSEDA22DC1.dexter.dexteraxle.com" -Name $computerName -RRType A -Force -ErrorAction Stop

    # If the above line doesn't throw an error, the DNS entry was found and removed
    Write-Host -ForegroundColor Green "DNS entry for '$computerName' removed."

  } 
 catch {
         # Handle errors during DNS record removal
    Write-Host -ForegroundColor Red "DNS entry for '$computerName' not found or could not be removed: $_"
  }
}

Write-Host "Script execution completed."
