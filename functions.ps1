function Get-HypervisorCredential {
<# 
    .SYNOPSIS  
        Get the credential to connect to the vCenter server
    .DESCRIPTION                      

    .EXAMPLE          

#> 

    $user = "YourAccountToConnect"
    $passwordFile = "pathToTheSecurePassword.txt"
    $keyFile = "pathToTheSecureKey.key"
    $key = Get-Content $keyFile        
    $deploymentCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $passwordFile | ConvertTo-SecureString -Key $key)
    return $deploymentCredential
}


function Connect-Hypervisor {
param(
    [String]$VirtualCenterServer
    )
<#  
    .SYNOPSIS  
        Connect to the hypervisor
    .DESCRIPTION              
        
    .EXAMPLE          

#>     
    try {	
        $now = Get-Date	    	    
        #$deploymentCredential = Get-HypervisorCredential
        $script:hypervisorConnection = Connect-VIServer $VirtualCenterServer  -User root -Password P@ssword1! # -Credential $deploymentCredential               
    }
    catch {	    
        Write-Output $_.Exception        
        Terminate-Session -VirtualCenterServer $VirtualCenterServer
    }        
}

function Terminate-Session {

param(
    [String]$VirtualCenterServer
    )
<#  
    .SYNOPSIS  
        Terminate the session with the vCenter server
    .DESCRIPTION                    

    .EXAMPLE          

#> 
    if ($script:hypervisorConnection.IsConnected -eq "True") {
        Write-Output "Déconnexion du Virtual Center Server $VirtualCenterServer"
        Disconnect-VIServer -Server $VirtualCenterServer -Confirm:$false
    }
}

function Get-FreeVDSPort {
    Param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    $VDSPG
    )
    Process {
        $nicTypes = "VirtualE1000","VirtualE1000e","VirtualPCNet32","VirtualVmxnet","VirtualVmxnet2","VirtualVmxnet3" 
        $ports = @{}

        $VDSPG.ExtensionData.PortKeys | Foreach {
            $ports.Add($_,$VDSPG.Name)
        }
 
        $VDSPG.ExtensionData.Vm | Foreach {
            $VMView = Get-View $_
            $nic = $VMView.Config.Hardware.Device | where {$nicTypes -contains $_.GetType().Name -and $_.Backing.GetType().Name -match "Distributed"}
            $nic | where {$_.Backing.Port.PortKey} | Foreach {$ports.Remove($_.Backing.Port.PortKey)}
        }
        ($ports.Keys).Count
    }
}

function Write-Log {
    [CmdletBinding()]  
    Param ([Parameter(Mandatory=$true)][System.IO.StreamWriter]$StreamWriter, [Parameter(Mandatory=$true)]$InfoToLog)  
    Process{    
        try{
            $StreamWriter.WriteLine("$InfoToLog")
        }
        catch {
            $_
        }
    }
}

function End-Log { 
    [CmdletBinding()]  
    Param ([Parameter(Mandatory=$true)][System.IO.StreamWriter]$StreamWriter)  
    Process{             
        $StreamWriter.Close()   
    }
}

function Write-Setting {
    [CmdletBinding()]  
    Param ([Parameter(Mandatory=$true)]$Settings) 
    Process{             
        foreach($setting in $settings) {
            Write-Log -StreamWriter $streamWriter -InfoToLog "$($setting.Name),$($setting.Entity),$($setting.Value)"
        }        
    }
}