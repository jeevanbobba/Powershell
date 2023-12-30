# This Script Creates the user account in DEV/TEST/STAGE and/or creates a AVD/WVD in Azure

## To run the Script you need the following Parameters (along with the prerequisites )
1. Production Email of the User
2. Agency the user is supporting 
3. Ticket/Incident Number from ServiceNow
4. Federal lead Email

#### If user already exists in the corresponding Environment(Checking by comparing the Employeenumber attrib to prod email account) ..this script will not do anything.

## ProvisioningMode Needs to be "User_With_AVD", "User_Only" or  "AVD_Only"
**User_With_AVD** - This Mode provisions AVD along with User Account as well

**AVD_Only** - This Mode provisions only AVD . No user Account will be Provisioned 

**User_Only** - This Mode provisions only User Account. No Machine/AVD will be Provisioned

**_Please See the examples in the end section for more information on using the Provosioning Mode_**

### This Script does the following
- Creates the login name using production naming standards and password specified in the welcome email
- Adds the EmployeeNumber as prod email to help reset the password
- Copies all the Cosmetic Values from Production (Display Attributes)
- Adds correct Non-Production groups for access (including Administrative groups)
- Adds the User to the AZ groups in Prod. for correct Billing
- Created the AVD and Joins to domain and places in the correct OU (by agency specified)
- Add the correct tags in Azure for proper identification
- Sends an email to the appropriate groups on successful creation

## Prerequisites

- Need Email Relay Authorized to run this Script (Additional Details Please Contact T3 EMail Team). Enabled on the Jumpboxes Windows Admin Team uses
- Access to Azure keyvault to retrive the secret (This is Granted using AVD-DEV-OCIO-KV-WINDOWSADMINS)
- Need Access to \\silentfs01.ent.dir.labor.gov\MGTOPS\Scrips_Certs\AVD-Scripted to get the Parameters and related JSON templates

- Need Following Modules 
 1. Azure (Provisioning Azure VM and Secret Management)
 2. Mailozaurr (Sending Email)
 3. AD Cmdlets (Create and Modify AD Account)


## Currently only supports only these 10 agencies 
1. **ETA**

2. **OASAM**

3. **AE** (Advanced Engineering)

4. **ET** (Emerging Technology)

5. **EBSA**

6. **OSHA**

7. **MSHA**

8. **WHD**

9. **OWCP**

10. **OFCCP**

## Currently only supports these Environments (For User Creation)
 1. **COE-DEV**

 2. **COE-TEST**

 3. **COE-STAGE**


#### ChangeLog:
- 05/31/22 - Changed user create function to address SamAccountName ending with Period
- 07/05/22 - Added COE-TEST and STAGE svc. accounts  to the keystore and had some cosmetic changes
- 07/07/22 - Added Credential to address Token issues
- 07/19/2022 - Corrected VM Create function with correct variables

# Typical Usage Examples
**##### Always Run this Script from a Management Server using Elevated Account on Production**

## This is hardcoded to use SubscriptionID and Tenant for DOL AVD ..for anything different please call the script using Additional parameters AZsub and Tenant 

Please copy this script to a local folder such as (C:\Temp) and run from there (Instead of Running from the network share)

## for Creating AVD with User Account
      #.\Provision-UserAccountandAVD.ps1 -COEENV "COE-DEV" -ProvisioningMode "User_With_AVD"  -Agency OASAM -Ticket "CRQ165421" -Prodemail "LastName.FirstName@dol.gov"  -FedLeadEmail "UserLead@dol.gov"
	  
## for Creating AVD only (No User Account)

      #.\Provision-UserAccountandAVD.ps1 -COEENV "COE-DEV" -ProvisioningMode "AVD_Only"  -Agency OASAM -Ticket "CRQ165421" -Prodemail "LastName.FirstName@dol.gov"
	  
## for Creating User Account (No AVD)

      #.\Provision-UserAccountandAVD.ps1 -COEENV "COE-DEV" -ProvisioningMode "User_Only"  -Agency OASAM -Ticket "CRQ165421" -Prodemail "LastName.FirstName@dol.gov"  -FedLeadEmail "UserLead@dol.gov"


## for Bulk processing Accounts or Machines ..Define the AZ Credential and call it in the function ..Create CSV file with appropriate Headers
        $AZCred = Get-Credential -Message "Enter your Email and Password" #Put your Email and Password on Pop-Up
        $CSVFile with headers Agency,Ticket,ProdEmail,FedLeadEmail
        $objs = Import-csv $CSVFile
        foreach($obj in $objs){
          .\Provision-UserAccountandAVD.ps1 -COEENV "COE-DEV" -ProvisioningMode "User_With_AVD"  -Agency $obj.Agency -Ticket  $obj.Ticket -Prodemail  $obj.Prodemail  -FedLeadEmail $obj.FedLeademail -AZcred $azcred
         }
         
# For Azure Token Errors ..Please Try These 3 commands to Resolve the incorrect account tied up to the AZ cmdlets
	  Disconnect-AzAccount 
	  $Cred = Get-Credential #Put your Email and Password on Pop-Up
	  Connect-AzAccount -SubscriptionId "f03da233-2925-4557-b7cc-5f6200da4d49" -Force -WarningAction SilentlyContinue -Tenant "75a63054-7204-4e0c-9126-adab971d4aca" -Credential $cred
      
