<#
Gets all the Internal CA Manually issues certs (FIlters by template)..see line 11 ($templates)
Exports to a Excel 
#>
$allCA = (Get-CertificationAuthority -Enterprise).computerName
$exportfile = "\\SILENTFS01.ent.dir.labor.gov\Reports\CA Servers\Reports\AllIssuedCerts-$(get-date -f MMM-dd-yyyy-hh-mm-tt).xlsx" 
$Results = New-Object system.collections.Generic.List[System.Object]
foreach($CA in $allCA){
Write-Output "Working on $CA"
$CurrentCA = Connect-CertificationAuthority  $CA
$templates = Get-CertificateTemplate | ?{$PSItem.DisplayName -match "DOL CLIENT SERVER AUTHENTICATION|DOL CODE SIGNING|DOL REGISTRATION AUTHORITY|DOL SERVER AUTHENTICATION"}
$Result = $Templates.'DisplayName' | %{
$template = $PSItem
Get-IssuedRequest -CertificationAuthority $CurrentCA  -filter "NotAfter -ge $(Get-Date)","CertificateTemplate -eq $template" -Property RequestID,Request.EMail,Request.DistinguishedName,Request.CommonName,CertificateTemplate,CertificateTemplateOid,PrivatekeyFlags,NotAfter,NotBefore,UPN,DistingushedName,CommonName,ConfigString,SerialNumber
}
foreach($item in $Result){
$certitem = $item |Receive-Certificate #To Get Cert Details
$report = [pscustomobject]@{
CAServer = $CA
RequestID = $item.RequestID
'Request.RequesterName' = $item.'Request.RequesterName'
CommonName = ($item.CommonName | Out-String).trim()
SANNAMES = $certitem.DnsNameList.unicode -join ","
NotBefore = get-date -Date $certitem.NotBefore -Format "MM/dd/yyyy HH:mm"
NotAfter = get-date -Date $certitem.NotAfter -Format "MM/dd/yyyy HH:mm"
SerialNumber = ($item.SerialNumber | Out-String).trim()
ThumbPrint = ($CertItem.Thumbprint | Out-String).trim()
'Request.EMail' = ($item.'Request.EMail' | Out-String).trim()
'Request.DistinguishedName' = ($item.'Request.DistinguishedName' | Out-String).trim()
'Request.CommonName' = ($item.'Request.CommonName' | Out-String).trim()
UPN = ($item.UPN | Out-String).trim()
HasPrivateKey=($certitem.HasPrivateKey| Out-String).trim()
KeySize = ($certitem.PublicKey.Key.KeySize| Out-String).trim()
CertificateTemplateName = $certitem.ResolvedExtensions.templateoid.FriendlyName
CertificateTemplateOid = ($item.CertificateTemplateOid.Value | Out-String).trim()
}
$Results.Add($report)
}
}
$Results | Export-Excel $exportfile -AutoSize -AutoFilter
