$cred = Import-Clixml C:\Scripts\CItrix\xdreportspas.xml
$TOLIST = "Bobba.Jeevan@DOL.gov","Nawthale.Kavibhushan@dol.gov","Wright.Brian.D@dol.gov","Quintanilla.Raul.H@DOL.gov","Behzad.Ellie@dol.gov","WatsonIII.George.A@DOL.GOV","Surapaneni.Venu@dol.gov","Onadeko.Eddie@dol.gov","Kleinkauf.Karl.H@dol.gov","Khan.Adnan.A@dol.gov","Huynh.Anh.H@dol.gov"
Set-StrictMode -Off 
Import-Module C:\Scripts\CItrix\DCOMPermissions.psm1 | Out-Null
get-process excel -errorAction Silentlycontinue | stop-process -force -errorAction Silentlycontinue | Out-Null
$DC1path = '\\SILENTFS01.ent.dir.labor.gov\reports\Citrix\templates\2hoursummaryDC1.xlsx'
$DC17path = '\\SILENTFS01.ent.dir.labor.gov\reports\Citrix\templates\7daysummaryDC1.xlsx'
$2dayreportfile = '\\SILENTFS01.ent.dir.labor.gov\reports\Citrix\templates\Consolidated\2hoursummary.xlsx'
$7dayreportfile = '\\SILENTFS01.ent.dir.labor.gov\reports\Citrix\templates\Consolidated\7daysummary.xlsx'
$reportparentfolder = "\\SILENTFS01.ent.dir.labor.gov\reports\Citrix\Reports"
$dailyreportfolder = "$reportparentfolder\$(get-date -format 'MM-dd-yyyy')"
if(!(Test-Path $dailyreportfolder)){New-Item -ItemType Directory  $dailyreportfolder -Force | Out-Null}
$hourlyreportfolder = "$dailyreportfolder\$(get-date -Format 'hh-mm tt')"
if(!(Test-Path $hourlyreportfolder)){New-Item -ItemType Directory  $hourlyreportfolder -Force | Out-Null}
$Dc1Srv = (Test-Connection 'DC1VWCTXXDCP01.ent.dir.labor.gov','DC1VWCTXXDCP02.ent.dir.labor.gov' -count 2 | Sort-Object -Property ResponseTime | Select-Object -First 1).Address
$dc1vcenter = 'dc1vavdimgtp01.ent.dir.labor.gov'
$fullresults = @()
$reporttime = $((Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month) + $(get-date -f " dd-yyyy hh:mm tt"))
#$startdate =  get-date -Date (Get-Date).AddHours(-2)  -Format "yyyy-MM-ddTHH:mm:ss"
#$enddate =  Get-Date  -Format "yyyy-MM-ddTHH:mm:ss"
#$startdateforweek =  get-date -Date (Get-Date).Adddays(-7)  -Format "yyyy-MM-ddTHH:mm:ss"
$timeoftheday = (Get-Date).Hour
if($timeoftheday -eq '7' -or $timeoftheday -eq '17'){$repvalue='RUN'}
get-process excel -errorAction Silentlycontinue | stop-process -force -errorAction Silentlycontinue | Out-Null
#$files = @($DC1path,$DC17path,$stlpath,$stl7path)
$files = @($DC1path,$DC17path)
$Dc1SB = {
#$startdate =  get-date -Date (Get-Date).AddHours(-2)  -Format "yyyy-MM-ddTHH:mm:ss'Z'"
$datescope = (get-date).AddHours(-2).ToUniversalTime()
$startdate= get-date($datescope) -Format "yyyy-MM-ddTHH:mm:ss'Z'"
$URI = 'http://localhost/Citrix/Monitor/OData/v4/Data/SessionActivitySummaries?$filter=SummaryDate gt #startdate# and DesktopGroupId eq 6132bd9e-a34b-4123-8a5d-0843ca81713a'
$URI=$URI -replace '#startdate#',$startdate 
$results = Invoke-RestMethod -Uri $URI -Credential $args[0]
$results.value | Select-Object SummaryDate,ConnectedSessionCount,DisconnectedSessionCount,ConcurrentSessionCount,TotalLogOnCount,TotalLogonDuration
}
$DC17DaySB = {
$datescope = (get-date).Adddays(-7).ToUniversalTime()
$startdate= get-date($datescope) -Format "yyyy-MM-ddTHH:mm:ss'Z'"
$URI = 'http://localhost/Citrix/Monitor/OData/v4/Data/SessionActivitySummaries?$filter=(SummaryDate gt #startdate# and DesktopGroupId eq 6132bd9e-a34b-4123-8a5d-0843ca81713a) and Granularity eq 60'
$URI=$URI -replace '#startdate#',$startdate
$results= Invoke-RestMethod -Uri $URI -Credential $args[0]
$results.value | Select-Object SummaryDate,ConnectedSessionCount,DisconnectedSessionCount,ConcurrentSessionCount,TotalLogOnCount,TotalLogonDuration
}

