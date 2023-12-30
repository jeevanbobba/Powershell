CLS
#$Users= gc \\mgtutils01.oasam.dir.labor.gov\dml\COE-DEV\RDP_Files\Ref\Scripts\Final\Userid.txt
$Users= gc C:\temp\WHD.txt
$Users | %{
$a = $PSItem
if (($a.Substring(0,2) -like “z-“) -and ($a -notmatch ” “) ){“$a”}
else{
$SamAccountName = ((($a -split ” “)[-1..-5] -join “-“).Insert(0,’z-‘))
#$SamAccountName
#If ($samaccountname.length -ge 19){$samaccountname.remove(19)} else {$SamAccountName}
if ($SamAccountName.length -ge 19){$SamAccountName.substring(0, 19)} else {$SamAccountName}
}
}