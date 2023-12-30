Set-Location C:\
$console = $host.UI.RawUI
$console.WindowTitle = "Tim's PowerShell Console"
$console.BackgroundColor = "Gray"
$console.ForegroundColor = "Black"
 
$buffer = $console.BufferSize
$buffer.Width = 80
$buffer.Height = 5000
$console.BufferSize = $buffer
 
$size = $console.WindowSize
$size.Width = 80
$size.Height = 25
$console.WindowSize = $size
 
New-Item alias:np -value "C:\Windows\System32\notepad.exe"
New-Item alias:st -value "C:\Program Files\Sublime Text 3\sublime_text.exe"
 

function Get-Uptime {
   $os = Get-WmiObject win32_operatingsystem
   $uptime = (Get-Date) - ($os.ConvertToDateTime($os.lastbootuptime))
   $Display = "Uptime: " + $Uptime.Days + " days, " + $Uptime.Hours + " hours, " + $Uptime.Minutes + " minutes" 
   Write-Output $Display
} 
Clear-Host
Get-Uptime
