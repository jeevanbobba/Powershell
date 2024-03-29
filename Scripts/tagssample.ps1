# Install Import-Excel module if not installed
# Install-Module -Name Import-Excel -Force -SkipPublisherCheck

# Import the Import-Excel module
Import-Module ImportExcel

# Login to Azure (if not already logged in)
# Connect-AzAccount

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

# Default COSTCENTER to the first word of the subscription name
$costCenterDefault = ($selectedSubscription.Name -split ' ')[0]

# Specify the path to the Excel file
$excelFilePath = "C:\temp\tags.xlsx"

# Read data from Excel file
$excelData = Import-Excel -Path $excelFilePath

# Find all VMs across all resource groups in the selected subscription
$allVMs = Get-AzVM

# Initialize a hashtable to keep track of last entered values for tags
$lastEnteredValues = @{}

foreach ($vm in $allVMs) {
  Write-Host "VM Name: $($vm.Name), Resource Group: $($vm.ResourceGroupName), Computer Name: $($vm.OSProfile.ComputerName)" -ForegroundColor Magenta
   
  # Prepare the tags hashtable for updating
  $newTags = @{}

  # Ensure defaults are set for missing tags
  $tagDefaults = @{
    "COSTCENTER" = $costCenterDefault
    "RESOURCE_TYPE" = "IaaS"
    "RESOURCE_CATEGORY" = "Virtual Machines"
  }

  # Define a list of tags you wish to ensure are correct
  $tagKeys = @("COSTCENTER", "RESOURCE_TYPE", "RESOURCE_CATEGORY", "ADMINISTRATOR", "APPLICATION", "OWNER", "TurboScalingPolicy", "USAGE", "BUSINESS_PROCESS")

  # Iterate over each tag
  foreach ($tagKey in $tagKeys) {
    $defaultValue = $null
    
    # Check if the Excel data contains a value for the current VM and tag
    $excelValue = $excelData | Where-Object { $_.VMName -eq $vm.Name -and $_.Tag -eq $tagKey } | Select-Object -ExpandProperty Value
    
    if ($excelValue) {
      $defaultValue = $excelValue
    } elseif ($tagDefaults.ContainsKey($tagKey)) {
      $defaultValue = $tagDefaults[$tagKey]
    }

    # If the tag already exists on the VM, use that value
    if ($vm.Tags.ContainsKey($tagKey)) {
      $defaultValue = $vm.Tags[$tagKey]
    }

    $promptMessage = "Enter value for tag '$tagKey'"
    if ($defaultValue) {
      $promptMessage += " (default: '$defaultValue', leave blank to use default)"
    }
    $tagValue = Read-Host $promptMessage

    # Determine how to update the tag value
    if (-not [string]::IsNullOrWhiteSpace($tagValue)) {
      $newTags[$tagKey] = $tagValue
    } elseif ($defaultValue) {
      $newTags[$tagKey] = $defaultValue
      # Do not overwrite last entered values with default values
    }
  }

  # Update the tags for the VM
  $resourceId = $vm.Id
  Update-AzTag -ResourceId $resourceId -Tag $newTags -Operation Merge
  Write-Host "Updated tags for VM '$($vm.Name)' in resource group '$($vm.ResourceGroupName)'." -ForegroundColor Green
}

Write-Host "Tag update process completed." -ForegroundColor Cyan
