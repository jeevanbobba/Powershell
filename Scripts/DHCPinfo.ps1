# Import the necessary modules
Import-Module DHCPServer

# Define the DHCP server name (replace with your server name)
$DHCPServer = "DHCPServerName"

# Define the output file path (replace with your desired path)
$outputFile = "C:\DHCPRecords.xlsx"

# Get all active leases from the DHCP server
$leases = Get-DhcpServerv4Lease -ComputerName $DHCPServer -AllLeases

# Create an empty Excel object
$excel = New-Object -ComObject Excel.Application

# Create a new workbook
$workbook = $excel.Workbooks.Add()

# Create a new worksheet and name it "DHCP Leases"
$worksheet = $workbook.Worksheets.Add(1)
$worksheet.Name = "DHCP Leases"

# Set headers for the worksheet
$headers = @("IP Address", "MAC Address", "Client Name", "Lease Start", "Lease End")
$i = 1
$headers.ForEach { $worksheet.Cells($i, 1) = $_; $i++ }

# Loop through each lease and write data to the worksheet
$i = 2
$leases | ForEach-Object {
    $worksheet.Cells($i, 1) = $_.IPAddress
    $worksheet.Cells($i, 2) = $_.ClientId
    $worksheet.Cells($i, 3) = $_.ClientName
    $worksheet.Cells($i, 4) = $_.LeaseStartTime
    $worksheet.Cells($i, 5) = $_.LeaseExpiresTime
    $i++
}

# Autofit columns to data
$worksheet.UsedRange.Columns.AutoFit()

# Save the workbook as an Excel file
$workbook.SaveAs($outputFile)

# Quit Excel
$excel.Quit()

# Release the Excel object
[System.Runtime.InteropServices]::ReleaseComObject($excel)

Write-Host "DHCP lease records exported to file: $outputFile"