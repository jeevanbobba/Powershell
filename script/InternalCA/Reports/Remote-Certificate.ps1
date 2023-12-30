using namespace System.Net.Sockets
using namespace System.Net.Security
using namespace System.Security.Cryptography.X509Certificates
function ConvertFrom-X509Certificate {
    param(
        [Parameter(ValueFromPipeline)]
        [X509Certificate2]$Certificate
    )

    process {
        @(
            '-----BEGIN CERTIFICATE-----'
            [Convert]::ToBase64String(
                $Certificate.Export([X509ContentType]::Cert),
                [Base64FormattingOptions]::InsertLineBreaks
            )
            '-----END CERTIFICATE-----'
        ) -join [Environment]::NewLine
    }
}
function Get-RemoteCertificate {
    param(
        [Alias('CN')]
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComputerName,

        [Parameter(Position = 1)]
        [UInt16]$Port = 443,

        [ValidateSet('Base64', 'X509Certificate')]
        [string]$As = 'X509Certificate',
        [switch]$Insecure = $false
    )

    $tcpClient = [TcpClient]::new($ComputerName, $Port)
    try {
        $tlsClient = [SslStream]::new($tcpClient.GetStream(), $false, {$Insecure})
        $tlsClient.AuthenticateAsClient($ComputerName)

        if ($As -eq 'Base64') {
            return $tlsClient.RemoteCertificate |ConvertFrom-X509Certificate
        }

        return $tlsClient.RemoteCertificate -as [X509Certificate2]
    }
    finally {
        if ($tlsClient -is [IDisposable]) {
            $tlsClient.Dispose()
        }
        $tcpClient.Dispose()
    }
}
$serverlist = "ecompws.dol.gov:443","speedtest.ent.dir.labor.gov:443","dc1vaocspp03.ent.dir.labor.gov:3602","efax.dol.gov:443","dc1pixiaadmp01.ent.dir.labor.gov:443","dra.dol.gov:443"
$results = New-Object System.Collections.ArrayList
foreach($server in $serverlist){
$serverName = ($server -split ":")[0]
$serverPort = ($server -split ":")[1]
try{
$certDetails = Get-RemoteCertificate -ComputerName $serverName  -Port $serverPort -Insecure
}
catch{
Write-Output "$serverName is Not Responding on $serverPort"
}
if($certDetails){
$obj = [pscustomobject]@{
Server = $serverName
Port = $serverPort
CertIssuer = ($certDetails.Issuer -split ", DC=" -split ", OU=" -replace "CN=")[0]
IssuedDate = $certDetails.GetEffectiveDateString()
ExpiryDate = $certDetails.GetExpirationDateString()
DNSNames = $certDetails.DnsNameList.unicode -join ","
SerialNumber = $certDetails.SerialNumber
ThumbPrint = $certDetails.Thumbprint
CertSubject = $certDetails.Subject
EnhancedKeyUsageList = $certDetails.EnhancedKeyUsageList.friendlyname -join ","
}
$results.Add($obj)|Out-Null
Remove-Variable obj,certDetails -Force -ErrorAction SilentlyContinue
}
}
$results
