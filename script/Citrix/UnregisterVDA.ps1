###########################################################################
###########################################################################
###  UNREGISTERVDA.PS1                                                  ###
###                                                                     ###
###  INPUTS                                                             ###
###     -- VERBOSELOGGING                                               ###
###        SET TO TRUE FOR WRITING OUTPUT TO THE CONSOLE                ###
###        SET TO $FALSE FOR SILENT OPERATION                           ###
###                                                                     ###
###  PROCESSING                                                         ###
###     -- DETERMINES OS AND BITNESS FOR XP OPERATING SYSTEMS ONLY      ###
###     -- DETERMINES WHETHER THE VDA IS INSTALLED                      ###
###     -- DETERMINES WHETHER THE LIST OF DDCS HAS BEEN SET IN REGISTRY ###
###     -- IF DDCS LIST IS NOT EMPTY, THEN CLEAR THE VALUES             ###
###                                                                     ###
###########################################################################
###                                                                     ###
###  INPUTS:                                                            ###
     $VERBOSELOGGING = $false;
###                                                                     ###
###                                                                     ###
###########################################################################

#Determine OS
$OSVERSION=(get-wmiobject win32_operatingsystem).Version;

#Determine Bitness
$OSBITNESS=(get-wmiobject win32_operatingsystem).OSArchitecture;

#IF NOT SUPPORTED THEN HALT; WRITE ERROR
if($OSVERSION -ne '5.1.2600' -and $OSVERSION -ne '5.2.3790') `
{
   if ($VERBOSELOGGING -eq $true) {Write-Host 'ERROR - This test is only designed for XP32 and XP64' }
} 
   else 
{
   if ($VERBOSELOGGING -eq $true) {Write-host 'Valid operating system, proceeding with UNREGISTER...' }
}

#CHECK IF LIST OF DDCS REGISTRY KEY EXISTS

$c = Test-Path -Path "HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent"
if ($c -eq $false) `
{ 
   IF ($VERBOSELOGGING -eq $true) {write-Host 'ERROR - The VDA is not installed'};	
} 
ELSE `
{ 
   IF ($VERBOSELOGGING -EQ $true) {Write-Host "Previous list of DDCs found... Removing..." }
   $d = (Get-ItemProperty "HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent").ListOfDDCs ;

   #IF EXIST THEN DELETE CONTENTS OF REGISTRY
   IF ($d -ne "") `
   {
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent" -Name ListOfDDCs -Value ""
      $e = (Get-ItemProperty "HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent").ListOfDDCs 
      IF ($e -ne "") `
      {
         IF ($VERBOSELOGGING -eq $true) {Write-Host "There was an error writing to Registry Key HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent";}
      }
      ELSE
      {
         IF ($VERBOSELOGGING -eq $true) {Write-Host "The Registriy Key has been RESET to an UNCONFIGURED state";}
      }
   }
   ELSE `
   {
      IF ($VERBOSELOGGING -eq $true) {Write-Host "The registry is blank.  No operation performed"};
   }
}



