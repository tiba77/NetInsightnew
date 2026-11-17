# =====================================================================
# NetInsight
# Module      : Windows.psm1
# Version     : 2.3.0
# Build       : 002
# =====================================================================

Set-StrictMode -Version Latest

if (-not (Get-Module Common)) {
    Import-Module "$PSScriptRoot\Common.psm1" -Force
}

#---------------------------------------------------------
# PRIVATE
#---------------------------------------------------------

function Get-OSInfo {

    $OS = Get-CimInstance Win32_OperatingSystem

    [PSCustomObject]@{

        Caption      = [string]$OS.Caption
        Version      = [string]$OS.Version
        BuildNumber  = [string]$OS.BuildNumber
        Architecture = [string]$OS.OSArchitecture
        InstallDate  = Convert-WmiDate $OS.InstallDate
        LastBoot     = Convert-WmiDate $OS.LastBootUpTime

    }

}

function Get-ActivationInfo {

    try {

        $License = Get-CimInstance SoftwareLicensingProduct |
            Where-Object {
                $_.PartialProductKey -and $_.LicenseStatus -ne $null
            } |
            Select-Object -First 1

        if ($null -eq $License) {
            return $null
        }

        [PSCustomObject]@{

            LicenseStatus = $License.LicenseStatus
            PartialKey    = $License.PartialProductKey
            Description   = $License.Description

        }

    }

    catch {

        $null

    }

}

function Get-HotFixInfo {

    try {

        Get-HotFix |
            Sort-Object InstalledOn -Descending |
            ForEach-Object {

                [PSCustomObject]@{

                    HotFixID    = $_.HotFixID
                    Description = $_.Description
                    InstalledOn = $_.InstalledOn
                    InstalledBy = $_.InstalledBy

                }

            }

    }

    catch {

        @()

    }

}

function Get-InstalledSoftware {

    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Apps = foreach ($Path in $Paths) {

        foreach ($Item in (Get-ItemProperty $Path -ErrorAction SilentlyContinue)) {

            $DisplayName = if (
                $Item.PSObject.Properties.Match("DisplayName").Count
            ) {
                $Item.DisplayName
            }
            else {
                $null
            }

            if ([string]::IsNullOrWhiteSpace($DisplayName)) {
                continue
            }

            [PSCustomObject]@{

                DisplayName = $DisplayName

                DisplayVersion = if (
                    $Item.PSObject.Properties.Match("DisplayVersion").Count
                ) {
                    $Item.DisplayVersion
                }
                else {
                    $null
                }

                Publisher = if (
                    $Item.PSObject.Properties.Match("Publisher").Count
                ) {
                    $Item.Publisher
                }
                else {
                    $null
                }

                InstallDate = if (
                    $Item.PSObject.Properties.Match("InstallDate").Count
                ) {
                    $Item.InstallDate
                }
                else {
                    $null
                }

            }

        }

    }

    $Apps | Sort-Object DisplayName -Unique

}

function Get-LocalUsers {

    try {

        Get-LocalUser |
            ForEach-Object {

                [PSCustomObject]@{

                    Name                 = $_.Name
                    FullName             = $_.FullName
                    Enabled              = $_.Enabled
                    LastLogon            = $_.LastLogon
                    PasswordRequired     = $_.PasswordRequired
                    PasswordNeverExpires = $_.PasswordNeverExpires

                }

            }

    }

    catch {

        @()

    }

}

function Get-LocalGroups {

    try {

        Get-LocalGroup |
            ForEach-Object {

                [PSCustomObject]@{

                    Name        = $_.Name
                    Description = $_.Description

                }

            }

    }

    catch {

        @()

    }

}

function Get-NIWindows {

    try {

        $Data = [ordered]@{

            OS         = Get-OSInfo
            Activation = Get-ActivationInfo
            HotFixes   = Get-HotFixInfo
            Software   = Get-InstalledSoftware
            Users      = Get-LocalUsers
            Groups     = Get-LocalGroups

        }

        [PSCustomObject]@{

            Module  = "Windows"
            Success = $true
            Version = "2.3.0"
            Data    = $Data

        }

    }

    catch {

        [PSCustomObject]@{

            Module  = "Windows"
            Success = $false
            Version = "2.3.0"
            Error   = $_.Exception.Message

        }

    }

}

function Test-Module {

    try {

        $Result = Get-NIWindows

        return $Result.Success

    }

    catch {

        return $false

    }

}

#---------------------------------------------------------
# EXPORT
#---------------------------------------------------------

Export-ModuleMember -Function `
    Get-NIWindows, `
    Test-Module