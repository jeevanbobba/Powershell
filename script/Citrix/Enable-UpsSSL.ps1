<#
.SYNOPSIS
    Enable/Disable the TLS listeners on the UPS

.DESCRIPTION
    Enable or disable the TLS listeners on the UPS. 
    Optionally, the TLS certificate, port, version and cipher suite to use can be specified.

.PARAMETER Disable
    Disables the TLS listeners.
.PARAMETER Enable
    Enables the TLS listeners.
.PARAMETER HTTPPort
    Specifies the port to use for HTTP Web Service. Default is port 8080.
.PARAMETER CGPPort
    Specifies the port to use for Print Data Stream. Default is port 7229.    
.PARAMETER HTTPSPort
    Specifies the port to use for Encrypted (HTTPS) Web Service. Default is port 8443.
.PARAMETER CGPSSLPort
    Specifies the port to use for Encrypted Print Data Stream. Default is port 443.           
.PARAMETER SSLMinVersion
    Specifies the minimum TLS version to use (allowed values are TLS_1.0, TLS_1.1 and TLS_1.2).
    Default is TLS_1.2. 
.PARAMETER SSLCipherSuite
    Specifies the cipher suite to use (allowed values are GOV, COM and ALL). Default is ALL.
.PARAMETER CertificateThumbPrint
    Specifies the certificate SHA-1 thumbprint that identifies the certificate to use.
.PARAMETER ComplianceMode
    Specifies the security compliance mode to use (allowed values are OPEN and SP_800_52).
.PARAMETER FIPSMode
    Enables or disables FIPS 140 mode of operation. Default is false.

.EXAMPLE
    To disable the TLS listeners
    Enable-UpsSsl -Disable
.EXAMPLE
    To enable the TLS listeners
    Enable-UpsSsl -Enable
.EXAMPLE
    To enable TLS on the Web Service Port 4000 and the Print Data Stream (CGP) Port 5000
    Enable-UpsSsl -Enable -HTTPSPort 4000 -CGPSSLPort 5000
.EXAMPLE
    To enable the TLS listeners using TLS 1.2 with the GOV cipher suite
    Enable-UpsSsl -Enable -SSLMinVersion "TLS_1.2" -SSLCipherSuite "GOV"
