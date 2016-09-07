
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

    $parameters = @()
    $parameters += "isolation.tools.autoInstall.disable"
    $parameters += "isolation.tools.copy.disable"
    $parameters += "isolation.tools.dnd.disable"
    $parameters += "isolation.tools.setGUIOptions.enable"
    $parameters += "isolation.tools.paste.disable"
    $parameters += "isolation.tools.diskShrink.disable"
    $parameters += "isolation.tools.diskWiper.disable"
    $parameters += "isolation.tools.hgfsServerSet.disable"
    $parameters += "vmci0.unrestricted"
    $parameters += "isolation.monitor.control.disable"
    $parameters += "isolation.tools.ghi.autologon.disable"
    $parameters += "isolation.bios.bbs.disable"
    $parameters += "isolation.tools.getCreds.disable"
    $parameters += "isolation.tools.ghi.launchmenu.change"
    $parameters += "isolation.tools.memSchedFakeSampleStats.disable"
    $parameters += "isolation.tools.ghi.protocolhandler.info.disable"
    $parameters += "isolation.ghi.host.shellAction.disable"
    $parameters += "isolation.tools.dispTopoRequest.disable"
    $parameters += "isolation.tools.trashFolderState.disable"
    $parameters += "isolation.tools.ghi.trayicon.disable"
    $parameters += "isolation.tools.unity.disable"
    $parameters += "isolation.tools.unityInterlockOperation.disable"
    $parameters += "isolation.tools.unity.taskbar.disable"
    $parameters += "isolation.tools.unityActive.disable"
    $parameters += "isolation.tools.unity.windowContents.disable"
    $parameters += "isolation.tools.unity.push.update.disable"
    $parameters += "isolation.tools.vmxDnDVersionGet.disable"
    $parameters += "isolation.tools.guestDnDVersionSet.disable"
    $parameters += "isolation.tools.vixMessage.disable"
    $parameters += "RemoteDisplay.maxConnections"
    $parameters += "log.keepOld"
    $parameters += "log.rotateSize"
    $parameters += "tools.setInfo.sizeLimit"
    $parameters += "isolation.device.connectable.disable"
    $parameters += "isolation.device.edit.disable"
    $parameters += "tools.guestlib.enableHostInfo"
    $parameters += "ethernetn.filtern.name*"
    $parameters += "vmsafe.agentAddress"
    $parameters += "vmsafe.agentPort"
    $parameters += "vmsafe.enable"
    $parameters += "RemoteDisplay.vnc.enabled"


    # Retrieve settings for all VMs on this vcenter
    $vms = Get-VM
    foreach($vm in $vms){
        foreach($parameter in $parameters) {
            $settings = $vm | Get-AdvancedSetting -Name $parameter | Select Entity, Name, Value
            if($settings) {
                Write-Setting -Settings $settings
            }
        }
    }

    Terminate-Session -VirtualCenterServer $DefaultVIServer
}
else {
    Terminate-Session -VirtualCenterServer $DefaultVIServer
}

End-Log -StreamWriter $streamWriter