<#
.SYNOPSIS
    Enable/Disable the TLS/DTLS listeners on the VDA

.DESCRIPTION
    Enable or disable the TLS/DTLS listeners on the VDA. 
    Optionally, the TLS/DTLS certificate, port, version and cipher suite to use can be specified.

.PARAMETER Disable
    Disables the TLS/DTLS listeners.
.PARAMETER Enable
    Enables the TLS/DTLS listeners.
.PARAMETER SSLPort
    Specifies the port to use. Default is port 443.
.PARAMETER SSLMinVersion
    Specifies the minimum TLS/DTLS version to use (allowed values are SSL_3.0, TLS_1.0, TLS_1.1 and TLS_1.2).
    Default is TLS_1.0. 
.PARAMETER SSLCipherSuite
    Specifies the cipher suite to use (allowed values are GOV, COM and ALL). Default is ALL.
.PARAMETER CertificateThumbPrint
    Specifies the certificate thumbprint to identify the certificate to use. Default is the certificate that
    matches the FQDN of the VDA.

.EXAMPLE
    To disable the TLS/DTLS listeners
    Enable-VdaSSL -Disable
.EXAMPLE
    To enable the TLS/DTLS listeners
    Enable-VdaSSL -Enable
.EXAMPLE
    To enable the TLS/DTLS listeners on port 4000
    Enable-VdaSSL -Enable -SSLPort 4000
.EXAMPLE
    To enable the TLS/DTLS listeners using TLS 1.2 with the GOV cipher suite
    Enable-VdaSSL -Enable -SSLMinVersion "TLS_1.2" -SSLCipherSuite "GOV"