foreach($file in $files ){
$vs = $dc1vcenter;$ctxc = $Dc1Srv;$dg= 'DOL GSS Desktop';$dgid = '6132bd9e-a34b-4123-8a5d-0843ca81713a'
$VC = Connect-VIServer -force -Credential $cred -Server $Vs | Out-Null
$CtxData = Invoke-Command -Credential $cred -ComputerName $ctxc -ScriptBlock {Add-PSSnapin ci* ;Get-BrokerSession | Select-Object HostedMachineName,MachineName | Where-Object{$_.HostedMachineName -ne $null}}
IF(!$CTXDATA){"no aCTIVE sESSIONS"| ADD-CONTENT "$hourlyreportfolder\$site-NOUSERDATA.txt"; BREAK}
$citrixVMs = get-vm $CtxData.HostedMachineName -Server $VC
$summary = get-vm $citrixVMs -Server $VC -OutVariable VMDetails | Get-Stat -Stat "cpu.usage.average","mem.usage.average" -Start (get-date).AddHours(-2) -Finish (get-date) -IntervalMins 5 -MaxSamples 120
Disconnect-VIServer -Server $VS -Force -Confirm:$false
if($file -match "2hoursummaryDC1.xlsx"){$PDFPath = "$hourlyreportfolder\Last2HourReport.pdf";$FSB = $Dc1SB;$final = Invoke-Command -ComputerName $ctxc -ScriptBlock $FSB  -Credential $cred -ArgumentList $cred | Select-Object @{l="Date";e={get-date -date $_.SummaryDate -Format t}},ConnectedSessionCount,DisconnectedSessionCount,ConcurrentSessionCount,TotalLogOnCount,TotalLogonDuration;$path="$hourlyreportfolder\2hoursummary.xlsx" ; copy-item $2dayreportfile   -Destination $path -Force;$final | Export-Excel -Path $path -WorksheetName DC1 -ClearSheet;$peakdata = ($final | Sort-Object -Property ConcurrentSessionCount -Descending | Select-Object -First 1 | Select-Object @{l="val";e={-join ($_.ConcurrentSessionCount, " (",$_.Date,")")}}).Val} 
if($file -match "7daysummaryDC1.xlsx"  -and $repvalue -eq 'RUN' ) {$PDFPath = "$hourlyreportfolder\Last7DayReport.pdf";$FSB = $DC17DaySB;$final = Invoke-Command -ComputerName $ctxc -ScriptBlock $FSB  -Credential $cred -ArgumentList $cred | Select-Object @{l="Date";e={get-date -date $_.SummaryDate -Format "MM/dd/yyyy HH:mm:ss tt"}},ConnectedSessionCount,DisconnectedSessionCount,ConcurrentSessionCount,TotalLogOnCount,TotalLogonDuration;$path="$hourlyreportfolder\7DaySummary.xlsx";copy-item $7dayreportfile   -Destination $path  -Force;$final | Export-Excel -Path $path -WorksheetName DC1 -ClearSheet} 
if(Test-Path $path){
Grant-DComPermission -ApplicationID '{00020812-0000-0000-C000-000000000046}'  -Account "NT AUTHORITY\SYSTEM" -Type Launch -Permissions LocalLaunch,LocalActivation 
Grant-DComPermission -ApplicationID '{00020812-0000-0000-C000-000000000046}'  -Account "NT AUTHORITY\SELF" -Type Launch -Permissions LocalLaunch,LocalActivation 
Grant-DComPermission -ApplicationID '{00020812-0000-0000-C000-000000000046}'  -Account "BUILTIN\Administrators" -Type Launch -Permissions LocalLaunch,LocalActivation 
$Excel = New-Object -ComObject excel.application
$Excel.visible = $false
$macros_wb = $excel.Workbooks.open($path)
$item="chart" #sheetname
$xlFixedFormat = "Microsoft.Office.Interop.Excel.xlFixedFormatType" -as [type]
$macros_ws = $macros_wb.WorkSheets.item($item)
<#
$macros_wb.Application.PrintCommunication =$true
$macros_ws.PageSetup.Orientation = 2
$macros_ws.PageSetup.Zoom = $False
$macros_ws.PageSetup.FitToPagesTall = 1
$macros_ws.PageSetup.FitToPagesWide  = 1
$macros_ws.PageSetup.LeftMargin  = 5
$macros_ws.PageSetup.RightMargin  = 0.01
$macros_ws.PageSetup.TopMargin  = 20
$macros_ws.PageSetup.BottomMargin  = 0.01
$macros_ws.PageSetup.HeaderMargin  = 0.01
$macros_ws.PageSetup.FooterMargin  = 0.01
$macros_ws.ExportAsFixedFormat($xlFixedFormat::xlTypePDF, $PDFPath)
#>
$macros_ws.Application.DisplayAlerts = $false
$macros_ws.SaveAs($PDFPath,57)
#$macros_ws.Application.DisplayAlerts = $true
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)
get-process excel -errorAction Silentlycontinue | stop-process -force -errorAction Silentlycontinue | Out-Null
}
if($file -match "2hoursummary" ){
$fullresults += [pscustomobject]@{
Time = $reporttime
Site = "DC1"
CurrentUsers = $CtxData| Measure-Object | Select-Object -ExpandProperty Count
'CPU(Avg)' =  [math]::Round(($summary | Where-Object{$_.MetricID -like "cpu.usage.average" }| Measure-Object -Average -Property Value).Average,2)
'Memory(Avg)' = [math]::Round(($summary | Where-Object{$_.MetricID -like "mem.usage.average" }| Measure-Object -Average -Property Value).Average,2)
'Peak(CPU)' = ($summary | Where-Object{$_.MetricID -like "cpu.usage.average"} | Sort-Object -Property Value -Descending | Select-Object -First 1 | Select-Object @{l="val";e={-join ($_.Value, " (",$_.TimeStamp,")", " (",$_.Entity,")"  )}}).Val
'Peak(Memory)'= ($summary | Where-Object{$_.MetricID -like "mem.usage.average"} | Sort-Object -Property Value -Descending | Select-Object -First 1| Select-Object @{l="val";e={-join ($_.Value, " (",$_.TimeStamp,")", " (",$_.Entity,")"  )}}).Val
'PeakUsers(Time)'=  $peakdata
'MaxConcurrentSessions' = ($final | Sort-Object -Property concurrentSessioncount -Descending | Select-Object -First 1).ConcurrentSessionCount
'AverageLogon(Minutes)' =  [math]::Round(($final | Measure-Object -Property TotallogonDuration -Average).Average/6000,1)
#'MaxConcurrentSessions(Last7Days)' = $dirlastweekdata.MaxConcurrentSessions
}
}
}

