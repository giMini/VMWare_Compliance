
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Add-PSSnapin VMware.VimAutomation.Core

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptParentPath = split-path -parent $scriptPath
$scriptFile = $MyInvocation.MyCommand.Definition
$launchDate = get-date -f "yyyyMMddHHmmss"
$logDirectoryPath = $scriptPath + "\" + $launchDate
$logFileName = "Log_Network" + $launchDate + ".log"
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

    # Check if auto expand is enabled on vDS 
    $dvPortGroup = Get-VirtualPortGroup -Distributed | Select Name, @{N="AutoExpand";E={$_.ExtensionData.Config.AutoExpand}}
    Write-Log -StreamWriter $streamWriter -InfoToLog "$dvPortGroup"

    # List all vSwitches, their Portgroups and VLAN Ids
    $vSwiches = Get-VirtualPortGroup -Standard | Select virtualSwitch, Name, VlanID
    foreach($vSwich in $vSwiches) {
        Write-Log -StreamWriter $streamWriter -InfoToLog "$($vSwich.virtualSwitch),$($vSwich.Name),$($vSwich.VlanID)"
    }

    # List all vSwitches
    $vSwiches = Get-VirtualSwitch -Standard | Select Name, NumPorts, NumPortsAvailable, Mtu, VMHost
    foreach($vSwich in $vSwiches) {
        Write-Log -StreamWriter $streamWriter -InfoToLog "$($vSwich.Name),$($vSwich.NumPorts),$($vSwich.NumPortsAvailable),$($vSwich.Mtu),$($vSwich.VMHost)"
    }

    # List all dvSwitches and their Portgroups, VLAN Type and Ids
    foreach ($dvPortGroup in (Get-VirtualPortGroup -Distributed)) {
        Switch ((($dvPortGroup.ExtensionData.Config.DefaultPortConfig.Vlan).GetType()).Name) {
            VMwareDistributedVirtualSwitchPvlanSpec { 
                $type = "Private VLAN"
                $VLAN = $dvPortGroup.ExtensionData.Config.DefaultPortConfig.Vlan.pVlanID 
            }
            VMwareDistributedVirtualSwitchTrunkVlanSpec { 
                $type = "VLAN Trunk"
                $VLAN = ($dvPortGroup.ExtensionData.Config.DefaultPortConfig.Vlan.VlanID | Select Start, End)
            } 
            VMwareDistributedVirtualSwitchVlanIdSpec { 
                $type = "VLAN"
                $VLAN = $dvPortGroup.ExtensionData.Config.DefaultPortConfig.Vlan.vlanID
            }
            default {
                $type = (($dvPortGroup.ExtensionData.Config.DefaultPortConfig.Vlan).GetType()).Name
                $VLAN = "Unknown"
            }
        }
        $dvPortGroup | Select virtualSwitch, Name, @{N="Type";E={$type}}, @{N="VLanId";E={$VLAN}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "$dvPortGroup"
    }

    # Check for the number of free ports on all VDS PortGroups
    $numFreePorts = Get-VirtualPortGroup -Distributed | Select Name, @{N="NumFreePorts";E={Get-FreeVDSPort -VDSPG $_}}
    Write-Log -StreamWriter $streamWriter -InfoToLog "$numFreePorts"

    # List all vSwitches and their Security Settings
    $vSwitchSecuritySettings = Get-VirtualSwitch -Standard | Select VMHost, Name, `
     @{N="MacChanges";E={if ($_.ExtensionData.Spec.Policy.Security.MacChanges) { "Accept" } Else { "Reject"} }}, `
     @{N="PromiscuousMode";E={if ($_.ExtensionData.Spec.Policy.Security.PromiscuousMode) { "Accept" } Else { "Reject"} }}, `
     @{N="ForgedTransmits";E={if ($_.ExtensionData.Spec.Policy.Security.ForgedTransmits) { "Accept" } Else { "Reject"} }}
     foreach($vSwitchSecuritySetting in $vSwitchSecuritySettings) {
        Write-Log -StreamWriter $streamWriter -InfoToLog "$vSwitchSecuritySetting"
    }
    # List all dvPortGroups and their Security Settings
    $vPortGroupSecuritySettings = Get-VirtualPortGroup -Distributed | Select Name, `
     @{N="MacChanges";E={if ($_.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.MacChanges.Value) { "Accept" } Else { "Reject"} }}, `
     @{N="PromiscuousMode";E={if ($_.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.AllowPromiscuous.Value) { "Accept" } Else { "Reject"} }}, `
     @{N="ForgedTransmits";E={if ($_.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.ForgedTransmits.Value) { "Accept" } Else { "Reject"} }}
    foreach($vPortGroupSecuritySetting in $vPortGroupSecuritySettings) {
        Write-Log -StreamWriter $streamWriter -InfoToLog "$vPortGroupSecuritySettings"
    }

    #Disconnect-VIServer -Server $DefaultVIServer -Confirm:$false
    Terminate-Session -VirtualCenterServer $DefaultVIServer
}
else {
    Terminate-Session -VirtualCenterServer $DefaultVIServer
}

End-Log -StreamWriter $streamWriter