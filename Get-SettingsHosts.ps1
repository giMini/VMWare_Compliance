
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Add-PSSnapin VMware.VimAutomation.Core

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptParentPath = split-path -parent $scriptPath
$scriptFile = $MyInvocation.MyCommand.Definition
$launchDate = get-date -f "yyyyMMddHHmmss"
$logDirectoryPath = $scriptPath + "\" + $launchDate
$logFileName = "Log_Hosts" + $launchDate + ".log"
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

    $esxHosts = Get-VMHost
    foreach($esxHost in $esxHosts){
        Write-Log -StreamWriter $streamWriter -InfoToLog $($esxHost.Name)
        $services = Get-VMHostService -VMHost $esxHost
        foreach($service in $services){
            Write-Log -StreamWriter $streamWriter -InfoToLog "$service running $($service.Running)"        
        }
        $rulesDefined = $esxHost | Get-VMHostFirewallException | Where {$_.Enabled -and (-not $_.ExtensionData.AllowedHosts.AllIP)}
        foreach($ruleDefined in $rulesDefined){
            Write-Log -StreamWriter $streamWriter -InfoToLog "$rulesDefined  $($rulesDefined.VMHost),$($rulesDefined.IncomingPorts),$($rulesDefined.OutgoingPorts),$($rulesDefined.Protocols),$($rulesDefined.Enabled)"
        }
        $rulesNotDefined = $esxHost | Get-VMHostFirewallException | Where {$_.Enabled -and ($_.ExtensionData.AllowedHosts.AllIP)}
        foreach($ruleNotDefined in $rulesNotDefined){
            Write-Log -StreamWriter $streamWriter -InfoToLog "$ruleNotDefined $($ruleNotDefined.VMHost),$($ruleNotDefined.IncomingPorts),$($ruleNotDefined.OutgoingPorts),$($ruleNotDefined.Protocols),$($ruleNotDefined.Enabled)"
        }

        $ntp = $esxHost | Select Name, @{N="NTPSetting";E={$_ | Get-VMHostNtpServer}}
        Write-Log -StreamWriter $streamWriter -InfoToLog $ntp
    
        # List Syslog.global.logDir for each host
        $syslog = $esxHost | Select Name, @{N="Syslog.global.logDir";E={$_ | Get-VMHostAdvancedConfiguration Syslog.global.logDir | Select -ExpandProperty Values}}
        Write-Log -StreamWriter $streamWriter -InfoToLog $syslog
    
        # Check if ESXi Shell is running and set to start
        $esxiShell = $esxHost | Get-VMHostService | Where { $_.key -eq "TSM" } | Select VMHost, Key, Label, Policy, Running, Required
        Write-Log -StreamWriter $streamWriter -InfoToLog $esxiShell

        $ssh = $esxHost | Get-VMHostService | Where { $_.key -eq "TSM-SSH" } | Select VMHost, Key, Label, Policy, Running, Required
        Write-Log -StreamWriter $streamWriter -InfoToLog $ssh
       
        $domainMembership = $esxHost | Get-VMHostAuthentication | Select VmHost, Domain, DomainMembershipStatus
        Write-Log -StreamWriter $streamWriter -InfoToLog $domainMembership

        # Check the host profile is using vSphere Authentication proxy to add the host to the domain
        $vsphereAuthProxy = $esxHost | Select Name, `
         @{N="HostProfile";E={$_ | Get-VMHostProfile}}, `
         @{N="JoinADEnabled";E={($_ | Get-VmHostProfile).ExtensionData.Config.ApplyProfile.Authentication.ActiveDirectory.Enabled}}, `
         @{N="JoinDomainMethod";E={(($_ | Get-VMHostProfile).ExtensionData.Config.ApplyProfile.Authentication.ActiveDirectory | Select -ExpandProperty Policy | Where {$_.Id -eq "JoinDomainMethodPolicy"}).Policyoption.Id}}
        Write-Log -StreamWriter $streamWriter -InfoToLog $vsphereAuthProxy

        $vsphereAuthProxy = $esxHost | Get-VMHostHba | Where {$_.Type -eq "Iscsi"} | Select VMHost, Device, ChapType, @{N="CHAPName";E={$_.AuthenticationProperties.ChapName}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "Proxy $vsphereAuthProxy."
    
        $lockDown = $esxHost | Select Name,@{N="Lockdown";E={$_.Extensiondata.Config.adminDisabled}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "$lockDown"

        #$logHost = $esxHost | Select Name, @{N="Syslog.global.logHost";E={$_ | Get-VMHostAdvancedConfiguration Syslog.global.logHost | Select -ExpandProperty Values}}
        $logHost = (Get-AdvancedSetting -Entity (Get-VMHost -Name $esxHost ) -Name Syslog.global.logHost).Value
        Write-Log -StreamWriter $streamWriter -InfoToLog "$logHost"

        $esxiShellInterTimeOut = $esxHost | Select Name, @{N="UserVars.ESXiShellInteractiveTimeOut";E={$_ | Get-VMHostAdvancedConfiguration UserVars.ESXiShellInteractiveTimeOut | Select -ExpandProperty Values}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "$esxiShellInterTimeOut"

        $esxiShellTimeOut = $esxHost | Select Name, @{N="UserVars.ESXiShellTimeOut";E={$_ | Get-VMHostAdvancedConfiguration UserVars.ESXiShellTimeOut | Select -ExpandProperty Values}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "$esxiShellTimeOut"

        $esxCli = Get-EsxCli -VMHost $esxHost
        $acceptanceLevel = $esxHost | Select Name, @{N="AcceptanceLevel";E={$esxCli.software.acceptance.get()}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "$acceptanceLevel"

        $esxCli = Get-EsxCli -VMHost $esxHost
        $vibs = $esxCli.software.vib.list() | Where { ($_.AcceptanceLevel -ne "VMwareCertified") -and ($_.AcceptanceLevel -ne "VMwareAccepted") }
        Write-Log -StreamWriter $streamWriter -InfoToLog "$vibs"

        $esxCli = Get-EsxCli -VMHost $esxHost
        $vibsFiltered = $esxCli.software.vib.list() | Where { ($_.AcceptanceLevel -ne "VMwareCertified") -and ($_.AcceptanceLevel -ne "VMwareAccepted") -and ($_.AcceptanceLevel -ne "PartnerSupported") }
        Write-Log -StreamWriter $streamWriter -InfoToLog "$vibsFiltered"

        $dvd = $esxHost | Select Name, @{N="Net.DVFilterBindIpAddress";E={$_ | Get-VMHostAdvancedConfiguration Net.DVFilterBindIpAddress | Select -ExpandProperty Values}}
        Write-Log -StreamWriter $streamWriter -InfoToLog "$dvd"

        $passwordExpiration = (Get-AdvancedSetting -Entity (Get-VMHost -Name $esxHost ) -Name VirtualCenter.VimPasswordExpirationInDays).Value
        Write-Log -StreamWriter $streamWriter -InfoToLog "$passwordExpiration"
    }

    $account = Get-VMHostAccount
    Write-Log -StreamWriter $streamWriter -InfoToLog "users $account.Name"

    Terminate-Session -VirtualCenterServer $DefaultVIServer
}
else {
    Terminate-Session -VirtualCenterServer $DefaultVIServer
}

End-Log -StreamWriter $streamWriter