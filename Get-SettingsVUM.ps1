
#----------------------------------------------------------[Declarations]----------------------------------------------------------

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptParentPath = split-path -parent $scriptPath
$scriptFile = $MyInvocation.MyCommand.Definition
$launchDate = get-date -f "yyyyMMddHHmmss"
$logDirectoryPath = $scriptPath + "\" + $launchDate
$logFileName = "Log_VUM" + $launchDate + ".log"
$logPathName = "$logDirectoryPath\$logFileName"

$folderToLook = $scriptPath

if(!(Test-Path $logDirectoryPath)) {
    New-Item $logDirectoryPath -type directory | Out-Null
}

$streamWriter = New-Object System.IO.StreamWriter $logPathName

$updates = Get-WmiObject -ComputerName "127.0.0.1" Win32_QuickFixEngineering | select Description, Hotfixid
foreach($update in $updates) {
    Write-Log -StreamWriter $streamWriter -InfoToLog "$($update.Description),$($update.Hotfixid)"
}

End-Log -StreamWriter $streamWriter