IF($fullresults){$fullresults | export-csv $hourlyreportfolder\reports.csv -NoTypeInformation}
$a = Get-ChildItem $dailyreportfolder -Filter *.csv -Recurse|Sort-Object -Property CreationTime  | ForEach-Object{import-csv  $PSItem.FullName }
$DC1results = New-Object System.Collections.Generic.List[System.Object]
foreach($b in $a){
$DC1results += [pscustomobject]@{
"Time" =  get-date -date $((get-date -Date $b.Time).AddHours(1))  -uFormat '%I:00 %p'
"Users"= $b.CurrentUsers
"CPU Usage"= $b.'CPU(Avg)'
"Memory Usage"= $b.'Memory(Avg)'
"PeakUsage Time"= ($b.'PeakUsers(Time)' -split "\(" -split "\)")[1]
}
}
$convertParams = @{ 
 head = @"
 <Title>Citrix Session Summary</Title>
<style>
table {
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    border-spacing: 5px;
    margin: 20px;
    text-align: center;
}

td {
    font-size: 1em;
    border: 1px solid #0078D7;
    padding: 5px 5px 5px 5px;
}

th {
    font-size: 1.1em;
    text-align: center;
    border: 1px solid;
    padding-top: 5px;
    padding-bottom: 5px;
    padding-right: 7px;
    padding-left: 7px;
    background-color: #0078D7;
    color: #ffffff;
    }

name tr {
    color: #000000;
    background-color: #0078D7;
}

</style>
"@
}
$last2HourResultsh = $fullresults | ConvertTo-Html -As Table -Fragment -PreContent "<h3>Citrix User Connection Summary for Last 2 Hours</h4>" -PostContent "<br></br>" | Out-String
$DC1Results_Frag = $DC1results | ConvertTo-Html -As Table -Fragment -PreContent "<h4>DC1 FARM-Citrix User Connection Summary for $(get-date -Format D) </h4>"  -PostContent "<br></br>"   | Out-String
#$STLResults_Frag = $STLresults | ConvertTo-Html -As Table -Fragment -PreContent "<h4>STL FARM-Citrix User Connection Summary for $(get-date -Format D) </h4>" -PostContent "<br></br>" | Out-String 
$body = ConvertTo-HTML @convertParams -PreContent $last2HourResultsh,$DC1Results_Frag -Title "<h2>Citrix Daily Checks $(get-date -Format D) </h2>" -PostContent "<p>Detailed Reports are located on the Share at <u><b>$hourlyreportfolder</b></u></p><p class='footer'>Report generated from $env:COMPUTERNAME on $(get-date) .Report is run using $($cred.username)</p>"
if($repvalue -eq 'RUN'){$attachments= (Get-ChildItem $hourlyreportfolder -Filter *.pdf).FullName;$Subj = "Citrix Hourly Check Report and Last 7 Days Report for $(($hourlyreportfolder -split "\\")[-2,-1] -join " ")" } else {$attachments= (Get-ChildItem $hourlyreportfolder -Filter *.pdf).FullName;$subj = "Citrix Hourly Check Report for $(($hourlyreportfolder -split "\\")[-2,-1] -join " ")"}
Send-EmailMessage -To $TOLIST -From 'CitrixHourlyChecks@dol.gov' -Server 'dc1-smtp.dol.gov' -Subject $Subj -Attachment $attachments -HTML $Body -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror
#Send-EmailMessage -To "surapaneni.venu@dol.gov" -From 'CitrixHourlyChecks@dol.gov' -Server 'dc1-smtp.dol.gov' -Subject $Subj -Attachment $attachments -HTML $Body -DeliveryNotificationOption Never -Verbose -Port 25 -ErrorVariable mailerror
if($mailerror){"Email Failed - $mailerror" | Add-Content "$hourlyreportfolder\$hourlyreportfolder-mailissues.txt"}