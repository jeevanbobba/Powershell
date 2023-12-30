$computers = (Get-ADComputer -filter {SamAccountName -like "Silvmociod*"} -server dev-ent.dev-dir.labor.gov).DNSHOSTNAME

$a = {
 if((cscript.exe "c:\windows\system32\slmgr.vbs" /dli)[7] -Notlike "*Licensed"){ write-output "$env:COMPUTERNAME is not licensed"}

 }


 foreach($computer in $computers)
 {
 if (Test-Connection $computer -Quiet -Count 1)
 {
  ICM -ComputerName $computer -ScriptBlock $a -SessionOption (New-PSSessionOption -NoMachineProfile)
 }#If
 else {
 write-output "$computer is offline "
 }
 }#foreach

 