.EXAMPLE
    To enable the TLS listeners using the specified computer certificate
    Enable-UpsSsl -Enable -CertificateThumbprint "373641446CCA0343D1D5C77EB263492180B3E0FD"
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
Param(
    [Parameter(Mandatory = $True, Position = 1, ValueFromPipeline = $False, ParameterSetName = "DisableMode")]
    [switch] $Disable,

    [Parameter(Mandatory = $True, Position = 1, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [switch] $Enable,

    [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
    [System.UInt16] $HTTPPort = 8080,

    [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
    [System.UInt16] $CGPPort = 7229,

    [Parameter(Mandatory = $False, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [System.UInt16] $HTTPSPort = 8443,

    [Parameter(Mandatory = $False, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [System.UInt16] $CGPSSLPort = 443,

    [Parameter(Mandatory = $false, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [ValidateSet("TLS_1.0", "TLS_1.1", "TLS_1.2")]
    [string] $SSLMinVersion = 'TLS_1.2',

    [Parameter(Mandatory = $false, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [ValidateSet("GOV", "COM", "ALL")]
    [string] $SSLCipherSuite = 'ALL',

    [Parameter(Mandatory = $false, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [string]$CertificateThumbPrint,

    [Parameter(Mandatory = $false, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [ValidateSet("OPEN", "SP_800_52")]
    [String] $ComplianceMode = 'OPEN',

    [Parameter(Mandatory = $false, ValueFromPipeline = $False, ParameterSetName = "EnableMode")]
    [bool] $FIPSMode = $false
)

#
# Enable-UpsSSL.ps1
# Copyright Citrix Systems, Inc.. All Rights Reserved.
#

Set-StrictMode -Version 2.0
$erroractionpreference = "Stop"

#Check if the user is an administrator
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Administrator rights are required to run this script.`nPlease re-run this script as an Administrator."
    break
}

#Write Header
Write-Host "Enable TLS to the UPS"
Write-Host "Running command Enable-UpsSsl to enable or disable TLS to the UPS."
Write-Host "This includes:"
Write-Host "`ta.Disable TLS to UPS or"
Write-Host "`tb.Enable TLS to UPS"
Write-Host "`t`t1.Setting ACLs"
Write-Host "`t`t2.Setting registry keys"
Write-Host "`t`t3.Configuring Firewall"
Write-Host ""
Write-Host ""

# Registry path constants 
$XTE_CONFIG_PATH = 'HKLM:\SOFTWARE\WOW6432Node\Citrix\XTEConfig'

$FirewallRule_Description = 'Inbound rule for Citrix Universal Print Server to communicate with client.'
$FirewallRuleGroup_DisplayName = 'Citrix Universal Print Server'

$UPServer_DisplayName = 'Citrix Universal Printing Service'
$UPServer_HomeDirPath = 'C:\Program Files (x86)\Citrix\Universal Print Server'
$UPServer_ProgramPath = Join-Path -Path $UPServer_HomeDirPath -ChildPath UPSERVER.EXE

$XTE_DisplayName = 'Citrix XTE Server'

$CGPPort_DisplayName = 'Citrix Universal Printing Data Service'
$CGPPort_DefaultValue = 7229

$HTTPPort_DisplayName = 'Citrix Universal Printing Web Service'
$HTTPPort_DefaultValue = 8080

$CGPSSLPort_DisplayName = 'Citrix Universal Printing Encrypted Data Service'
$CGPSSLPort_DefaultValue = 443

$HTTPSPort_DisplayName = 'Citrix Universal Printing Encrypted Web Service'
$HTTPSPort_DefaultValue = 8443

$HostName = ([System.Net.Dns]::GetHostByName((hostname)).HostName)

switch ($PSCmdlet.ParameterSetName) {
    "DisableMode" {
        if ($PSCmdlet.ShouldProcess("This will delete any existing firewall rules for encrypted Web Service and encrypted Data Service and add firewall rules for cleartext Web Service and cleartext Data Service.", "Are you sure you want to perform this action?`nThis will delete any existing firewall rules for encrypted Web Service and encrypted Data Service and add firewall rules for cleartext Web Service and cleartext Data Service.", "Configure Firewall")) {
            netsh advfirewall firewall delete rule name=$CGPSSLPort_DisplayName | Out-Null
            netsh advfirewall firewall delete rule name=$HTTPSPort_DisplayName  | Out-Null
            netsh advfirewall firewall delete rule name=$CGPPort_DisplayName  | Out-Null
            netsh advfirewall firewall delete rule name=$HTTPPort_DisplayName  | Out-Null
            netsh advfirewall firewall add rule name=$CGPPort_DisplayName dir=in action=allow profile=any protocol=tcp description=$FirewallRule_Description localport=$CGPPort | Out-Null
            netsh advfirewall firewall add rule name=$HTTPPort_DisplayName dir=in action=allow profile=any protocol=tcp description=$FirewallRule_Description localport=$HTTPPort | Out-Null
        }
        else {
            Write-Host "Firewall configuration skipped."
        }

        #Turning off SSL by setting SSLOn registry value to 0
        foreach ($registryValueName in 'Certificate', 'Protocol', 'CipherSuite', 
            'ComplianceMode', 'FIPS140Mode', 'SSLPort', 
            'CGPSSLPort', 'CertServer') {
            Remove-ItemProperty -Path $XTE_CONFIG_PATH -name $registryValueName -Confirm:$False -ErrorAction SilentlyContinue
        }
        Set-ItemProperty -Path $XTE_CONFIG_PATH -name SSLOn -Value 0 -Type DWord -Confirm:$false
 
        Write-Host "TLS to UPS has been disabled."
    }

    "EnableMode" {
        $RegistryKeysSet = $ACLsSet = $FirewallConfigured = $False
        $serviceACLs = @(
            @{ serviceName = $UPServer_DisplayName; userName = 'LocalService'; ACLsSet = $false },
            @{ serviceName = $XTE_DisplayName; userName = 'NetworkService'; ACLsSet = $false }
        )

        $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
        try {                
            $Store.Open("ReadOnly")
        
            if ($Store.Certificates.Count -eq 0) {
                Write-Host "No certificates found in the Personal Local Machine Certificate Store. Please install a certificate and try again."
                Write-Host "`nEnabling TLS to UPS failed."
                break
            }
            elseif ($Store.Certificates.Count -eq 1) {
                if ($CertificateThumbPrint) {
                    $Certificate = $Store.Certificates[0]
                    $Thumbprint = $Certificate.GetCertHashString()
                    if ($Thumbprint -ne $CertificateThumbPrint) {
                        Write-Host "No certificate found in the certificate store with thumbprint $CertificateThumbPrint"
                        Write-Host "`nEnabling TLS to UPS failed."
                        break
                    }
                }
                else {
                    $Certificate = $Store.Certificates[0]
                }
            }
            elseif ($CertificateThumbPrint) {
                $Certificate = $Store.Certificates | Where-Object {$_.GetCertHashString() -eq $CertificateThumbPrint}
                if (!$Certificate) {
                    Write-Host "No certificate found in the certificate store with thumbprint $CertificateThumbPrint"
                    Write-Host "`nEnabling TLS to UPS failed."
                    break
                }
                # $Certificate is either an array or X509Certificate2
                if ($Certificate -is [array]) {
                    $Certificate = $Certificate[0]
                }
            }
            else {
                $ComputerName = 'CN=' + $HostName
                $CommonNameRegex = '(?i)' + [System.Text.RegularExpressions.Regex]::Escape($ComputerName) + ',?'
                $Certificate = $Store.Certificates | Where-Object {$_.Subject -match $CommonNameRegex }
                if (!$Certificate) {
                    Write-Host "No certificate found in the certificate store with Subject $ComputerName, please specify the thumbprint using -CertificateThumbPrint option."
                    Write-Host "`nEnabling TLS to UPS failed."
                    break
                }
                # $Certificate is either an array or X509Certificate2                
                if ($Certificate -is [array]) {
                    $Certificate = $Certificate[0]
                }
            }
                
            #Validate the certificate
            Write-Host "`nSelected TLS Server Certificate:`n$Certificate`n"

            #Validate expiration date                        
            $UtcNow = [DateTime]::UtcNow
            if (($UtcNow -lt $Certificate.NotBefore) -or ($UtcNow -gt $Certificate.NotAfter)) {
                Write-Host "The certificate is expired. Please install a valid certificate and try again."
                Write-Host "`nEnabling TLS to UPS failed."
                break
            }

            #Check certificate trust
            if (!$Certificate.Verify()) {
                Write-Host "Verification of the certificate failed. Please install a valid certificate and try again."
                Write-Host "`nEnabling TLS to UPS failed."
                break
            }

            #Check private key availability
            try {
                [System.Security.Cryptography.AsymmetricAlgorithm] $PrivateKey = $Certificate.PrivateKey 
                $UniqueContainer = ((($Certificate).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
            }
            catch {
                Write-Host "Unable to access the Private Key of the Certificate or one of its fields."
                Write-Host "`nEnabling TLS to UPS failed."
                break
            }

            if (!$PrivateKey -or !$UniqueContainer) {
                Write-Host "Unable to access the Private Key of the Certificate or one of its fields."
                Write-Host "`nEnabling TLS to UPS failed."
                break
            }

            foreach ($service in $serviceACLs) {
                if ($PSCmdlet.ShouldProcess("This will grant $($service['serviceName']) read and execute access to the private key.", 
                "Are you sure you want to perform this action?`nThis will grant $($service['serviceName']) read access to the private key.", 
                "Configure ACLs for $($service['serviceName'])")) {
                    $KeyContainerName = ((($Certificate).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
                    $dir = Join-Path -Path $env:ProgramData -ChildPath '\Microsoft\Crypto\RSA\MachineKeys\'
                    $keypath = Join-Path -Path $dir -ChildPath $KeyContainerName
                    icacls $keypath /grant `"$($service['userName'])`"`:RX | Out-Null
                    Write-Host "ACLs set."
                    Write-Host ""
                    $service['ACLsSet'] = $True
                }
                else {
                    Write-Host "ACL configuration for $($service['serviceName']) skipped."
                }    
            }


            if ($PSCmdlet.ShouldProcess("This will delete any existing firewall rules for ports $HTTPSPort,$CGPSSLPort and disable rules for HTTP and CGP services.", "Are you sure you want to perform this action?`nThis will delete any existing firewall rules for ports $HTTPSPort,$CGPSSLPort and disable rules for HTTP and CGP services.", "Configure Firewall")) {
                netsh advfirewall firewall delete rule name=$CGPSSLPort_DisplayName | Out-Null
                netsh advfirewall firewall delete rule name=$HTTPSPort_DisplayName  | Out-Null
                netsh advfirewall firewall delete rule name=$CGPPort_DisplayName  | Out-Null
                netsh advfirewall firewall delete rule name=$HTTPPort_DisplayName  | Out-Null                
                netsh advfirewall firewall add rule name=$CGPSSLPort_DisplayName dir=in action=allow profile=any protocol=tcp description=$FirewallRule_Description localport=$CGPSSLPort | Out-Null
                netsh advfirewall firewall add rule name=$HTTPSPort_DisplayName dir=in action=allow profile=any protocol=tcp description=$FirewallRule_Description localport=$HTTPSPort | Out-Null    
                Write-Host "Firewall configured."
                $FirewallConfigured = $True
            }
            else {
                Write-Host "Firewall configuration skipped."
            }

            # Create registry keys to enable SSL to the UPS
            Write-Host "Setting registry keys..."
            Set-ItemProperty -Path $XTE_CONFIG_PATH -name Certificate -Value $Certificate.GetCertHashString() -Type String -Confirm:$False 
            switch ($SSLMinVersion) {
                "TLS_1.0" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name Protocol -Value 'TLSv1' -Type String -Confirm:$False
                }
                "TLS_1.1" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name Protocol -Value 'TLSv1.1' -Type String -Confirm:$False
                }
                "TLS_1.2" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name Protocol -Value 'TLSv1.2' -Type String -Confirm:$False
                }
            }

            switch ($SSLCipherSuite) {
                "GOV" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name CipherSuite -Value 'GOV' -Type String -Confirm:$False
                }    
                "COM" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name CipherSuite -Value 'COM' -Type String -Confirm:$False
                }
                "ALL" { 
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name CipherSuite -Value 'ALL' -Type String -Confirm:$False
                }
            }

            switch ($ComplianceMode) {
                "OPEN" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name ComplianceMode -Value 0 -Type DWord -Confirm:$False
                }    
                "SP800_52" {
                    Set-ItemProperty -Path $XTE_CONFIG_PATH -name ComplianceMode -Value 1 -Type DWord -Confirm:$False
                }
            }

            if ($FIPSMode) {
                Set-ItemProperty -Path $XTE_CONFIG_PATH -name FIPS140Mode -Value 1 -Type DWord -Confirm:$False
            } else {
                Set-ItemProperty -Path $XTE_CONFIG_PATH -name FIPS140Mode -Value 0 -Type DWord -Confirm:$False
            }            

            Set-ItemProperty -Path $XTE_CONFIG_PATH -name SSLPort -Value $HTTPSPort -Type DWord -Confirm:$False
            Set-ItemProperty -Path $XTE_CONFIG_PATH -name CGPSSLPort -Value $CGPSSLPort -Type DWord -Confirm:$False
            Set-ItemProperty -Path $XTE_CONFIG_PATH -name CertServer -Value $HostName -Type String -Confirm:$false
            Set-ItemProperty -Path $XTE_CONFIG_PATH -name SSLOn -Value 1 -Type DWord -Confirm:$False
        
            Write-Host "Registry keys set."
            Write-Host ""
            $RegistryKeysSet = $True
        }
        finally {
            $Certificate = $null
            $PrivateKey = $null
            $Store.Close()
        }

        $ACLsSet = $true
        foreach ($service in $serviceACLs) {
            $ACLsSet = $ACLsSet -and $service['ACLsSet']
        }
        
        if ($RegistryKeysSet -and $ACLsSet -and $FirewallConfigured) {
            Write-Host "`nTLS to UPS enabled.`n"
        }
        else {
            Write-Host "`n"

            if (!$RegistryKeysSet) {
                Write-Host "Configure registry manually or re-run the script to complete enabling TLS to UPS."
            }

            if (!$ACLsSet) {
                Write-Host "Configure ACLs manually or re-run the script to complete enabling TLS to UPS."
            }
                    
            if (!$FirewallConfigured) {
                Write-Host "Configure firewall manually or re-run the script to complete enabling TLS to UPS."
            }
        }
    }
}

# SIG # Begin signature block
# MIIa0AYJKoZIhvcNAQcCoIIawTCCGr0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUvu1Ahm95p8CXiuiZDg1EHXVA
# kEmgghTsMIIFJDCCBAygAwIBAgIQCpJdJFWANibhh6AFcJolkDANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgVGltZXN0YW1waW5nIENBMB4XDTE4MDgwMTAwMDAwMFoXDTIzMDkw
# MTAwMDAwMFowYDELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFENpdHJpeCBTeXN0ZW1z
# LCBJbmMuMQ0wCwYDVQQLEwRHTElTMSMwIQYDVQQDExpDaXRyaXggVGltZXN0YW1w
# IFJlc3BvbmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANjWtJ4e
# cpVfB34YnxfYNvb1Rp2JbBu5/G9Boe8aEBQc2zidW82ousZrXj2QD2qUA1Ee8noo
# t1KGcQdY0WzzbSIU7KHePB5KaESWjtHVJ3BW6W9q+U24m2dPD/oaNxGx6DtD7M0N
# lMBIRZKo7aNIsRIlHkg7wnNQzqi0jTkzBO7S34holaqhfuQgqkgKqGmcoSIXVqNm
# EFaU+5kpYFqpMo6x1sSAgfgNEcIgGjnj8xzdU1rnh6iNYMxOt8guMWk2z+KKNbux
# H6YLAA9VBYW417Zf153/5L4ejuxxUhCp03JkoUIWjSRjz3m24HD9K8NSgJ0AdDpN
# E8ZPmIJCMFi9FYcCAwEAAaOCAcYwggHCMB8GA1UdIwQYMBaAFPS24SAd/imu0uRh
# pbKiJbLIFzVuMB0GA1UdDgQWBBS1Y37AhXUHPaYuvS/SUsWFFisSbTAMBgNVHRMB
# Af8EAjAAMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBP
# BgNVHSAESDBGMDcGCWCGSAGG/WwHATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3
# dy5kaWdpY2VydC5jb20vQ1BTMAsGCWCGSAGG/WwDFTBxBgNVHR8EajBoMDKgMKAu
# hixodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLXRzLmNybDAy
# oDCgLoYsaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5j
# cmwwgYUGCCsGAQUFBwEBBHkwdzAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tME8GCCsGAQUFBzAChkNodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRTSEEyQXNzdXJlZElEVGltZXN0YW1waW5nQ0EuY3J0MA0GCSqG
# SIb3DQEBCwUAA4IBAQBrQ4tHgdu37madmYML6Ikfb8bNWoritioGcrlVfsMEGdLN
# LAsPYqrMo9mZmNzKTE7UVzGVdwb+Cfz9IRfD6hmK6hhEuom+XNzC8LGQ3o7U2ede
# YF/xuIcFZAwmQnXOoVl4yDWKrfyalOIO9wpQ6bDV7f0CPa8j3Qj2eNJ2u2qKnRE+
# x5Iz8j5lsjQeefIriGVHd27R93ai0li9WZMT9KKOAk06R0Z0qyG70jXhoUp4Or5c
# lv5mmVJgmxr1hMjVg7v95WGY50p2+cfhqLlViu2cu0LCg31IUb0lbTYNbgY1eca2
# cr8F0ppVnrt55YVfb1M80huj9DeYYjeFSKkcN+6xMIIFMDCCBBigAwIBAgIQBAkY
# G1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQw
# IgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIw
# MDAwWhcNMjgxMDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhE
# aWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrb
# RPV/5aid2zLXcep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdglrA55KDp+6dFn08b7
# KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRniolF1C2ho+mILCCV
# rhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXp
# dOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWO
# D8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IB
# zTCCAckwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1Ud
# HwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0gBEgwRjA4BgpghkgB
# hv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9D
# UFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8G
# A1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IB
# AQA+7A1aJLPzItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew
# 4fbRknUPUbRupY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQGivecRk5c/5CxGwcO
# kRX7uq+1UcKNJK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEehemhor5unXCBc2XGx
# DI+7qPjFEmifz0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJRZboWR3p+nRka7Lr
# ZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiF
# LpKR6mhsRDKyZqHnGKSaZFHvMIIFMTCCBBmgAwIBAgIQCqEl1tYyG35B5AXaNpfC
# FTANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdp
# Q2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTYwMTA3MTIwMDAwWhcNMzEwMTA3
# MTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEy
# IEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAvdAy7kvNj3/dqbqCmcU5VChXtiNKxA4HRTNREH3Q+X1NaH7n
# tqD0jbOI5Je/YyGQmL8TvFfTw+F+CNZqFAA49y4eO+7MpvYyWf5fZT/gm+vjRkcG
# GlV+Cyd+wKL1oODeIj8O/36V+/OjuiI+GKwR5PCZA207hXwJ0+5dyJoLVOOoCXFr
# 4M8iEA91z3FyTgqt30A6XLdR4aF5FMZNJCMwXbzsPGBqrC8HzP3w6kfZiFBe/WZu
# VmEnKYmEUeaC50ZQ/ZQqLKfkdT66mA+Ef58xFNat1fJky3seBdCEGXIX8RcG7z3N
# 1k3vBkL9olMqT4UdxB08r8/arBD13ays6Vb/kwIDAQABo4IBzjCCAcowHQYDVR0O
# BBYEFPS24SAd/imu0uRhpbKiJbLIFzVuMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1R
# i6enIZ3zbcgPMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMG
# A1UdJQQMMAoGCCsGAQUFBwMIMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGB
# BgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMFAGA1UdIARJMEcwOAYK
# YIZIAYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAQEAcZUS6VGHVmnN
# 793afKpjerN4zwY3QITvS4S/ys8DAv3Fp8MOIEIsr3fzKx8MIVoqtwU0HWqumfgn
# oma/Capg33akOpMP+LLR2HwZYuhegiUexLoceywh4tZbLBQ1QwRostt1AuByx5jW
# PGTlH0gQGF+JOGFNYkYkh2OMkVIsrymJ5Xgf1gsUpYDXEkdws3XVk4WTfraSZ/tT
# YYmo9WuWwPRYaQ18yAGxuSh1t5ljhSKMYcp5lH5Z/IwP42+1ASa2bKXuh1Eh5Fhg
# m7oMLSttosR+u8QlK0cCCHxJrhO24XxCQijGGFbPQTS2Zl22dHv1VjMiLyI2skui
# SpXY9aaOUjCCBVcwggQ/oAMCAQICEA5SwjVXc07EY1PSyXDjKx8wDQYJKoZIhvcN
# AQELBQAwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBB
# c3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTAeFw0yMTA0MjgwMDAwMDBaFw0yMzA1
# MDMyMzU5NTlaMIGUMQswCQYDVQQGEwJVUzEQMA4GA1UECBMHRmxvcmlkYTEYMBYG
# A1UEBxMPRm9ydCBMYXVkZXJkYWxlMR0wGwYDVQQKExRDaXRyaXggU3lzdGVtcywg
# SW5jLjEbMBkGA1UECxMSWGVuQXBwKFBvd2Vyc2hlbGwpMR0wGwYDVQQDExRDaXRy
# aXggU3lzdGVtcywgSW5jLjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# ALqU69rRrQR5G6LXw3BRk644qamIX1oTGmWacWkYHRI6B8dn5hfK2Doaw7KxzKkj
# 05V902fKg2Sf2IJpKlTX9c1HJ9fFQasTZTsw9xESEybANuZNzgzJcnsc1TQwLoKH
# 9WSv4DUiaJCrheh4YICeafPrhojZRgFsiOUFDMXYFmeRwn9j6/o8SUrf+E3Um9T9
# cIgDtYgJgLvLf5nY1qftiMGJ+hLhlz9LDAUbsESL/uC0fkUXcjbbXyxmWKZ2SpS3
# YLZlxgehSqilmk0OYAQi4sIkLvwKEMYrsk7QQv+IQBmVveZkHxZqR9P/uhRtlREb
# GzDFuVYxy7kqYqKPNI2yRSECAwEAAaOCAcQwggHAMB8GA1UdIwQYMBaAFFrEuXsq
# CqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBS7iHme24LPbr20oCMccD2IWSJyGTAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1
# oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1n
# MS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3Vy
# ZWQtY3MtZzEuY3JsMEsGA1UdIAREMEIwNgYJYIZIAYb9bAMBMCkwJwYIKwYBBQUH
# AgEWG2h0dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsG
# AQUFBwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# ME4GCCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRTSEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADAN
# BgkqhkiG9w0BAQsFAAOCAQEAMphWU/pi+dVNcVAIc489Z16RLtzJgZjfLM1trtDI
# 9wtYK+33CLBM7QhW+EL3bt5cFcqbmzlSQ7gH7uAmOOW/eUX4WyFcvEyVYu2aJg1/
# ML0f4JeCe1KQeGbRFjoYvC/5tUYuAEb/9Z7Nc3INtMjL4uhO67VrKlxHFKJOoDks
# AeeKRwhBBQP7Ga8odNXJxSA79s7NrDBUo5HNKc3R2I1N4jASYAfUNhee9H/8Kp85
# B/8+f2zNBpwJUs3ZdRSU0gH5okbw8OP8J4UPfolsRhPJ1+Kz6R/fVScud6VTLYFz
# iRJzdo1asGUJ9OxEh9u31bJcC0W9t6zSWcNgzu4ZT//q3zGCBU4wggVKAgEBMIGG
# MHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJl
# ZCBJRCBDb2RlIFNpZ25pbmcgQ0ECEA5SwjVXc07EY1PSyXDjKx8wCQYFKw4DAhoF
# AKCBnDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqfL2sGslnvWXJkkFs2vk6vxP
# kUMwPAYKKwYBBAGCNwIBDDEuMCygEIAOAFMAYwByAGkAcAB0AHOhGIAWaHR0cDov
# L3d3dy5jaXRyaXguY29tIDANBgkqhkiG9w0BAQEFAASCAQBpi4SzxGXBje4KDBWH
# +o4DKy9INVRlhgDUT7xBlbcl6u97Omd+21SHB7UUJD3J16WB1ZS9n75NjKpQKymg
# 4+hHmD4x/fTmNmNEubPAEOsM82+PARh7nN0Gs4ITB/B92dQ30t+i4xbGDE+yReIj
# aQPKhN4x+ZgV4WxX53L/OjSXYWrbeEJ46xuV6b5RO9P3ykOphkWUXY8hp38NWb3I
# JCqZLNeac3CxhmHhu5FzMZndk7QlSj5wDO00FXc1nlES+Nq5mSIF7RQyY9+Fge0l
# X0hi7Zxx+n/xdVwSkCvLRJQ7j2Lil7i1+pCpgpcqimzxu/6JLLeAvP/jnOG8s/10
# mJSBoYIC/TCCAvkGCSqGSIb3DQEJBjGCAuowggLmAgEBMIGGMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3Rh
# bXBpbmcgQ0ECEAqSXSRVgDYm4YegBXCaJZAwDQYJYIZIAWUDBAIBBQCgggE0MBgG
# CSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIyMDIyMTEw
# MjAxNVowLwYJKoZIhvcNAQkEMSIEIBW9UViJX6PBtYzf6iuMrTemFgNn9wtZJxuG
# T+dQleV1MIHIBgsqhkiG9w0BCRACLzGBuDCBtTCBsjCBrwQgsCrO26Gy12Ws1unF
# BnpWG9FU4YUyDBzPXmMmtqVvLqMwgYowdqR0MHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EC
# EAqSXSRVgDYm4YegBXCaJZAwDQYJKoZIhvcNAQEBBQAEggEALigPnczRtQcLzLGp
# TK3LC6rrkCLMlRLUUxY5+S+G3U0uXxfoZlRTxY4rkJvJx6GAQ42rYYOtL70m4nhA
# DhLtQzK0MTjmdfB2CFVtIfSw4EqBvuJQ8EM3IOdcBm7V+Q5lEenSXTWR0j0K/WIF
# 4BTWhErjb6D3Svb/Rwd1X81/RGxEEtQumND9dAaJenVR7dXlntIM9mBa1+dy8+QH
# QsbISdNvlsr77vTArlrzNiZ0ik4f6pwqq3TWaBwiUNs2GIU+qFumaGDlxKQ8rnkc
# pk97rxhzFwVMdjHQ0Emah+5cDAvH+Zvie40xfqPfnW3isZn73IfIiSjmt0mm2xNw
# 3U9utA==
# SIG # End signature block