.EXAMPLE
    To enable the TLS/DTLS listeners using the specified computer certificate
    Enable-VdaSSL -Enable -CertificateThumbprint "373641446CCA0343D1D5C77EB263492180B3E0FD"
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
Param(
    [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$False, ParameterSetName = "DisableMode")]
    [switch] $Disable,

    [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$False, ParameterSetName = "EnableMode")]
    [switch] $Enable,
    
    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ParameterSetName = "EnableMode")]
    [int] $SSLPort = 443,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ParameterSetName = "EnableMode")]
    [ValidateSet("SSL_3.0", "TLS_1.0", "TLS_1.1", "TLS_1.2")]
    [String] $SSLMinVersion = "TLS_1.0",

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ParameterSetName = "EnableMode")]
    [ValidateSet("GOV", "COM", "ALL")]
    [String] $SSLCipherSuite = "ALL",

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ParameterSetName = "EnableMode")]
    [string]$CertificateThumbPrint 
    )

    Set-StrictMode -Version 2.0
    $erroractionpreference = "Stop"

    #Check if the user is an administrator
    if(!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Host "You do not have Administrator rights to run this script.`nPlease re-run this script as an Administrator."
        break
    }

    #Write Header
    Write-Host "Enable TLS/DTLS to the VDA"
    Write-Host "Running command Enable-VdaSSL to enable or disable TLS/DTLS to the VDA."
    Write-Host "This includes:"
    Write-Host "`ta.Disable TLS/DTLS to VDA or"
    Write-Host "`tb.Enable TLS/DTLS to VDA"
    Write-Host "`t`t1.Setting ACLs"
    Write-Host "`t`t2.Setting registry keys"
    Write-Host "`t`t3.Configuring Firewall"
    Write-Host ""
    Write-Host ""

    # Registry path constants 
    $ICA_LISTENER_PATH = 'HKLM:\system\CurrentControlSet\Control\Terminal Server\Wds\icawd'
    $ICA_CIPHER_SUITE = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman'
    $DHEnabled = 'Enabled'
    $BACK_DHEnabled = 'Back_Enabled'
    $ENABLE_SSL_KEY = 'SSLEnabled'
    $SSL_CERT_HASH_KEY = 'SSLThumbprint'
    $SSL_PORT_KEY = 'SSLPort'
    $SSL_MINVERSION_KEY = 'SSLMinVersion'
    $SSL_CIPHERSUITE_KEY = 'SSLCipherSuite'

    $POLICIES_PATH = 'HKLM:\SOFTWARE\Policies\Citrix\ICAPolicies'
    $ICA_LISTENER_PORT_KEY = 'IcaListenerPortNumber'
    $SESSION_RELIABILITY_PORT_KEY = 'SessionReliabilityPort'
    $WEBSOCKET_PORT_KEY = 'WebSocketPort'

    #Read ICA, CGP and HTML5 ports from the registry
    try
    {
        $IcaPort = (Get-ItemProperty -Path $POLICIES_PATH -Name $ICA_LISTENER_PORT_KEY).IcaListenerPortNumber
    }
    catch
    {
        $IcaPort = 1494
    }

    try
    {
        $CgpPort = (Get-ItemProperty -Path $POLICIES_PATH -Name $SESSION_RELIABILITY_PORT_KEY).SessionReliabilityPort
    }
    catch
    {
        $CgpPort = 2598
    }

    try
    {
        $Html5Port = (Get-ItemProperty -Path $POLICIES_PATH -Name $WEBSOCKET_PORT_KEY).WebSocketPort
    }
    catch
    {
        $Html5Port = 8008
    }

    if (!$IcaPort)
    {
        $IcaPort = 1494
    }
    if (!$CgpPort)
    {
        $CgpPort = 2598
    }
    if (!$Html5Port)
    {
        $Html5Port = 8008
    }

    # Determine the name of the ICA Session Manager
    if (Get-Service | Where-Object {$_.Name -eq 'porticaservice'}) 
    {
        $username = 'NT SERVICE\PorticaService'
        $serviceName = 'PortIcaService'
    }
    else
    {
        $username = 'NT SERVICE\TermService'
        $serviceName = 'TermService'
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        "DisableMode"
        {
            #Replace Diffie-Hellman Enabled value to its original value
            if (Test-Path $ICA_CIPHER_SUITE)
            {
                $back_enabled_exists = Get-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -ErrorAction SilentlyContinue
                if ($back_enabled_exists -ne $null)
                {
                    Set-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value $back_enabled_exists.Back_Enabled
                    Remove-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled
                }
            }

            if ($PSCmdlet.ShouldProcess("This will delete any existing firewall rules for Citrix SSL Service and enable rules for ICA, CGP and Websocket services.", "Are you sure you want to perform this action?`nThis will delete any existing firewall rules for Citrix SSL Service and enable rules for ICA, CGP and Websocket services.", "Configure Firewall"))
            {
                #Enable any existing rules for ICA, CGP and HTML5 ports
                netsh advfirewall firewall add rule name="Citrix ICA Service"        dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$IcaPort | Out-Null
                netsh advfirewall firewall add rule name="Citrix CGP Server Service" dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$CgpPort | Out-Null
                netsh advfirewall firewall add rule name="Citrix Websocket Service"  dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$Html5Port | Out-Null

                #Enable existing rules for UDP-ICA, UDP-CGP 
                netsh advfirewall firewall add rule name="Citrix ICA UDP" dir=in action=allow service=$serviceName profile=any protocol=udp localport=$IcaPort | Out-Null
                netsh advfirewall firewall add rule name="Citrix CGP UDP" dir=in action=allow service=$serviceName profile=any protocol=udp localport=$CgpPort | Out-Null

                #Delete any existing rules for Citrix SSL Service
                netsh advfirewall firewall delete rule name="Citrix SSL Service" | Out-Null

                #Delete any existing rules for Citrix DTLS Service
                netsh advfirewall firewall delete rule name="Citrix DTLS Service" | Out-Null
            }
            else
            {
                Write-Host "Firewall configuration skipped."
            }

            #Turning off SSL by setting SSLEnabled key to 0
            Set-ItemProperty -Path $ICA_LISTENER_PATH -name $ENABLE_SSL_KEY -Value 0 -Type DWord -Confirm:$false

            Write-Host "SSL to VDA has been disabled."
        }

        "EnableMode"
        {
            $RegistryKeysSet = $ACLsSet = $FirewallConfigured = $False

            $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
            $Store.Open("ReadOnly")
        
            if ($Store.Certificates.Count -eq 0)
            {
                Write-Host "No certificates found in the Personal Local Machine Certificate Store. Please install a certificate and try again."
                Write-Host "`nEnabling SSL to VDA failed."
                $Store.Close()
                break
            }
            elseif ($Store.Certificates.Count -eq 1)
            {
                if ($CertificateThumbPrint)
                {
                    $Certificate = $Store.Certificates[0]
                    $Thumbprint = $Certificate.GetCertHashString()
                    if ($Thumbprint -ne $CertificateThumbPrint)
                    {
                        Write-Host "No certificate found in the certificate store with thumbprint $CertificateThumbPrint"
                        Write-Host "`nEnabling SSL to VDA failed."
                        $Store.Close()
                        break
                    }
                }
                else
                {
                    $Certificate = $Store.Certificates[0]
                }
            }
            elseif ($CertificateThumbPrint)
            {
                $Certificate = $Store.Certificates | where {$_.GetCertHashString() -eq $CertificateThumbPrint}
                if (!$Certificate)
                {
                    Write-Host "No certificate found in the certificate store with thumbprint $CertificateThumbPrint"
                    Write-Host "`nEnabling SSL to VDA failed."
                    $Store.Close()
                    break
                }
            }
            else
            {
                $ComputerName = "CN="+[System.Net.Dns]::GetHostByName((hostname)).HostName+","
                $Certificate = $Store.Certificates | where {$_.Subject -match $ComputerName}
                if (!$Certificate)
                {
                    Write-Host "No certificate found in the certificate store with Subject $ComputerName, please specify the thumbprint using -CertificateThumbPrint option."
                    Write-Host "`nEnabling SSL to VDA failed."
                    $Store.Close()
                    break
                }
            }
                
            #Validate the certificate

            #Validate expiration date
            $ValidTo = [DateTime]::Parse($Certificate.GetExpirationDateString())
            if($ValidTo -lt [DateTime]::UtcNow)
            {
                Write-Host "The certificate is expired. Please install a valid certificate and try again."
                Write-Host "`nEnabling SSL to VDA failed."
                $Store.Close()
                break
            }

            #Check certificate trust
            if(!$Certificate.Verify())
            {
                Write-Host "Verification of the certificate failed. Please install a valid certificate and try again."
                Write-Host "`nEnabling SSL to VDA failed."
                $Store.Close()
                break
            }

            #Check private key availability
            try
            {
                [System.Security.Cryptography.AsymmetricAlgorithm] $PrivateKey = $Certificate.PrivateKey 
                $UniqueContainer = ((($Certificate).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
            }
            catch
            {
                Write-Host "Unable to access the Private Key of the Certificate or one of its fields."
                Write-Host "`nEnabling SSL to VDA failed."
                $Store.Close()
                break
            }

            if(!$PrivateKey -or !$UniqueContainer)
            {
                Write-Host "Unable to access the Private Key of the Certificate or one of its fields."
                Write-Host "`nEnabling SSL to VDA failed."
                $Store.Close()
                break
            }

            if ($PSCmdlet.ShouldProcess("This will grant $serviceName read access to the certificate.", "Are you sure you want to perform this action?`nThis will grant $serviceName read access to the certificate.", "Configure ACLs"))
            {
                $private_key = ((($Certificate).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
                $dir= $env:ProgramData + '\Microsoft\Crypto\RSA\MachineKeys\'
                $keypath = $dir+$private_key
                icacls $keypath /grant `"$username`"`:RX | Out-Null
                Write-Host "ACLs set."
                Write-Host ""
                $ACLsSet = $True
            }
            else
            {
                Write-Host "ACL configuration skipped."
            }

            if($PSCmdlet.ShouldProcess("This will delete any existing firewall rules for port $SSLPort and disable rules for ICA, CGP and Websocket services.", "Are you sure you want to perform this action?`nThis will delete any existing firewall rules for port $SSLPort and disable rules for ICA, CGP and Websocket services.", "Configure Firewall"))
            {
                #Delete any existing rules for the SSLPort
                netsh advfirewall firewall delete rule name=all protocol=tcp localport=$SSLPort | Out-Null

                #Delete any existing rules for the DTLSPort
                netsh advfirewall firewall delete rule name=all protocol=udp localport=$SSLPort | Out-Null
                        
                #Delete any existing rules for Citrix SSL Service
                netsh advfirewall firewall delete rule name="Citrix SSL Service" | Out-Null

                #Delete any existing rules for Citrix DTLS Service
                netsh advfirewall firewall delete rule name="Citrix DTLS Service" | Out-Null
                        
                #Creating firewall rule for Citrix SSL Service
                netsh advfirewall firewall add rule name="Citrix SSL Service"  dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$SSLPort | Out-Null

                #Creating firewall rule for Citrix DTLS Service
                netsh advfirewall firewall add rule name="Citrix DTLS Service" dir=in action=allow service=$serviceName profile=any protocol=udp localport=$SSLPort | Out-Null

                #Disable any existing rules for ICA, CGP and HTML5 ports
                netsh advfirewall firewall set rule name="Citrix ICA Service"        protocol=tcp localport=$IcaPort new enable=no | Out-Null
                netsh advfirewall firewall set rule name="Citrix CGP Server Service" protocol=tcp localport=$CgpPort new enable=no | Out-Null
                netsh advfirewall firewall set rule name="Citrix Websocket Service"  protocol=tcp localport=$Html5Port new enable=no | Out-Null

                #Disable existing rules for UDP-ICA, UDP-CGP
                netsh advfirewall firewall set rule name="Citrix ICA UDP" protocol=udp localport=$IcaPort new enable=no | Out-Null          
                netsh advfirewall firewall set rule name="Citrix CGP UDP" protocol=udp localport=$CgpPort new enable=no | Out-Null

                Write-Host "Firewall configured."
                $FirewallConfigured = $True
            }
            else
            {
                Write-Host "Firewall configuration skipped."
            }

            # Create registry keys to enable SSL to the VDA
            Write-Host "Setting registry keys..."
            Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CERT_HASH_KEY -Value $Certificate.GetCertHash() -Type Binary -Confirm:$False 
            switch($SSLMinVersion)
            {
                "SSL_3.0"
                {
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 1 -Type DWord -Confirm:$False
                }
                "TLS_1.0"
                {
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 2 -Type DWord -Confirm:$False
                }
                "TLS_1.1"
                {
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 3 -Type DWord -Confirm:$False
                }
                "TLS_1.2"
                {
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 4 -Type DWord -Confirm:$False
                }
            }

            switch($SSLCipherSuite)
            {
                "GOV"
                {
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CIPHERSUITE_KEY -Value 1 -Type DWord -Confirm:$False
                }    
                "COM"
                {
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CIPHERSUITE_KEY -Value 2 -Type DWord -Confirm:$False
                }
                "ALL"
                { 
                    Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CIPHERSUITE_KEY -Value 3 -Type DWord -Confirm:$False
                }
            }

            Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_PORT_KEY -Value $SSLPort -Type DWord -Confirm:$False

            #Backup DH Cipher Suite and set Enabled:0 if SSL is enabled
            if (!(Test-Path $ICA_CIPHER_SUITE))
            {
                New-Item -Path $ICA_CIPHER_SUITE -Force | Out-Null
                New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value 0 -PropertyType DWORD -Force | Out-Null
                New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
            }
            else
            {
                $back_enabled_exists = Get-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -ErrorAction SilentlyContinue
                if ($back_enabled_exists -eq $null)
                {
                    $exists = Get-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -ErrorAction SilentlyContinue
                    if ($exists -ne $null)
                    {
                        New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -Value $exists.Enabled -PropertyType DWORD -Force | Out-Null
                        Set-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value 0
                    }
                    else
                    {
                        New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value 0 -PropertyType DWORD -Force | Out-Null
                        New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
                    }
                }
            }

            # NOTE: This must be the last thing done when enabling SSL as the Citrix Service
            #       will use this as a signal to try and start the Citrix SSL Listener!!!!
            Set-ItemProperty -Path $ICA_LISTENER_PATH -name $ENABLE_SSL_KEY -Value 1 -Type DWord -Confirm:$False
        
            Write-Host "Registry keys set."
            Write-Host ""
            $RegistryKeysSet = $True

            $Store.Close()

            if ($RegistryKeysSet -and $ACLsSet -and $FirewallConfigured)
            {
                Write-Host "`nSSL to VDA enabled.`n"
            }
            else
            {
                Write-Host "`n"

                if (!$RegistryKeysSet)
                {
                    Write-Host "Configure registry manually or re-run the script to complete enabling SSL to VDA."
                }

                if (!$ACLsSet)
                {
                    Write-Host "Configure ACLs manually or re-run the script to complete enabling SSL to VDA."
                }
                    
                if (!$FirewallConfigured)
                {
                    Write-Host "Configure firewall manually or re-run the script to complete enabling SSL to VDA."
                }
            }
        }
    }

# SIG # Begin signature block
# MIIa0AYJKoZIhvcNAQcCoIIawTCCGr0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVlCkBIWutmvfv102UfUYLGe2
# k6GgghTsMIIFJDCCBAygAwIBAgIQCpJdJFWANibhh6AFcJolkDANBgkqhkiG9w0B
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
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUDuf7Bgt0VZuidKQQo5ndwQCB
# Ff4wPAYKKwYBBAGCNwIBDDEuMCygEIAOAFMAYwByAGkAcAB0AHOhGIAWaHR0cDov
# L3d3dy5jaXRyaXguY29tIDANBgkqhkiG9w0BAQEFAASCAQBBoEqaJ91S4NpVM3Wj
# xLWjFm2Hqll6KknJo0+nsbxISZq7yuMmOmWAfMz9U/x4D1c+pEebRIndhxHzJYlY
# a+3Ov0tU0l3uGW7fK2ms0RpOAO+cqlM2KmerlM5rx3HoXRtIe594IY/uHOTyoCHR
# 0YuK3gWSjVyWzrl/ugibmI2I8SUM/4kgMSjmOHH13NDHHmd5mnHKUz/454QQRbMu
# dKTbm3XM9YHpjldFWBiJ1bTn49TNswuEZfG8KvZ+oqIBzXo6mNfey91AUvNsp+PK
# 1BrW41bQMJNhamBgQSAaDwAyXApICUODiDAMjGSdztsIQZ0xwHSEb3nofC+q3sxj
# flwnoYIC/TCCAvkGCSqGSIb3DQEJBjGCAuowggLmAgEBMIGGMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3Rh
# bXBpbmcgQ0ECEAqSXSRVgDYm4YegBXCaJZAwDQYJYIZIAWUDBAIBBQCgggE0MBgG
# CSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIyMDIyMTEw
# MjAxNVowLwYJKoZIhvcNAQkEMSIEII8yLVM/2VCm1ROuWCoA/CJkTvzsQM0vubSB
# Zf2T4QJKMIHIBgsqhkiG9w0BCRACLzGBuDCBtTCBsjCBrwQgsCrO26Gy12Ws1unF
# BnpWG9FU4YUyDBzPXmMmtqVvLqMwgYowdqR0MHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EC
# EAqSXSRVgDYm4YegBXCaJZAwDQYJKoZIhvcNAQEBBQAEggEAEHRFdH9Bjmlzf0Fp
# nV78U2sM7pupQQAJWwVmknnhmJUfXehfjf3d3QDtjNHKMSbxHoJCEUZy7PrTtBK0
# ZDchh4upQ2VLzoGKtrpN9GtrO5meCVNQswVihVJR/HktS4XBijKBQ0BChVt+0m9X
# RjEgD+wOmwK5fmZfSorlvrwNjayeXr58P05qwAu5I40Wjt9MsAkU9dY+38PXMWWt
# 8ZKXQUkz5P8oZYaJ4YJk2vVYWnQCgTW2LIHoaGKhP0edNE5T4qAUIGYlLuckOYAn
# opqtLmddI+N9ziMQRYtd2XUDqGAQeKGxSCOxtdn+J8Y7B9oDeOLqnMSyzLgYXlwE
# 4R2jRw==
# SIG # End signature block
