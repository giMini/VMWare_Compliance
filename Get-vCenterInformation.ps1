
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Add-PSSnapin VMware.VimAutomation.Core

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptParentPath = split-path -parent $scriptPath
$scriptFile = $MyInvocation.MyCommand.Definition
$launchDate = get-date -f "yyyyMMddHHmmss"
$logDirectoryPath = $scriptPath + "\" + $launchDate
$logFileName = "Log_VMs" + $launchDate + ".log"
$logPathName = "$logDirectoryPath\$logFileName"

$folderToLook = $scriptPath

if(!(Test-Path $logDirectoryPath)) {
    New-Item $logDirectoryPath -type directory | Out-Null
}

$streamWriter = New-Object System.IO.StreamWriter $logPathName

$DefaultVIServer = "192.168.25.128"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

$functions = "$scriptPath\functions.ps1"
. $functions

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Connect-Hypervisor -VirtualCenterServer $DefaultVIServer

if ($script:hypervisorConnection.IsConnected -eq "True") {

    #[xml]$xmlSettings = Get-Content "$scriptPath\config.xml"
    #$computeClusterName = $xmlSettings.Settings.General.ComputeClusterName

    #-----------------------------------------------------------[Functions]------------------------------------------------------------

    $functions = "$scriptPath\functions.ps1"
    . $functions

    #-----------------------------------------------------------[Execution]------------------------------------------------------------

    # List All Patches for your vCenter Server, Administrator Privileges will be needed on your
    # vCenter server for this to complete
    Get-WmiObject -ComputerName $DefaultVIServer Win32_QuickFixEngineering | select Description, Hotfixid


    # List all vCenter Application log entries for VMware VirtualCenter. OS Administrator Privileges will be needed on your server for this to complete.
    Get-EventLog -ComputerName $DefaultVIServer -LogName Application -Source "VMware VirtualCenter Server" -EntryType Warning

    # List the version of vCenter OS and Service Pack. OS Administrator Privileges will be needed on your server for this to complete
    Get-WmiObject Win32_OperatingSystem -computer $DefaultVIServer | select CSName, Caption, CSDVersion
    # List Plugins Installed
    $ServiceInstance = get-view ServiceInstance -Server $DefaultVIServer
    $EM = Get-View $ServiceInstance.Content.ExtensionManager -Server $DefaultVIServer
    $EM.ExtensionList | Select @{N="Name";E={$_.Description.Label}}, Company, Version, @{N="Summary";E={$_.Description.Summary}}

    Terminate-Session -VirtualCenterServer $DefaultVIServer
}
else {
    Terminate-Session -VirtualCenterServer $DefaultVIServer
}

End-Log -StreamWriter $streamWriter