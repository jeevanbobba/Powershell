<# .SYNOPSIS
Updates tags for Azure VMs based on a provided Excel file. 
This script helps ensure specific tags ("COSTCENTER", "RESOURCE_TYPE", etc.) are set correctly for VMs.

DESCRIPTION
Reads VM data (Name, ResourceGroup, specific tags) from an Excel file and updates tags for corresponding VMs in the chosen Azure subscription.

EXAMPLE: This script can be used to update tags for VMs in a specific Azure subscription based on a file named "tags.xlsx" located in the "C:\temp" directory.
AUTHOR: Jeevan Bobba
VERSION: 1.0
LASTUPDATED: 2024-03-15
PARAMETER: ExcelFilePath (Optional): Path to the Excel file containing VM data. Defaults to "C:\temp\tags.xlsx".
INPUTS: Excel file containing VM data (NAME, IPAddress,RESOURCE_TYPE,COSTCENTER,RESOURCE_CATEGORY,ADMINISTRATOR,APPLICATION,OWNER,TurboScalingPolicy,USAGE,BUSINESS_PROCESS SUBSCRIPTION, RESOURCEGROUP )
OUTPUTS: Messages indicating successful tag updates or skipped VMs due to not being found. #>

# Install Import-Excel module if not installed
  Install-Module -Name ImportExcel -Force -SkipPublisherCheck -ErrorAction SilentlyContinue  #>

# Import the Import-Excel module
  Import-Module ImportExcel

# Login to Azure (if not already logged in)
#Connect-AzAccount

# Get a list of subscriptions
$subscriptions = Get-AzSubscription

# Display subscriptions and prompt the user to select one
Write-Host "Please select a subscription by entering the number: " -ForegroundColor Cyan
for ($i=0; $i -lt $subscriptions.Count; $i++) {
    Write-Host "$($i+1): $($subscriptions[$i].Name)" -ForegroundColor Green
}
$selectedSubscriptionIndex = Read-Host "Enter subscription number" -AsInt
$selectedSubscription = $subscriptions[$selectedSubscriptionIndex - 1]

# Set the selected subscription
Set-AzContext -SubscriptionId $selectedSubscription.Id

# Specify the path to the Excel file
$excelFilePath = "C:\temp\tags.xlsx"

# Read data from Excel file
$excelData = Import-Excel -Path $excelFilePath

foreach ($record in $excelData) {
    $vmName = $record.Name
    $resourceGroupName = $record.ResourceGroup
    $tags = @{}

    # Define a list of tags you wish to ensure are correct
    $tagKeys = @("COSTCENTER", "RESOURCE_TYPE", "RESOURCE_CATEGORY", "ADMINISTRATOR", "APPLICATION", "OWNER", "USAGE", "BUSINESS_PROCESS","TurboScalingPolicy")

    # Iterate over each tag
    foreach ($tagKey in $tagKeys) {
        $tagValue = $record.$tagKey

        # Only set the tag if the value is not empty
        if (-not [string]::IsNullOrWhiteSpace($tagValue)) {
            $tags[$tagKey] = $tagValue
        }}

    # Get the Azure VM by name
    $vm = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -eq $vmName }
    if ($vm)
     {
        # Update tags for the VM
        $resourceId = $vm.Id
        Update-AzTag -ResourceId $resourceId -Tag $tags -Operation Merge
        Write-Host "Updated tags for VM '$vmName' in resource group '$resourceGroupName'." -ForegroundColor Green
    }
     else
    {
        Write-Host "Azure VM '$vmName' not found in resource group '$resourceGroupName'. Skipped." -ForegroundColor Yellow
    }}

Write-Host "Tag update process completed." -ForegroundColor Cyan
