# =====================================================================
# NetInsight
# Module      : Hardware.psm1
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

function Get-SystemInfo {

    $CS = Get-CimInstance Win32_ComputerSystem

    [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        Manufacturer = $CS.Manufacturer
        Model        = $CS.Model
        Domain       = $CS.Domain
        TotalRAMGB   = [Math]::Round($CS.TotalPhysicalMemory/1GB,2)

    }

}

function Get-BIOSInfo {

    $BIOS = Get-CimInstance Win32_BIOS

    [PSCustomObject]@{

        Manufacturer = $BIOS.Manufacturer
        Version      = $BIOS.SMBIOSBIOSVersion
        SerialNumber = $BIOS.SerialNumber
        ReleaseDate  = Convert-WmiDate $BIOS.ReleaseDate

    }

}

function Get-MotherboardInfo {

    $Board = Get-CimInstance Win32_BaseBoard

    [PSCustomObject]@{

        Manufacturer = $Board.Manufacturer
        Product      = $Board.Product
        SerialNumber = $Board.SerialNumber

    }

}
function Get-CPUInfo {

    $CPU = Get-CimInstance Win32_Processor

    [PSCustomObject]@{

        Name               = $CPU.Name
        Manufacturer       = $CPU.Manufacturer
        Cores              = $CPU.NumberOfCores
        LogicalProcessors  = $CPU.NumberOfLogicalProcessors
        MaxClockMHz        = $CPU.MaxClockSpeed
        Socket             = $CPU.SocketDesignation

    }

}

function Get-RAMInfo {

    Get-CimInstance Win32_PhysicalMemory |
    ForEach-Object {

        [PSCustomObject]@{

            Manufacturer = $_.Manufacturer
            CapacityGB   = [Math]::Round($_.Capacity / 1GB,2)
            SpeedMHz     = $_.Speed
            SerialNumber = $_.SerialNumber
            PartNumber   = ($_.PartNumber).Trim()

        }

    }

}

function Get-DiskInfo {

    Get-CimInstance Win32_DiskDrive |
    ForEach-Object {

        [PSCustomObject]@{

            Model      = $_.Model
            Serial     = $_.SerialNumber
            SizeGB     = [Math]::Round($_.Size / 1GB,2)
            Interface  = $_.InterfaceType

        }

    }

}
function Get-TPMInfo {

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

function Get-NIHardware {

    try {

        $Data = [ordered]@{

            System       = Get-SystemInfo
            BIOS         = Get-BIOSInfo
            Motherboard  = Get-MotherboardInfo
            CPU          = Get-CPUInfo
            Memory       = Get-RAMInfo
            Disk         = Get-DiskInfo
            TPM          = Get-TPMInfo

        }

        [PSCustomObject]@{

            Module    = "Hardware"
            Success   = $true
            Version   = "2.3.0"
                    Data      = $Data

        }

    }

    catch {

        [PSCustomObject]@{

            Module    = "Hardware"
            Success   = $false
            Version   = "2.3.0"
                    Error     = $_.Exception.Message

        }

    }

}
#---------------------------------------------------------
# Module Self Test
#---------------------------------------------------------

function Test-Module {

    try {

        $Result = Get-NIHardware

        if ($Result.Success) {

            return $true

        }

        return $false

    }

    catch {

        return $false

    }

}

#---------------------------------------------------------
# Export
#---------------------------------------------------------

Export-ModuleMember -Function `
Get-NIHardware,`
Test-Module
