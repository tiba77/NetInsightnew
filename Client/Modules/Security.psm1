# =====================================================================
# NetInsight
# Module      : Security.psm1
# Version     : 2.3.0
# Build       : 001
# =====================================================================

Set-StrictMode -Version Latest

if (-not (Get-Module Common)) {
    Import-Module "$PSScriptRoot\Common.psm1" -Force
}


#---------------------------------------------------------
# PRIVATE
#---------------------------------------------------------

function Get-NITPM {

    try {

        $TPM = Get-Tpm

        [PSCustomObject]@{

            Present   = $TPM.TpmPresent
            Ready     = $TPM.TpmReady
            Enabled   = $TPM.TpmEnabled
            Activated = $TPM.TpmActivated
            Owned     = $TPM.TpmOwned

        }

    }

    catch {

        [PSCustomObject]@{

            Present   = $false
            Ready     = $false
            Enabled   = $false
            Activated = $false
            Owned     = $false

        }

    }

}

function Get-NIBitLocker {

    try {

        Get-BitLockerVolume |
        ForEach-Object {

            [PSCustomObject]@{

                Drive         = $_.MountPoint
                VolumeStatus  = $_.VolumeStatus
                Protection    = $_.ProtectionStatus
                Encryption    = $_.EncryptionPercentage
                LockStatus    = $_.LockStatus

            }

        }

    }

    catch {

        @()

    }

}
function Get-NIDefender {

    try {

        $Status = Get-MpComputerStatus

        [PSCustomObject]@{

            AntivirusEnabled      = $Status.AntivirusEnabled
            RealTimeProtection    = $Status.RealTimeProtectionEnabled
            BehaviorMonitor       = $Status.BehaviorMonitorEnabled
            IoavProtection        = $Status.IoavProtectionEnabled
            NISEnabled            = $Status.NISEnabled
            AntivirusVersion      = $Status.AMProductVersion
            EngineVersion         = $Status.AMEngineVersion
            SignatureVersion      = $Status.AntivirusSignatureVersion

        }

    }

    catch {

        $null

    }

}

function Get-NIFirewall {

    try {

        Get-NetFirewallProfile |
        Sort-Object Name |
        ForEach-Object {

            [PSCustomObject]@{

                Profile               = $_.Name
                Enabled               = $_.Enabled
                DefaultInboundAction  = $_.DefaultInboundAction
                DefaultOutboundAction = $_.DefaultOutboundAction

            }

        }

    }

    catch {

        @()

    }

}

function Get-NISecureBoot {

    try {

        [PSCustomObject]@{

            SecureBoot = Confirm-SecureBootUEFI

        }

    }

    catch {

        [PSCustomObject]@{

            SecureBoot = $false

        }

    }

}

function Get-NIUAC {

    try {

        $Value = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        [PSCustomObject]@{

            EnableLUA = $Value.EnableLUA
            ConsentPromptBehaviorAdmin = $Value.ConsentPromptBehaviorAdmin

        }

    }

    catch {

        $null

    }

}
function Get-NISecurity {

    try {

        $Data = [ordered]@{

            TPM        = Get-NITPM

            BitLocker  = Get-NIBitLocker

            Defender   = Get-NIDefender

            Firewall   = Get-NIFirewall

            SecureBoot = Get-NISecureBoot

            UAC        = Get-NIUAC

        }

        [PSCustomObject]@{

            Module    = "Security"

            Success   = $true

            Version   = "2.3.0"

            

            Data      = $Data

        }

    }

    catch {

        [PSCustomObject]@{

            Module    = "Security"

            Success   = $false

            Version   = "2.3.0"

            

            Error     = $_.Exception.Message

        }

    }

}

function Test-Module {

    try {

        (Get-NISecurity).Success

    }

    catch {

        $false

    }

}

Export-ModuleMember -Function `
Get-NISecurity,`
Test-Module
