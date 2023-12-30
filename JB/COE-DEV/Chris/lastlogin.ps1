 $comps = gc "C:\temp\Computernames.txt"
 $file = "c:\temp\Last.csv"
 foreach($comp in $comps){
 Get-WmiObject Win32_NetworkLoginProfile -ComputerName $comp | select Name,@{l="LastLogonDate";e={[datetime]::ParseExact(($_.LastLogon -split "\.")[0],"yyyyMMddHHmmss",$null)}},@{l="ComputerName";e={$_."__SERVER"}} | Sort-Object -Descending -Property LastLogonDate  | select ComputerName,Name,LastLogonDate -First 1 | export-csv $file -NoTypeInformation -Append
 }  