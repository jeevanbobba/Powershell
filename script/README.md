What does the Script do ?

    The Script will validate a random certificate (certs folder is populated with a list of Public Key Cert’s from DC’s and other individuals PIV cert) and performs the following 

•	Check to see if the randomly selected Certificate is valid and Issued by the Entrust SSP Intermediate CA
•	Runs the OCSP check( to validate the Hash, Integrity and Revocation )  and validate the chain using CERTUTIL 
•	Captures and extracts the results(along with additional checks)  and convert into a PowerShell object
•	Runs the OCSP check and validate the chain using OPENSSL (CERTUTIL will not give the OCSP response output)
•	Repeats the above process for External Entrust connection(Changes the HOSTS file to simulate connection without VPN) and Test OCSP appliance as well
•	Deletes the temporary responses cached on the local drive due to CERTUTIL and OPENSSL operations
•	Appends the output to a CSV and end of the day it is converted to an Excel file and archived as year/month/day Report
•	On verification failure it alerts SMS to a list of folks specified as well in addition to the windows DL 
•	When issuing a failure notification email , script will also capture the Message ID ,that can be later used to track delivery of the report (in case of USI)
•	Removes all Variables and clears 

Whom does it Notify ?

             zzOASAM-OCIO-ITOS-Ops-Windows-Admins only on Certification verification failure  (Across any OCSP route i.e., Internal, External or Test)

Where and When does it run ?

              The Script is running in DC1VWCTXDIRP01 and is running every 5 minutes under System Account as a Scheduled Task

What are the pre-requisites?
           
1.	OpenSSL (Installed from Free OpenSSL Binaries and Installer for Microsoft Windows (firedaemon.com)
2.	PowerShell 5.1 or later
3.	PowerShell modules (IMPORTEXCEL,MAILOZAURR) Need for converting to Excel and sending email (for HTML and Message ID Capture)
    
How are errors in the script monitored ?
       
              There are garbage collections and logics than are able to catch  the condition and report it in the output .Currently there was not an automated PESTER or other automated tests built into this script . May be at some point they will be developed. The Script is still open for suggestions and improvement 
      
How can I get a copy of the Script ?

              https://gitlab.dol.gov/WindowsAdminTeam/script/-/raw/main/OCSP-CertUtil-Test.ps1 

What does this Script will not solve?

World hunger 😊
  I believe we have met the requirement and this script will address the requirement for an automated OCSP verification and alerting to validate the automated OCSP downloads
