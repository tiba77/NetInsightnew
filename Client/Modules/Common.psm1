# =====================================================================
# NetInsight
# Module      : Common.psm1
# Version     : 2.3.0
# =====================================================================

Set-StrictMode -Version Latest

#---------------------------------------------------------
# Time
#---------------------------------------------------------

function Get-TimeStamp {

    Get-Date -Format "yyyy-MM-dd HH:mm:ss"

}

#---------------------------------------------------------
# Folder
#---------------------------------------------------------

function Ensure-Folder {

    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    if([string]::IsNullOrWhiteSpace($Folder)){
        return
    }

    if(!(Test-Path $Folder)){

        New-Item `
            -ItemType Directory `
            -Path $Folder `
            -Force | Out-Null

    }

}

#---------------------------------------------------------
# Logging
#---------------------------------------------------------

function Write-Log {

    param(

        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$LogFile

    )

    Ensure-Folder (Split-Path $LogFile)

    Add-Content `
        $LogFile `
        "[$(Get-TimeStamp)] [$Module] $Message"

}

function Write-ErrorLog {

    param(

        [string]$Module,

        [string]$Message,

        [string]$LogFile

    )

    Write-Log `
        -Module $Module `
        -Message "ERROR : $Message" `
        -LogFile $LogFile

}

function Write-DebugLog {

    param(

        [string]$Module,

        [string]$Message,

        [string]$LogFile

    )

    Write-Log `
        -Module $Module `
        -Message "DEBUG : $Message" `
        -LogFile $LogFile

}
#---------------------------------------------------------
# Config
#---------------------------------------------------------

function Read-Config {

    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    if(!(Test-Path $ConfigFile)){
        throw "Config file not found : $ConfigFile"
    }

    $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

    # ساخت مسیرهای Local برای سازگاری با Inventory
    $Root = Split-Path $ConfigFile

    $Config | Add-Member -Force NoteProperty Local ([PSCustomObject]@{

        LogFolder    = Join-Path $Root "Logs"
        OutputFolder = Join-Path $Root "Output"
        CacheFolder  = Join-Path $Root "Cache"
        QueueFolder  = Join-Path $Root "Queue"

    })

    return $Config

}

#---------------------------------------------------------
# JSON
#---------------------------------------------------------

function Save-Json {

    param(

        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string]$File

    )

    Ensure-Folder (Split-Path $File)

    $Object |
        ConvertTo-Json -Depth 20 |
        Set-Content -Encoding UTF8 $File

}

#---------------------------------------------------------
# Date
#---------------------------------------------------------

function Convert-WmiDate {

    param($Date)

    if([string]::IsNullOrWhiteSpace($Date)){
        return $null
    }

    try{

        [System.Management.ManagementDateTimeConverter]::ToDateTime($Date)

    }

    catch{

        $Date

    }

}

#---------------------------------------------------------
# Uptime
#---------------------------------------------------------

function Get-Uptime {

    $OS = Get-CimInstance Win32_OperatingSystem

    $Boot = Convert-WmiDate $OS.LastBootUpTime

    (Get-Date) - $Boot

}
#---------------------------------------------------------
# Server
#---------------------------------------------------------

function Test-ServerPath {

    param(
        [string]$Path
    )

    Test-Path $Path

}

#---------------------------------------------------------
# Safe Invoke
#---------------------------------------------------------

function Invoke-Safe {

    param(
        [scriptblock]$Script
    )

    try {

        & $Script

    }

    catch {

        $null

    }

}

#---------------------------------------------------------
# Merge
#---------------------------------------------------------

function Merge-Objects {

    param(
        [hashtable[]]$Objects
    )

    $Result = @{}

    foreach($Object in $Objects){

        foreach($Key in $Object.Keys){

            $Result[$Key] = $Object[$Key]

        }

    }

    return $Result

}

#---------------------------------------------------------
# Result
#---------------------------------------------------------

function New-ResultObject {

    param(

        [string]$Module,

        [bool]$Success,

        $Data,

        [string]$Error

    )

    [PSCustomObject]@{

        Module     = $Module
        Success    = $Success
        TimeStamp  = Get-TimeStamp
        Data       = $Data
        Error      = $Error

    }

}

#---------------------------------------------------------
# Admin
#---------------------------------------------------------

function Test-IsAdministrator {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

}

#---------------------------------------------------------
# HotFix
#---------------------------------------------------------

function Get-LastHotFix {

    Get-HotFix |
        Sort-Object InstalledOn -Descending |
        Select-Object -First 1

}

#---------------------------------------------------------
# Manual
#---------------------------------------------------------

function Load-ManualInfo {

    param(
        [string]$File
    )

    if(Test-Path $File){

        Get-Content $File -Raw | ConvertFrom-Json

    }

    else{

        $null

    }

}

function Test-Module {

    $true

}
#---------------------------------------------------------
# Normalize Inventory Object
#---------------------------------------------------------

function Normalize-Inventory {

    param(
        [Parameter(Mandatory)]
        $Inventory
    )

    return [PSCustomObject]@{

        Project  = $Inventory.Project
        Version  = $Inventory.Version
        Computer = $Inventory.Computer
        Hardware = $Inventory.Hardware
        Windows  = $Inventory.Windows
        Security = $Inventory.Security

    }

}


Export-ModuleMember -Function *
