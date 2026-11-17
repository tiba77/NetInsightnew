# =====================================================================
# NetInsight
# Query.psm1
# Version : 1.1.0
# =====================================================================

Set-StrictMode -Version Latest

$ModuleVersion = "1.1.0"


# ============================================================
# Status Badge Helper (Color-coded)
# ============================================================

function ConvertTo-NIStatusBadge {
    param([object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return '<span style="color: #9ca3af;">-</span>'
    }

    $text = [string]$Value
    $text = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')

    if ($text -match '^(1|true|yes|enabled|on)$') {
        return '<span style="color: #22c55e; font-weight: bold;">&#10004;</span>'
    }
    if ($text -match '^(0|false|no|disabled|off)$') {
        return '<span style="color: #ef4444; font-weight: bold;">&#10008;</span>'
    }
    return $text
}

function Get-NIInventoryIndex {

    $Root = Split-Path $PSScriptRoot -Parent
    $IndexFile = Join-Path $Root "Data\InventoryIndex.json"

    if (-not (Test-Path $IndexFile)) {
        throw "InventoryIndex.json not found: $IndexFile"
    }

    try {
        return Get-Content $IndexFile -Raw -Encoding UTF8 |
            ConvertFrom-Json
    }
    catch {
        throw "Failed to read InventoryIndex.json : $($_.Exception.Message)"
    }
}

function Get-NIComputers {

    $Index = Get-NIInventoryIndex

    if ($null -eq $Index.Computers) {
        return @()
    }

    return @($Index.Computers)
}

function Get-NIComputer {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computers = Get-NIComputers

    return $Computers |
        Where-Object {
            $_.ComputerName -eq $Name
        } |
        Select-Object -First 1
}

function Find-NIComputer {

    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $Computers = Get-NIComputers

    return $Computers |
        Where-Object {
            $_.ComputerName -like "*$Pattern*" -or
            $_.FileName -like "*$Pattern*"
        }
}

function Get-NIComputerSummary {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    $Inventory = $Computer.Inventory

    $Hardware = $Inventory.Hardware.Data
    $Windows  = $Inventory.Windows.Data
    $Security = $Inventory.Security.Data

    # -------------------------
    # CPU
    # -------------------------

    $CPUName = $null
    $CPUCores = $null
    $LogicalProcessors = $null

    if ($null -ne $Hardware.CPU) {
        $CPUName = $Hardware.CPU.Name
        $CPUCores = $Hardware.CPU.Cores
        $LogicalProcessors = $Hardware.CPU.LogicalProcessors
    }

    # -------------------------
    # Memory
    # -------------------------

    $MemoryModules = @()

    if ($null -ne $Hardware.Memory) {
        $MemoryModules = @($Hardware.Memory)
    }

    # -------------------------
    # Disk
    # -------------------------

    $Disks = @()

    if ($null -ne $Hardware.Disk) {
        $Disks = @($Hardware.Disk)
    }

    # -------------------------
    # Firewall
    # -------------------------

    $FirewallDomain  = $null
    $FirewallPrivate = $null
    $FirewallPublic  = $null

    if ($null -ne $Security.Firewall) {

        $FirewallProfiles = @($Security.Firewall)

        $DomainProfile = $FirewallProfiles |
            Where-Object { $_.Profile -eq "Domain" } |
            Select-Object -First 1

        $PrivateProfile = $FirewallProfiles |
            Where-Object { $_.Profile -eq "Private" } |
            Select-Object -First 1

        $PublicProfile = $FirewallProfiles |
            Where-Object { $_.Profile -eq "Public" } |
            Select-Object -First 1

        if ($null -ne $DomainProfile) {
            $FirewallDomain = $DomainProfile.Enabled
        }

        if ($null -ne $PrivateProfile) {
            $FirewallPrivate = $PrivateProfile.Enabled
        }

        if ($null -ne $PublicProfile) {
            $FirewallPublic = $PublicProfile.Enabled
        }
    }

    # -------------------------
    # Secure Boot
    # -------------------------

    $SecureBoot = $null

    if ($null -ne $Security.SecureBoot) {
        $SecureBoot = $Security.SecureBoot.SecureBoot
    }

    # -------------------------
    # UAC
    # -------------------------

    $UACEnabled = $null

    if ($null -ne $Security.UAC) {
        $UACEnabled = $Security.UAC.EnableLUA
    }

    # -------------------------
    # BitLocker
    # -------------------------

    $BitLockerEnabled = $null

    if ($null -ne $Inventory.Security.BitLocker) {
        $BitLockerEnabled = $Inventory.Security.BitLocker.Enabled
    }

    # -------------------------
    # Defender
    # -------------------------

    $DefenderEnabled = $null

    if ($null -ne $Inventory.Security.Defender) {
        $DefenderEnabled = $Inventory.Security.Defender.Enabled
    }

    # -------------------------
    # Result
    # -------------------------

    [PSCustomObject]@{
        Computer          = $Computer.ComputerName
        Project           = $Computer.Project
        Version           = $Computer.Version
        Created           = $Computer.Created

        OS                = $Windows.OS.Caption
        OSVersion         = $Windows.OS.Version
        OSBuild           = $Windows.OS.BuildNumber

        CPU               = $CPUName
        CPUCores          = $CPUCores
        LogicalProcessors = $LogicalProcessors

        TotalRAMGB        = $Hardware.System.TotalRAMGB
        RAMModules        = $MemoryModules.Count

        DiskCount         = $Disks.Count

        SecureBoot        = $SecureBoot

        FirewallDomain    = $FirewallDomain
        FirewallPrivate   = $FirewallPrivate
        FirewallPublic    = $FirewallPublic

        UAC               = $UACEnabled

        BitLocker         = $BitLockerEnabled

        Defender          = $DefenderEnabled
    }
}

function Get-NIStatistics {

    $Index = Get-NIInventoryIndex

    [PSCustomObject]@{
        CollectorVersion = $Index.Collector.Version
        CollectorTime    = $Index.Collector.Time
        FilesFound       = $Index.Statistics.FilesFound
        FilesRead        = $Index.Statistics.FilesRead
        FilesFailed      = $Index.Statistics.FilesFailed
        Computers        = @($Index.Computers).Count
        Rejected         = @($Index.Rejected).Count
    }
}

function Test-Module {

    [PSCustomObject]@{
        Module  = "Query"
        Success = $true
        Version = $ModuleVersion
    }
}

function Get-NIOS {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return $Computer.Inventory.Windows.Data.OS
}

function Get-NICPU {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return $Computer.Inventory.Hardware.Data.CPU
}

function Get-NIRAM {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return $Computer.Inventory.Hardware.Data.Memory
}

function Get-NIDisk {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return @(
        $Computer.Inventory.Hardware.Data.Disk
    )
}

function Get-NINetwork {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return $Computer.Inventory.Network.Data
}

function Get-NISecurity {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return $Computer.Inventory.Security.Data
}

function Get-NISoftware {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Computer = Get-NIComputer -Name $Name

    if ($null -eq $Computer) {
        throw "Computer not found: $Name"
    }

    return @(
        $Computer.Inventory.Windows.Data.Software
    )
}

function Find-NIOSComputer {

    param(
        [Parameter(Mandatory)]
        [string]$OSPattern
    )

    return @(
        Get-NIComputers |
            Where-Object {
                $_.Inventory.Windows.Data.OS.Caption -like "*$OSPattern*"
            }
    )
}

function Find-NICPUComputer {

    param(
        [Parameter(Mandatory)]
        [string]$CPUPattern
    )

    return @(
        Get-NIComputers |
            Where-Object {
                $_.Inventory.Hardware.Data.CPU.Name -like "*$CPUPattern*"
            }
    )
}

function Find-NIRAMComputer {

    param(
        [Parameter(Mandatory)]
        [double]$MinimumGB
    )

    return @(
        Get-NIComputers |
            Where-Object {
                $_.Inventory.Hardware.Data.System.TotalRAMGB -ge $MinimumGB
            }
    )
}

function Find-NISecureBoot {

    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    return @(
        Get-NIComputers |
            Where-Object {
                $_.Inventory.Security.Data.SecureBoot.SecureBoot -eq $Enabled
            }
    )
}

function Find-NIFirewall {

    param(
        [ValidateSet("Domain","Private","Public")]
        [string]$Profile,

        [Parameter(Mandatory)]
        [int]$Enabled
    )

    return @(
        Get-NIComputers |
            Where-Object {

                $Profiles = @($_.Inventory.Security.Data.Firewall)

                $Target = $Profiles |
                    Where-Object {
                        $_.Profile -eq $Profile
                    } |
                    Select-Object -First 1

                $null -ne $Target -and
                $Target.Enabled -eq $Enabled
            }
    )
}

function Search-NIComputer {

    param(
        [string]$OS,
        [string]$CPU,
        [double]$MinRAM,
        [double]$MaxRAM,
        [bool]$SecureBoot,
        [int]$FirewallDomain,
        [int]$FirewallPrivate,
        [int]$FirewallPublic
    )

    $Computers = @(Get-NIComputers)

    $Results = foreach ($Computer in $Computers) {

        $Inventory = $Computer.Inventory

        $Hardware = $Inventory.Hardware.Data
        $Windows  = $Inventory.Windows.Data
        $Security = $Inventory.Security.Data

        $Match = $true

        if ($PSBoundParameters.ContainsKey("OS")) {
            $Caption = [string]$Windows.OS.Caption
            if ($Caption -notlike "*$OS*") {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("CPU")) {
            $CPUName = [string]$Hardware.CPU.Name
            if ($CPUName -notlike "*$CPU*") {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("MinRAM")) {
            $RAM = [double]$Hardware.System.TotalRAMGB
            if ($RAM -lt $MinRAM) {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("MaxRAM")) {
            $RAM = [double]$Hardware.System.TotalRAMGB
            if ($RAM -gt $MaxRAM) {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("SecureBoot")) {
            $SB = [bool]$Security.SecureBoot.SecureBoot
            if ($SB -ne $SecureBoot) {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("FirewallDomain")) {
            $Profiles = @($Security.Firewall)
            $Profile = $Profiles | Where-Object { $_.Profile -eq "Domain" } | Select-Object -First 1
            if ($null -eq $Profile) {
                $Match = $false
            }
            elseif ([int]$Profile.Enabled -ne $FirewallDomain) {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("FirewallPrivate")) {
            $Profiles = @($Security.Firewall)
            $Profile = $Profiles | Where-Object { $_.Profile -eq "Private" } | Select-Object -First 1
            if ($null -eq $Profile) {
                $Match = $false
            }
            elseif ([int]$Profile.Enabled -ne $FirewallPrivate) {
                $Match = $false
            }
        }

        if ($Match -and $PSBoundParameters.ContainsKey("FirewallPublic")) {
            $Profiles = @($Security.Firewall)
            $Profile = $Profiles | Where-Object { $_.Profile -eq "Public" } | Select-Object -First 1
            if ($null -eq $Profile) {
                $Match = $false
            }
            elseif ([int]$Profile.Enabled -ne $FirewallPublic) {
                $Match = $false
            }
        }

        if ($Match) {
            $Computer
        }
    }

    return @($Results)
}

function Get-NIQueryResult {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Computers
    )

    begin {

        function Get-NIQRPropertyValue {
            param([object]$InputObject, [string[]]$Names)
            if ($null -eq $InputObject -or $null -eq $Names) { return $null }
            foreach ($name in $Names) {
                if ($InputObject -is [System.Collections.IDictionary]) {
                    foreach ($key in $InputObject.Keys) {
                        if ([string]$key -eq $name) { return $InputObject[$key] }
                    }
                }
                elseif ($InputObject.PSObject.Properties[$name]) {
                    return $InputObject.PSObject.Properties[$name].Value
                }
            }
            return $null
        }

        function Get-NIQRPathValue {
            param([object]$InputObject, [string[]]$Path)
            if ($null -eq $InputObject -or $null -eq $Path) { return $null }
            $current = $InputObject
            foreach ($part in $Path) {
                if ($null -eq $current) { return $null }
                if ($current -is [System.Collections.IDictionary]) {
                    $found = $false
                    foreach ($key in $current.Keys) {
                        if ([string]$key -eq $part) {
                            $current = $current[$key]
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) { return $null }
                }
                elseif ($current.PSObject.Properties[$part]) {
                    $current = $current.PSObject.Properties[$part].Value
                }
                else { return $null }
            }
            return $current
        }

        function Get-NIQRFirstItem {
            param([object]$Value)
            if ($null -eq $Value) { return $null }
            if ($Value -is [string]) { return $Value }
            if ($Value -is [System.Collections.IEnumerable]) {
                $items = @($Value)
                if ($items.Count -eq 0) { return $null }
                return $items[0]
            }
            return $Value
        }

        function Get-NIQRCollectionCount {
            param([object]$Value)
            if ($null -eq $Value) { return 0 }
            if ($Value -is [string]) { return 1 }
            if ($Value -is [System.Collections.IEnumerable]) { return @($Value).Count }
            return 1
        }

        function Get-NIQRFirewallProfile {
            param([object]$Firewall, [string]$ProfileName)
            if ($null -eq $Firewall) { return $null }
            foreach ($item in @($Firewall)) {
                if ($null -eq $item) { continue }
                $profileNameVal = Get-NIQRPropertyValue -InputObject $item -Names @('Profile', 'Name', 'ProfileName')
                if ($profileNameVal -eq $ProfileName) {
                    return Get-NIQRPropertyValue -InputObject $item -Names @('Enabled', 'IsEnabled', 'Value')
                }
            }
            return $null
        }

        function New-NIQueryResultObject {
            param([hashtable]$Values)
            if ($null -eq $Values) { $Values = @{} }
            $standardColumns = @(
                'ComputerName','OS','OSVersion','OSBuild','CPU','CPUCores',
                'LogicalProcessors','TotalRAMGB','DiskCount','SecureBoot',
                'FirewallDomain','FirewallPrivate','FirewallPublic','UAC',
                'BitLocker','Defender','Rdp',
                'InventoryVersion','InventoryCreated'
            )
            $ordered = [ordered]@{}
            foreach ($column in $standardColumns) {
                if ($Values.ContainsKey($column)) { $ordered[$column] = $Values[$column] }
                else { $ordered[$column] = $null }
            }
            return New-Object -TypeName PSObject -Property $ordered
        }

        function Convert-NIRawInventoryToQueryResult {
            param([object]$Inventory)
            $system = Get-NIQRPathValue -InputObject $Inventory -Path @('Hardware', 'Data', 'System')
            $cpu = Get-NIQRPathValue -InputObject $Inventory -Path @('Hardware', 'Data', 'CPU')
            $disk = Get-NIQRPathValue -InputObject $Inventory -Path @('Hardware', 'Data', 'Disk')
            $os = Get-NIQRPathValue -InputObject $Inventory -Path @('Windows', 'Data', 'OS')
            $securityData = Get-NIQRPathValue -InputObject $Inventory -Path @('Security', 'Data')
            $secureBootNode = Get-NIQRPathValue -InputObject $securityData -Path @('SecureBoot')
            $firewall = Get-NIQRPathValue -InputObject $securityData -Path @('Firewall')
            $uacNode = Get-NIQRPathValue -InputObject $securityData -Path @('UAC')
            $bitLockerNode = Get-NIQRPathValue -InputObject $Inventory -Path @('Security', 'BitLocker')
            $defenderNode = Get-NIQRPathValue -InputObject $Inventory -Path @('Security', 'Defender')

            $system = Get-NIQRFirstItem -Value $system
            $cpu = Get-NIQRFirstItem -Value $cpu
            $os = Get-NIQRFirstItem -Value $os
            $secureBootNode = Get-NIQRFirstItem -Value $secureBootNode
            $uacNode = Get-NIQRFirstItem -Value $uacNode
            $bitLockerNode = Get-NIQRFirstItem -Value $bitLockerNode
            $defenderNode = Get-NIQRFirstItem -Value $defenderNode

            $secureBoot = $null
            if ($secureBootNode -is [bool] -or $secureBootNode -is [int] -or $secureBootNode -is [string]) { $secureBoot = $secureBootNode }
            else { $secureBoot = Get-NIQRPropertyValue -InputObject $secureBootNode -Names @('SecureBoot', 'Value') }

            $uac = $null
            if ($uacNode -is [bool] -or $uacNode -is [int] -or $uacNode -is [string]) { $uac = $uacNode }
            else { $uac = Get-NIQRPropertyValue -InputObject $uacNode -Names @('EnableLUA', 'Enabled', 'Value') }
            $bitLocker = $null
            if ($bitLockerNode -is [bool] -or $bitLockerNode -is [int] -or $bitLockerNode -is [string]) {
                $bitLocker = $bitLockerNode
            } else {
                $bitLocker = Get-NIQRPropertyValue -InputObject $bitLockerNode -Names @('Enabled', 'Value')
            }
            $defender = $null
            if ($defenderNode -is [bool] -or $defenderNode -is [int] -or $defenderNode -is [string]) {
                $defender = $defenderNode
            } else {
                $defender = Get-NIQRPropertyValue -InputObject $defenderNode -Names @('Enabled', 'Value')
            }
            $rdp = $null
            if ($null -ne $Inventory -and $Inventory.PSObject.Properties['Security']) {
                $securityObj = $Inventory.Security
                if ($null -ne $securityObj -and $securityObj.PSObject.Properties['Rdp']) {
                    $rdpNode = $securityObj.Rdp
                    if ($rdpNode -is [bool] -or $rdpNode -is [int] -or $rdpNode -is [string]) { $rdp = $rdpNode }
                    elseif ($null -ne $rdpNode -and $rdpNode.PSObject.Properties['Enabled']) { $rdp = $rdpNode.Enabled }
                }
            }

            $values = @{
                ComputerName      = Get-NIQRPropertyValue -InputObject $Inventory -Names @('Computer', 'ComputerName', 'Name')
                OS                = Get-NIQRPropertyValue -InputObject $os -Names @('Caption')
                OSVersion         = Get-NIQRPropertyValue -InputObject $os -Names @('Version')
                OSBuild           = Get-NIQRPropertyValue -InputObject $os -Names @('BuildNumber')
                CPU               = Get-NIQRPropertyValue -InputObject $cpu -Names @('Name', 'Caption', 'DeviceID', 'ProcessorName')
                CPUCores          = Get-NIQRPropertyValue -InputObject $cpu -Names @('Cores', 'NumberOfCores')
                LogicalProcessors = Get-NIQRPropertyValue -InputObject $cpu -Names @('LogicalProcessors', 'NumberOfLogicalProcessors')
                TotalRAMGB        = Get-NIQRPropertyValue -InputObject $system -Names @('TotalRAMGB', 'TotalPhysicalMemoryGB')
                DiskCount         = Get-NIQRCollectionCount -Value $disk
                SecureBoot        = $secureBoot
                FirewallDomain    = Get-NIQRFirewallProfile -Firewall $firewall -ProfileName 'Domain'
                FirewallPrivate   = Get-NIQRFirewallProfile -Firewall $firewall -ProfileName 'Private'
                FirewallPublic    = Get-NIQRFirewallProfile -Firewall $firewall -ProfileName 'Public'
                UAC               = $uac
                BitLocker         = $bitLocker
                Defender          = $defender
                Rdp               = $rdp
                InventoryVersion  = Get-NIQRPropertyValue -InputObject $Inventory -Names @('Version', 'InventoryVersion')
                InventoryCreated  = Get-NIQRPropertyValue -InputObject $Inventory -Names @('Created', 'InventoryCreated')
            }

            if ([string]::IsNullOrWhiteSpace([string]$values['ComputerName'])) {
                $values['ComputerName'] = Get-NIQRPropertyValue -InputObject $system -Names @('ComputerName', 'Name')
            }

            return New-NIQueryResultObject -Values $values
        }

        function Get-NIRdpValueFromSummary {
            param([object]$Summary)
            if ($null -eq $Summary) { return $null }
            $direct = Get-NIQRPropertyValue -InputObject $Summary -Names @('Rdp')
            if ($null -ne $direct) { return $direct }
            $inv = Get-NIQRPropertyValue -InputObject $Summary -Names @('Inventory')
            $node = Get-NIQRPathValue -InputObject $inv -Path @('Security', 'Rdp')
            if ($null -eq $node) { return $null }
            if ($node -is [bool] -or $node -is [int] -or $node -is [string]) { return $node }
            return Get-NIQRPropertyValue -InputObject $node -Names @('Enabled', 'Value')
        }
        function Convert-NISummaryObjectToQueryResult {
            param([object]$Summary)
            if ($Summary -is [string]) {
                return New-NIQueryResultObject -Values @{ ComputerName = $Summary }
            }
            $values = @{
                ComputerName      = Get-NIQRPropertyValue -InputObject $Summary -Names @('ComputerName', 'Computer', 'Name')
                OS                = Get-NIQRPropertyValue -InputObject $Summary -Names @('OS', 'OperatingSystem')
                OSVersion         = Get-NIQRPropertyValue -InputObject $Summary -Names @('OSVersion', 'Version')
                OSBuild           = Get-NIQRPropertyValue -InputObject $Summary -Names @('OSBuild', 'Build', 'BuildNumber')
                CPU               = Get-NIQRPropertyValue -InputObject $Summary -Names @('CPU', 'Processor')
                CPUCores          = Get-NIQRPropertyValue -InputObject $Summary -Names @('CPUCores', 'Cores')
                LogicalProcessors = Get-NIQRPropertyValue -InputObject $Summary -Names @('LogicalProcessors')
                TotalRAMGB        = Get-NIQRPropertyValue -InputObject $Summary -Names @('TotalRAMGB', 'RAMGB')
                DiskCount         = Get-NIQRPropertyValue -InputObject $Summary -Names @('DiskCount')
                SecureBoot        = Get-NIQRPropertyValue -InputObject $Summary -Names @('SecureBoot')
                FirewallDomain    = Get-NIQRPropertyValue -InputObject $Summary -Names @('FirewallDomain')
                FirewallPrivate   = Get-NIQRPropertyValue -InputObject $Summary -Names @('FirewallPrivate')
                FirewallPublic    = Get-NIQRPropertyValue -InputObject $Summary -Names @('FirewallPublic')
                UAC               = Get-NIQRPropertyValue -InputObject $Summary -Names @('UAC')
                BitLocker         = Get-NIQRPropertyValue -InputObject $Summary -Names @('BitLocker')
                Defender          = Get-NIQRPropertyValue -InputObject $Summary -Names @('Defender')
                Rdp               = (Get-NIRdpValueFromSummary -Summary $Summary)
                InventoryVersion  = Get-NIQRPropertyValue -InputObject $Summary -Names @('InventoryVersion', 'Version')
                InventoryCreated  = Get-NIQRPropertyValue -InputObject $Summary -Names @('InventoryCreated', 'Created')
            }
            return New-NIQueryResultObject -Values $values
        }
    }

    process {
        if ($null -eq $Computers -or @($Computers).Count -eq 0) { return @() }

        $results = New-Object System.Collections.Generic.List[object]

        foreach ($item in @($Computers)) {
            if ($null -eq $item) { continue }

            $targetName = $null
            if ($item -is [string]) { $targetName = $item }
            else { $targetName = Get-NIQRPropertyValue -InputObject $item -Names @('Computer', 'ComputerName', 'Name') }

            $summaryFound = $false
            if (-not [string]::IsNullOrWhiteSpace($targetName)) {
                try {
                    $summaries = @(Get-NIComputerSummary -Name $targetName -ErrorAction Stop)
                    foreach ($summary in $summaries) {
                        if ($null -ne $summary) {
                            $convertedSummary = Convert-NISummaryObjectToQueryResult -Summary $summary
                            if ($null -ne $convertedSummary -and $null -eq $convertedSummary.Rdp) {
                                $rdpNode = Get-NIQRPathValue -InputObject $item -Path @('Security', 'Rdp')
                                if ($null -eq $rdpNode) {
                                    $itemInv = Get-NIQRPropertyValue -InputObject $item -Names @('Inventory')
                                    $rdpNode = Get-NIQRPathValue -InputObject $itemInv -Path @('Security', 'Rdp')
                                }
                                if ($null -eq $rdpNode) {
                                    $sumInv = Get-NIQRPropertyValue -InputObject $summary -Names @('Inventory')
                                    $rdpNode = Get-NIQRPathValue -InputObject $sumInv -Path @('Security', 'Rdp')
                                }
                                if ($null -eq $rdpNode) { $rdpNode = Get-NIQRPathValue -InputObject $summary -Path @('Security', 'Rdp') }
                                if ($null -ne $rdpNode) {
                                    if ($rdpNode -is [bool] -or $rdpNode -is [int] -or $rdpNode -is [string]) { $convertedSummary.Rdp = $rdpNode }
                                    elseif ($rdpNode.PSObject.Properties['Enabled']) { $convertedSummary.Rdp = $rdpNode.Enabled }
                                }
                            }
                            $results.Add($convertedSummary)
                            $summaryFound = $true
                        }
                    }
                }
                catch { $summaryFound = $false }

                if ($summaryFound) { continue }
            }

            $converted = $null
            if ($item -isnot [string]) {
                $hardwareNode = Get-NIQRPropertyValue -InputObject $item -Names @('Hardware')
                $windowsNode = Get-NIQRPropertyValue -InputObject $item -Names @('Windows')
                $securityNode = Get-NIQRPropertyValue -InputObject $item -Names @('Security')

                if (($null -ne $hardwareNode) -and ($null -ne $windowsNode) -and ($null -ne $securityNode)) {
                    $converted = Convert-NIRawInventoryToQueryResult -Inventory $item
                }
            }

            if (-not $converted) { $converted = Convert-NISummaryObjectToQueryResult -Summary $item }
            if ($null -ne $converted) { $results.Add($converted) }
        }

        return $results.ToArray()
    }
}

function Export-NIQueryResult {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Computers,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('CSV', 'JSON')]
        [string]$Format = 'CSV'
    )

    $Format = $Format.ToUpper()
    $standardColumns = @(
        'ComputerName','OS','OSVersion','OSBuild','CPU','CPUCores',
        'LogicalProcessors','TotalRAMGB','DiskCount','SecureBoot',
        'FirewallDomain','FirewallPrivate','FirewallPublic','UAC',
        'BitLocker','Defender','Rdp',
        'InventoryVersion','InventoryCreated'
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $items = @()
    if ($null -ne $Computers -and @($Computers).Count -gt 0) {
        $items = @(Get-NIQueryResult -Computers $Computers)
    }

    if ($items.Count -eq 0) {
        if ($Format -eq 'JSON') { Set-Content -Path $Path -Value '[]' -Encoding UTF8 }
        else { Set-Content -Path $Path -Value ($standardColumns -join ',') -Encoding UTF8 }
        return
    }

    $normalized = @($items | ForEach-Object {
        if ($null -eq $_) { return }
        $ordered = [ordered]@{}
        foreach ($column in $standardColumns) {
            if ($_.PSObject.Properties[$column]) { $ordered[$column] = $_.PSObject.Properties[$column].Value }
            else { $ordered[$column] = $null }
        }
        New-Object -TypeName PSObject -Property $ordered
    })

    if ($normalized.Count -eq 0) {
        if ($Format -eq 'JSON') { Set-Content -Path $Path -Value '[]' -Encoding UTF8 }
        else { Set-Content -Path $Path -Value ($standardColumns -join ',') -Encoding UTF8 }
        return
    }

    if ($Format -eq 'CSV') {
        $normalized | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    else {
        $json = ConvertTo-Json -InputObject @($normalized) -Depth 20
        if ($json -notmatch '^\s*\[') { $json = "[$json]" }
        Set-Content -Path $Path -Value $json -Encoding UTF8
    }
}

function Test-NIReportNumericLessThan {
    param([object]$Value, [double]$Threshold)
    if ($null -eq $Value) { return $false }
    try { return ([double]$Value -lt $Threshold) } catch { return $false }
}

function Test-NIReportDisabled {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return (-not $Value) }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    return ($text -match '^(0|false|no|disabled|off)$')
}

function Get-NIReportAllComputers {
    [CmdletBinding()]
    param()
    $computers = @()
    try { $computers = @(Get-NIComputers -ErrorAction Stop) } catch { $computers = @() }
    return @(Get-NIQueryResult -Computers $computers)
}

function Get-NIReportDefinition {
    [CmdletBinding()]
    param()
    return @(
        [PSCustomObject]@{ Name = 'AllComputers'; Description = 'All registered computers' }
        [PSCustomObject]@{ Name = 'Windows10'; Description = 'Computers running Windows 10' }
        [PSCustomObject]@{ Name = 'LowMemory'; Description = 'Computers with less than 8 GB RAM' }
        [PSCustomObject]@{ Name = 'SecureBootDisabled'; Description = 'Computers with SecureBoot disabled' }
        [PSCustomObject]@{ Name = 'FirewallDisabledAny'; Description = 'Computers with any firewall profile disabled' }
        [PSCustomObject]@{ Name = 'FirewallDomainDisabled'; Description = 'Computers with Domain firewall disabled' }
        [PSCustomObject]@{ Name = 'FirewallPrivateDisabled'; Description = 'Computers with Private firewall disabled' }
        [PSCustomObject]@{ Name = 'FirewallPublicDisabled'; Description = 'Computers with Public firewall disabled' }
        [PSCustomObject]@{ Name = 'UACDisabled'; Description = 'Computers with UAC disabled' }
    )
}

function Get-NIReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('AllComputers','Windows10','LowMemory','SecureBootDisabled','FirewallDisabledAny','FirewallDomainDisabled','FirewallPrivateDisabled','FirewallPublicDisabled','UACDisabled')]
        [string]$Name
    )

    switch ($Name) {
        'AllComputers' { return @(Get-NIReportAllComputers) }
        'Windows10' {
            $raw = @()
            try { $raw = @(Search-NIComputer -OS 'Windows 10' -ErrorAction Stop) } catch { $raw = @() }
            return @(Get-NIQueryResult -Computers $raw)
        }
        'LowMemory' {
            $all = @(Get-NIReportAllComputers)
            return @($all | Where-Object { Test-NIReportNumericLessThan -Value $_.TotalRAMGB -Threshold 8 })
        }
        'SecureBootDisabled' {
            $raw = @()
            try { $raw = @(Search-NIComputer -SecureBoot $false -ErrorAction Stop) } catch { $raw = @() }
            return @(Get-NIQueryResult -Computers $raw)
        }
        'FirewallDisabledAny' {
            $all = @(Get-NIReportAllComputers)
            return @($all | Where-Object { (Test-NIReportDisabled -Value $_.FirewallDomain) -or (Test-NIReportDisabled -Value $_.FirewallPrivate) -or (Test-NIReportDisabled -Value $_.FirewallPublic) })
        }
        'FirewallDomainDisabled' {
            $all = @(Get-NIReportAllComputers)
            return @($all | Where-Object { Test-NIReportDisabled -Value $_.FirewallDomain })
        }
        'FirewallPrivateDisabled' {
            $all = @(Get-NIReportAllComputers)
            return @($all | Where-Object { Test-NIReportDisabled -Value $_.FirewallPrivate })
        }
        'FirewallPublicDisabled' {
            $all = @(Get-NIReportAllComputers)
            return @($all | Where-Object { Test-NIReportDisabled -Value $_.FirewallPublic })
        }
        'UACDisabled' {
            $all = @(Get-NIReportAllComputers)
            return @($all | Where-Object { Test-NIReportDisabled -Value $_.UAC })
        }
    }
}

function Export-NIReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('AllComputers','Windows10','LowMemory','SecureBootDisabled','FirewallDisabledAny','FirewallDomainDisabled','FirewallPrivateDisabled','FirewallPublicDisabled','UACDisabled')]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('CSV', 'JSON')]
        [string]$Format = 'CSV'
    )
    $data = @(Get-NIReport -Name $Name)
    Export-NIQueryResult -Computers $data -Path $Path -Format $Format
}

function Get-NIDashboardSummary {
    [CmdletBinding()]
    param()

    begin {
        function Get-NIDashboardPropertyValue {
            param([object]$InputObject, [string]$Name)
            if ($null -eq $InputObject) { return $null }
            if ($InputObject.PSObject.Properties[$Name]) { return $InputObject.PSObject.Properties[$Name].Value }
            return $null
        }
        function Get-NIDashboardDoubleValue {
            param([object]$Value)
            if ($null -eq $Value) { return $null }
            try { return [double]$Value } catch { return $null }
        }
        function Test-NIDashboardDisabledValue {
            param([object]$Value)
            if ($null -eq $Value) { return $false }
            if ($Value -is [bool]) { return (-not $Value) }
            $text = [string]$Value
            if ([string]::IsNullOrWhiteSpace($text)) { return $false }
            return ($text -match '^(0|false|no|disabled|off)$')
        }
        function Test-NIDashboardEnabledValue {
            param([object]$Value)
            if ($null -eq $Value) { return $false }
            if ($Value -is [bool]) { return $Value }
            $text = [string]$Value
            if ([string]::IsNullOrWhiteSpace($text)) { return $false }
            return ($text -match '^(1|true|yes|enabled|on)$')
        }
    }

    process {
        $rawComputers = @()
        try { $rawComputers = @(Get-NIComputers -ErrorAction Stop) } catch { $rawComputers = @() }
        $all = @(Get-NIQueryResult -Computers $rawComputers)

        $stats = $null
        try { $stats = Get-NIStatistics -ErrorAction Stop } catch { $stats = $null }

        $collectorVersion = Get-NIDashboardPropertyValue -InputObject $stats -Name 'CollectorVersion'
        $filesFound = Get-NIDashboardPropertyValue -InputObject $stats -Name 'FilesFound'
        $filesRead = Get-NIDashboardPropertyValue -InputObject $stats -Name 'FilesRead'
        $filesFailed = Get-NIDashboardPropertyValue -InputObject $stats -Name 'FilesFailed'

        $windows10 = @($all | Where-Object { $_.OS -like '*Windows 10*' })
        $lowMemory = @($all | Where-Object { $ram = Get-NIDashboardDoubleValue -Value $_.TotalRAMGB; ($null -ne $ram) -and ($ram -lt 8) })

        $secureBootEnabled = @($all | Where-Object { Test-NIDashboardEnabledValue -Value $_.SecureBoot })
        $secureBootDisabled = @($all | Where-Object { Test-NIDashboardDisabledValue -Value $_.SecureBoot })

        $firewallAllEnabled = @($all | Where-Object { (Test-NIDashboardEnabledValue -Value $_.FirewallDomain) -and (Test-NIDashboardEnabledValue -Value $_.FirewallPrivate) -and (Test-NIDashboardEnabledValue -Value $_.FirewallPublic) })
        $firewallAnyDisabled = @($all | Where-Object { (Test-NIDashboardDisabledValue -Value $_.FirewallDomain) -or (Test-NIDashboardDisabledValue -Value $_.FirewallPrivate) -or (Test-NIDashboardDisabledValue -Value $_.FirewallPublic) })

        $uacEnabled = @($all | Where-Object { Test-NIDashboardEnabledValue -Value $_.UAC })
        $uacDisabled = @($all | Where-Object { Test-NIDashboardDisabledValue -Value $_.UAC })

        $bitlockerEnabled = @($all | Where-Object { Test-NIDashboardEnabledValue -Value $_.BitLocker })
        $bitlockerDisabled = @($all | Where-Object { Test-NIDashboardDisabledValue -Value $_.BitLocker })
        $defenderEnabled = @($all | Where-Object { Test-NIDashboardEnabledValue -Value $_.Defender })
        $defenderDisabled = @($all | Where-Object { Test-NIDashboardDisabledValue -Value $_.Defender })
        $rdpEnabled = @($all | Where-Object { Test-NIDashboardEnabledValue -Value $_.Rdp })
        $rdpDisabled = @($all | Where-Object { Test-NIDashboardDisabledValue -Value $_.Rdp })

        $ramValues = @($all | ForEach-Object { Get-NIDashboardDoubleValue -Value $_.TotalRAMGB } | Where-Object { $null -ne $_ })
        $averageRam = 0; $minRam = 0; $maxRam = 0
        if ($ramValues.Count -gt 0) {
            $measure = $ramValues | Measure-Object -Average -Minimum -Maximum
            $averageRam = [math]::Round($measure.Average, 2)
            $minRam = $measure.Minimum
            $maxRam = $measure.Maximum
        }

        $totalDiskCount = 0
        foreach ($item in $all) {
            $diskCount = Get-NIDashboardDoubleValue -Value $item.DiskCount
            if ($null -ne $diskCount) { $totalDiskCount += [int]$diskCount }
        }

        return [PSCustomObject][ordered]@{
            Generated              = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            CollectorVersion       = $collectorVersion
            FilesFound             = $filesFound
            FilesRead              = $filesRead
            FilesFailed            = $filesFailed
            TotalComputers         = $all.Count
            Windows10Computers     = $windows10.Count
            LowMemoryComputers     = $lowMemory.Count
            AverageRamGB           = $averageRam
            MinRamGB               = $minRam
            MaxRamGB               = $maxRam
            TotalDiskCount         = $totalDiskCount
            SecureBootEnabled      = $secureBootEnabled.Count
            SecureBootDisabled     = $secureBootDisabled.Count
            FirewallAllEnabled     = $firewallAllEnabled.Count
            FirewallAnyDisabled    = $firewallAnyDisabled.Count
            UACEnabled             = $uacEnabled.Count
            UACDisabled            = $uacDisabled.Count
            BitLockerEnabled = $bitlockerEnabled.Count
            BitLockerDisabled = $bitlockerDisabled.Count
            DefenderEnabled = $defenderEnabled.Count
            DefenderDisabled = $defenderDisabled.Count
            RdpEnabled = $rdpEnabled.Count
            RdpDisabled = $rdpDisabled.Count
            Computers              = $all
        }
    }
}


function Get-NIHistoryChanges {
    param([string]$HistoryDir = "C:\NetInsight-Project\Data\History")
    $f = Join-Path $HistoryDir 'changes-latest.json'
    if (-not (Test-Path $f)) { return @() }
    try {
        $d = Get-Content $f -Raw | ConvertFrom-Json
        if ($null -eq $d) { return @() }
        return @($d)
    } catch { return @() }
}

function ConvertTo-NIHistoryHtml {
    param($Changes)
    $Changes = @($Changes)
    if ($Changes.Count -eq 0 -or ($Changes.Count -eq 1 -and $null -eq $Changes[0])) {
        return '<h2>Recent Changes</h2><div class="history-empty">No recent changes</div>'
    }
    $h = '<h2>Recent Changes</h2>'
    $h += '<table class="history-table"><thead><tr><th>Computer</th><th>Type</th><th>Details</th></tr></thead><tbody>'
    foreach ($c in $Changes) {
        if ($null -eq $c) { continue }
        $t = if ($null -ne $c.Type) { $c.Type } else { 'Unknown' }
        $cls = switch ($t) { 'Improved' {'improved'} 'Degraded' {'degraded'} 'New' {'new'} default {'neutral'} }
        $comp = if ($null -ne $c.Computer) { $c.Computer } else { '?' }
        $det = if ($null -ne $c.Detail) { $c.Detail } else { '' }
        $h += "<tr class=""$cls""><td>$comp</td><td><span class=""badge badge-$cls"">$t</span></td><td>$det</td></tr>"
    }
    $h += '</tbody></table>'
    return $h
}


function Get-NIRecentAlerts {
    param([int]$MaxCount = 10)
    $f = "C:\NetInsightServer\Data\Alerts\Alerts.json"
    if (-not (Test-Path $f)) { return @() }
    try {
        $alerts = Get-Content $f -Raw | ConvertFrom-Json
        # Ensure it is an array
        if ($alerts -is [array]) { return $alerts | Sort-Object Timestamp -Descending | Select-Object -First $MaxCount }
        else { return @($alerts) | Sort-Object Timestamp -Descending | Select-Object -First $MaxCount }
    } catch { return @() }
}

function ConvertTo-NIAlertsHtml {
    param($Alerts)
    # Ensure array
    if ($null -eq $Alerts) { $Alerts = @() }
    elseif ($Alerts -isnot [array]) { $Alerts = @($Alerts) }
    if ($Alerts.Count -eq 0) {
        return "<h2>Recent Alerts</h2><div style=""color:#666;font-style:italic;"">No recent alerts</div>"
    }
    $h = "<h2>Recent Alerts</h2>"
    $h += "<table style=""width:100%;border-collapse:collapse;margin:15px 0;""><thead><tr><th style=""text-align:left;padding:8px;background:#f5f5f5;"">Time</th><th style=""text-align:left;padding:8px;background:#f5f5f5;"">Severity</th><th style=""text-align:left;padding:8px;background:#f5f5f5;"">Computer</th><th style=""text-align:left;padding:8px;background:#f5f5f5;"">Message</th></tr></thead><tbody>"
    foreach ($a in $Alerts) {
        if ($null -eq $a) { continue }
        # Safe property access
        $sev = if ($a.PSObject.Properties["Severity"]) { $a.Severity } else { "Info" }
        $comp = if ($a.PSObject.Properties["Computer"]) { $a.Computer } else { "?" }
        $msg = if ($a.PSObject.Properties["Message"]) { $a.Message } else { "" }
        $ts = if ($a.PSObject.Properties["Timestamp"]) { $a.Timestamp } else { "" }
        $sc = switch ($sev) { 'Critical' {'#dc3545'} 'Warning' {'#ffc107'} default {'#28a745'} }
        $h += "<tr style=""border-bottom:1px solid #ddd;""><td style=""padding:8px;"">$ts</td><td style=""padding:8px;color:$sc;font-weight:bold;"">$sev</td><td style=""padding:8px;""><strong>$comp</strong></td><td style=""padding:8px;"">$msg</td></tr>"
    }
    $h += "</tbody></table>"
    return $h
}


function Export-NIDashboardHtml {
    [CmdletBinding()]
    param(
        [string]$Path = "C:\NetInsightServer\Data\Reports\Dashboard.html",
        [switch]$Open
    )

    begin {
        function ConvertTo-NIHtmlText {
            param([object]$Value)
            if ($null -eq $Value) { return '' }
            $text = [string]$Value
            return $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
        }
    }

    process {
        $summary = Get-NIDashboardSummary

        $cards = @(
            [ordered]@{ Label = 'Total Computers'; Value = $summary.TotalComputers }
            [ordered]@{ Label = 'Windows 10'; Value = $summary.Windows10Computers }
            [ordered]@{ Label = 'Low Memory < 8 GB'; Value = $summary.LowMemoryComputers }
            [ordered]@{ Label = 'Average RAM GB'; Value = $summary.AverageRamGB }
            [ordered]@{ Label = 'Total Disks'; Value = $summary.TotalDiskCount }
            [ordered]@{ Label = 'SecureBoot Disabled'; Value = $summary.SecureBootDisabled }
            [ordered]@{ Label = 'Firewall Disabled'; Value = $summary.FirewallAnyDisabled }
            [ordered]@{ Label = 'UAC Disabled'; Value = $summary.UACDisabled }
            [ordered]@{ Label = 'BitLocker Disabled'; Value = $summary.BitLockerDisabled }
            [ordered]@{ Label = 'Defender Disabled'; Value = $summary.DefenderDisabled }
            [ordered]@{ Label = 'RDP Enabled'; Value = $summary.RdpEnabled }
        )

        $cardsHtml = ''
        foreach ($card in $cards) {
            $cardsHtml += '<div class="card"><div class="value">{0}</div><div class="label">{1}</div></div>' -f `
                (ConvertTo-NIHtmlText -Value $card.Value), (ConvertTo-NIHtmlText -Value $card.Label)
        }

        $rowsHtml = ''
        foreach ($computer in @($summary.Computers)) {
            if ($null -eq $computer) { continue }
            $rowValues = @(
                $computer.ComputerName, $computer.OS, $computer.OSVersion, $computer.OSBuild,
                $computer.CPU, $computer.CPUCores, $computer.LogicalProcessors, $computer.TotalRAMGB,
                $computer.DiskCount, $computer.SecureBoot, $computer.FirewallDomain,
                $computer.FirewallPrivate, $computer.FirewallPublic, $computer.UAC,
                $computer.BitLocker, $computer.Defender, $computer.Rdp
            )
            $rowsHtml += '<tr>'
            for ($colIdx = 0; $colIdx -lt $rowValues.Count; $colIdx++) {
                $value = $rowValues[$colIdx]
                if ($colIdx -ge 9) {
                    $rowsHtml += '<td>' + (ConvertTo-NIStatusBadge -Value $value) + '</td>'
                } else {
                    $rowsHtml += '<td>{0}</td>' -f (ConvertTo-NIHtmlText -Value $value)
                }
            }
            $rowsHtml += '</tr>'
        }

    $historyHtml = ConvertTo-NIHistoryHtml -Changes (Get-NIHistoryChanges)
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>NetInsight Dashboard</title>
<style>
body { font-family: Segoe UI, Tahoma, Arial, sans-serif; background: #f4f6f8; margin: 20px; }
h1, h2 { color: #1f2937; }
.meta { color: #6b7280; margin-bottom: 20px; }
.cards { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 24px; }
.card { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 14px 18px; min-width: 160px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); }
.value { font-size: 24px; font-weight: 700; color: #111827; }
.label { color: #6b7280; margin-top: 4px; }
table { border-collapse: collapse; width: 100%; background: #ffffff; border: 1px solid #e5e7eb; }
th, td { border: 1px solid #e5e7eb; padding: 8px; text-align: left; font-size: 13px; }
th { background: #f9fafb; }
</style>
</head>
<body>
<h1>NetInsight Dashboard</h1>
<div class="meta">Generated: $($summary.Generated) | Collector Version: $($summary.CollectorVersion) | Files Found: $($summary.FilesFound) | Files Read: $($summary.FilesRead) | Files Failed: $($summary.FilesFailed)</div>
<div class="cards">$cardsHtml</div>
$(ConvertTo-NIAlertsHtml -Alerts (Get-NIRecentAlerts))
$historyHtml
<h2>Computers</h2>
<table>
<thead><tr><th>Computer</th><th>OS</th><th>OS Version</th><th>OS Build</th><th>CPU</th><th>Cores</th><th>Logical</th><th>RAM GB</th><th>Disks</th><th>SecureBoot</th><th>FW Domain</th><th>FW Private</th><th>FW Public</th><th>UAC</th><th>BitLocker</th><th>Defender</th><th>Rdp</th></tr></thead>
<tbody>$rowsHtml</tbody>
</table>
</body>
</html>
"@

        $parent = Split-Path -Parent $Path
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        Set-Content -Path $Path -Value $html -Encoding UTF8
        if ($Open) { Invoke-Item -Path $Path }
        return $Path
    }
}

function Get-NIComputerHealth {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Computers
    )

    begin {
        function Get-NIHealthPropertyValue {
            param([object]$InputObject, [string]$Name)
            if ($null -eq $InputObject) { return $null }
            if ($InputObject.PSObject.Properties[$Name]) { return $InputObject.PSObject.Properties[$Name].Value }
            return $null
        }
        function Get-NIHealthDoubleValue {
            param([object]$Value)
            if ($null -eq $Value) { return $null }
            try { return [double]$Value } catch { return $null }
        }
        function Test-NIHealthDisabledValue {
            param([object]$Value)
            if ($null -eq $Value) { return $false }
            if ($Value -is [bool]) { return (-not $Value) }
            $text = [string]$Value
            if ([string]::IsNullOrWhiteSpace($text)) { return $false }
            return ($text -match '^(0|false|no|disabled|off)$')
        }
        function Test-NIHealthEnabledValue {
            param([object]$Value)
            if ($null -eq $Value) { return $false }
            if ($Value -is [bool]) { return $Value }
            $text = [string]$Value
            if ([string]::IsNullOrWhiteSpace($text)) { return $false }
            return ($text -match '^(1|true|yes|enabled|on)$')
        }
    }

    process {
        if ($PSBoundParameters.ContainsKey('Computers')) {
            if ($null -eq $Computers -or @($Computers).Count -eq 0) { return @() }
            $normalized = @(Get-NIQueryResult -Computers $Computers)
        }
        else {
            $rawComputers = @()
            try { $rawComputers = @(Get-NIComputers -ErrorAction Stop) } catch { $rawComputers = @() }
            $normalized = @(Get-NIQueryResult -Computers $rawComputers)
        }

        if ($normalized.Count -eq 0) { return @() }

        $results = New-Object System.Collections.Generic.List[object]

        foreach ($item in $normalized) {
            if ($null -eq $item) { continue }

            $issues = New-Object System.Collections.Generic.List[string]
            $missing = New-Object System.Collections.Generic.List[string]
            [int]$score = 100
            [bool]$critical = $false
            [bool]$warning = $false

            $computerName = Get-NIHealthPropertyValue -InputObject $item -Name 'ComputerName'

            $os = Get-NIHealthPropertyValue -InputObject $item -Name 'OS'
            if ($null -eq $os -or [string]::IsNullOrWhiteSpace([string]$os)) { $missing.Add('OS'); $score -= 5; $warning = $true }

            $secureBoot = Get-NIHealthPropertyValue -InputObject $item -Name 'SecureBoot'
            if ($null -eq $secureBoot -or [string]::IsNullOrWhiteSpace([string]$secureBoot)) { $missing.Add('SecureBoot'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $secureBoot) { $issues.Add('SecureBootDisabled'); $score -= 30; $critical = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $secureBoot)) { $missing.Add('SecureBoot'); $score -= 5; $warning = $true }

            $firewallDomain = Get-NIHealthPropertyValue -InputObject $item -Name 'FirewallDomain'
            if ($null -eq $firewallDomain -or [string]::IsNullOrWhiteSpace([string]$firewallDomain)) { $missing.Add('FirewallDomain'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $firewallDomain) { $issues.Add('FirewallDomainDisabled'); $score -= 20; $critical = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $firewallDomain)) { $missing.Add('FirewallDomain'); $score -= 5; $warning = $true }

            $firewallPrivate = Get-NIHealthPropertyValue -InputObject $item -Name 'FirewallPrivate'
            if ($null -eq $firewallPrivate -or [string]::IsNullOrWhiteSpace([string]$firewallPrivate)) { $missing.Add('FirewallPrivate'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $firewallPrivate) { $issues.Add('FirewallPrivateDisabled'); $score -= 20; $critical = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $firewallPrivate)) { $missing.Add('FirewallPrivate'); $score -= 5; $warning = $true }

            $firewallPublic = Get-NIHealthPropertyValue -InputObject $item -Name 'FirewallPublic'
            if ($null -eq $firewallPublic -or [string]::IsNullOrWhiteSpace([string]$firewallPublic)) { $missing.Add('FirewallPublic'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $firewallPublic) { $issues.Add('FirewallPublicDisabled'); $score -= 20; $critical = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $firewallPublic)) { $missing.Add('FirewallPublic'); $score -= 5; $warning = $true }

            $uac = Get-NIHealthPropertyValue -InputObject $item -Name 'UAC'
            if ($null -eq $uac -or [string]::IsNullOrWhiteSpace([string]$uac)) { $missing.Add('UAC'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $uac) { $issues.Add('UACDisabled'); $score -= 15; $warning = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $uac)) { $missing.Add('UAC'); $score -= 5; $warning = $true }

            $bitLocker = Get-NIHealthPropertyValue -InputObject $item -Name 'BitLocker'
            if ($null -eq $bitLocker -or [string]::IsNullOrWhiteSpace([string]$bitLocker)) { $missing.Add('BitLocker'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $bitLocker) { $issues.Add('BitLockerDisabled'); $score -= 20; $critical = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $bitLocker)) { $missing.Add('BitLocker'); $score -= 5; $warning = $true }

            $defender = Get-NIHealthPropertyValue -InputObject $item -Name 'Defender'
            if ($null -eq $defender -or [string]::IsNullOrWhiteSpace([string]$defender)) { $missing.Add('Defender'); $score -= 5; $warning = $true }
            elseif (Test-NIHealthDisabledValue -Value $defender) { $issues.Add('DefenderDisabled'); $score -= 20; $critical = $true }
            elseif (-not (Test-NIHealthEnabledValue -Value $defender)) { $missing.Add('Defender'); $score -= 5; $warning = $true }
            $rdp = Get-NIHealthPropertyValue -InputObject $item -Name 'Rdp'

            $totalRamRaw = Get-NIHealthPropertyValue -InputObject $item -Name 'TotalRAMGB'
            $totalRam = Get-NIHealthDoubleValue -Value $totalRamRaw
            if ($null -eq $totalRam) { $missing.Add('TotalRAMGB'); $score -= 5; $warning = $true }
            elseif ($totalRam -lt 8) { $issues.Add('LowMemory'); $score -= 15; $warning = $true }

            if ($score -lt 0) { $score = 0 }

            if ($critical) { $status = 'Critical' }
            elseif ($warning -or $issues.Count -gt 0 -or $missing.Count -gt 0) { $status = 'Warning' }
            else { $status = 'OK' }

            $results.Add(
                [PSCustomObject][ordered]@{
                    ComputerName    = $computerName
                    Status          = $status
                    HealthScore     = $score
                    Issues          = @($issues)
                    IssueCount      = @($issues).Count
                    MissingData     = @($missing)
                    MissingCount    = @($missing).Count
                    OS              = $os
                    TotalRAMGB      = $totalRamRaw
                    SecureBoot      = $secureBoot
                    FirewallDomain  = $firewallDomain
                    FirewallPrivate = $firewallPrivate
                    FirewallPublic  = $firewallPublic
                    UAC             = $uac
                    BitLocker         = $bitLocker
                    Defender          = $defender
                Rdp               = $rdp
                }
            )
        }
        return $results.ToArray()
    }
}

function Get-NIComplianceSummary {
    [CmdletBinding()]
    param()

    process {
        $health = @(Get-NIComputerHealth)

        if ($health.Count -eq 0) {
            return [PSCustomObject][ordered]@{
                Generated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; TotalComputers = 0; OKComputers = 0; WarningComputers = 0; CriticalComputers = 0
                AverageHealthScore = 0; MinHealthScore = 0; MaxHealthScore = 0; TotalIssues = 0; SecureBootDisabled = 0
                FirewallAnyDisabled = 0; UACDisabled = 0; LowMemory = 0; MissingData = 0; AttentionCount = 0; Computers = @()
            }
        }

        $ok = @($health | Where-Object { $_.Status -eq 'OK' })
        $warning = @($health | Where-Object { $_.Status -eq 'Warning' })
        $critical = @($health | Where-Object { $_.Status -eq 'Critical' })
        $secureBootDisabled = @($health | Where-Object { $_.Issues -contains 'SecureBootDisabled' })
        $firewallAnyDisabled = @($health | Where-Object { ($_.Issues -contains 'FirewallDomainDisabled') -or ($_.Issues -contains 'FirewallPrivateDisabled') -or ($_.Issues -contains 'FirewallPublicDisabled') })
        $uacDisabled = @($health | Where-Object { $_.Issues -contains 'UACDisabled' })
        $lowMemory = @($health | Where-Object { $_.Issues -contains 'LowMemory' })
        $missingData = @($health | Where-Object { $_.MissingCount -gt 0 })
        $attention = @($health | Where-Object { $_.Status -ne 'OK' })

        $totalIssues = 0
        foreach ($item in $health) { $totalIssues += [int]$item.IssueCount }

        $scores = @($health | ForEach-Object { [double]$_.HealthScore })
        $averageScore = 0; $minScore = 0; $maxScore = 0
        if ($scores.Count -gt 0) {
            $measure = $scores | Measure-Object -Average -Minimum -Maximum
            $averageScore = [math]::Round($measure.Average, 2)
            $minScore = $measure.Minimum
            $maxScore = $measure.Maximum
        }

        return [PSCustomObject][ordered]@{
            Generated              = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            TotalComputers         = $health.Count
            OKComputers            = $ok.Count
            WarningComputers       = $warning.Count
            CriticalComputers      = $critical.Count
            AverageHealthScore     = $averageScore
            MinHealthScore         = $minScore
            MaxHealthScore         = $maxScore
            TotalIssues            = $totalIssues
            SecureBootDisabled     = $secureBootDisabled.Count
            FirewallAnyDisabled    = $firewallAnyDisabled.Count
            UACDisabled            = $uacDisabled.Count
            LowMemory              = $lowMemory.Count
            MissingData            = $missingData.Count
            AttentionCount         = $attention.Count
            Computers              = $health
        }
    }
}

function Get-NIAttentionComputers {
    [CmdletBinding()]
    param()

    process {
        $health = @(Get-NIComputerHealth)
        if ($health.Count -eq 0) { return @() }

        $attention = @($health | Where-Object { ($_.Status -ne 'OK') -or ($_.IssueCount -gt 0) })
        if ($attention.Count -eq 0) { return @() }

        return @($attention | Sort-Object -Property @{Expression = 'HealthScore'}, @{Expression = 'ComputerName'})
    }
}
function Export-NIComplianceDashboard {
    [CmdletBinding()]
    param(
        [string]$Path = "C:\NetInsightServer\Data\Reports\ComplianceDashboard.html",
        [switch]$Open
    )

    begin {

        function ConvertTo-NIHtmlText {
            param([object]$Value)
            if ($null -eq $Value) { return '' }
            $text = [string]$Value
            return $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
        }

        function Get-NIStatusColor {
            param([string]$Status)
            switch ($Status) {
                'OK'       { return '#22c55e' }
                'Warning'  { return '#f59e0b' }
                'Critical' { return '#ef4444' }
                default    { return '#6b7280' }
            }
        }

        function Get-NIScoreColor {
            param([int]$Score)
            if ($Score -ge 80) { return '#22c55e' }
            if ($Score -ge 50) { return '#f59e0b' }
            return '#ef4444'
        }

    }

    process {

        $summary = Get-NIComplianceSummary
        $health = @($summary.Computers)

        # ============================================================
        # Summary Cards
        # ============================================================

        $summaryCards = @(
            [ordered]@{ Label = 'Total Computers'; Value = $summary.TotalComputers; Color = '#3b82f6' }
            [ordered]@{ Label = 'Healthy (OK)'; Value = $summary.OKComputers; Color = '#22c55e' }
            [ordered]@{ Label = 'Warning'; Value = $summary.WarningComputers; Color = '#f59e0b' }
            [ordered]@{ Label = 'Critical'; Value = $summary.CriticalComputers; Color = '#ef4444' }
            [ordered]@{ Label = 'Avg Health Score'; Value = $summary.AverageHealthScore; Color = '#6366f1' }
            [ordered]@{ Label = 'Total Issues'; Value = $summary.TotalIssues; Color = '#8b5cf6' }
        )

        $summaryCardsHtml = ''
        foreach ($card in $summaryCards) {
            $summaryCardsHtml += @"
<div class="card" style="border-top: 4px solid $($card.Color);">
    <div class="value" style="color: $($card.Color);">$(ConvertTo-NIHtmlText $card.Value)</div>
    <div class="label">$(ConvertTo-NIHtmlText $card.Label)</div>
</div>
"@
        }

        # ============================================================
        # Security Cards
        # ============================================================

        $securityCards = @(
            [ordered]@{ Label = 'SecureBoot Disabled'; Value = $summary.SecureBootDisabled; Color = '#ef4444' }
            [ordered]@{ Label = 'Firewall Disabled'; Value = $summary.FirewallAnyDisabled; Color = '#ef4444' }
            [ordered]@{ Label = 'UAC Disabled'; Value = $summary.UACDisabled; Color = '#f59e0b' }
            [ordered]@{ Label = 'Low Memory'; Value = $summary.LowMemory; Color = '#f59e0b' }
            [ordered]@{ Label = 'Missing Data'; Value = $summary.MissingData; Color = '#6b7280' }
        )

        $securityCardsHtml = ''
        foreach ($card in $securityCards) {
            $securityCardsHtml += @"
<div class="card" style="border-top: 4px solid $($card.Color);">
    <div class="value" style="color: $($card.Color);">$(ConvertTo-NIHtmlText $card.Value)</div>
    <div class="label">$(ConvertTo-NIHtmlText $card.Label)</div>
</div>
"@
        }

        # ============================================================
        # Computers Table Rows
        # ============================================================

        $computersRowsHtml = ''

        foreach ($computer in $health) {
            if ($null -eq $computer) { continue }

            $statusColor = Get-NIStatusColor -Status $computer.Status
            $scoreColor = Get-NIScoreColor -Score $computer.HealthScore
            $statusText = ConvertTo-NIHtmlText $computer.Status

            $issuesHtml = ''
            if ($computer.IssueCount -gt 0) {
                $issuesHtml = ($computer.Issues | ForEach-Object {
                    '<span class="badge badge-issue">' + (ConvertTo-NIHtmlText $_) + '</span>'
                }) -join ' '
            }
            else {
                $issuesHtml = '<span class="badge badge-ok">No Issues</span>'
            }

            $computersRowsHtml += @"
<tr data-status="$statusText">
    <td>$(ConvertTo-NIHtmlText $computer.ComputerName)</td>
    <td><span class="badge" style="background-color: $statusColor; color: white;">$statusText</span></td>
    <td><span style="color: $scoreColor; font-weight: bold;">$(ConvertTo-NIHtmlText $computer.HealthScore)</span></td>
    <td>$issuesHtml</td>
    <td>$(ConvertTo-NIHtmlText $computer.OS)</td>
    <td>$(ConvertTo-NIHtmlText $computer.TotalRAMGB)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.SecureBoot)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.FirewallDomain)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.FirewallPrivate)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.FirewallPublic)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.UAC)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.BitLocker)</td>
    <td>$(ConvertTo-NIStatusBadge $computer.Defender)</td>
</tr>
"@
        }

        # ============================================================
        # Attention List
        # ============================================================

        $attention = @(Get-NIAttentionComputers)
        $attentionHtml = ''

        if ($attention.Count -eq 0) {
            $attentionHtml = '<p class="no-attention">All systems are healthy. No attention required.</p>'
        }
        else {
            $attentionHtml = '<table><thead><tr><th>Computer</th><th>Status</th><th>Score</th><th>Issues</th></tr></thead><tbody>'

            foreach ($item in $attention) {
                $statusColor = Get-NIStatusColor -Status $item.Status
                $scoreColor = Get-NIScoreColor -Score $item.HealthScore
                $statusText = ConvertTo-NIHtmlText $item.Status

                $issuesHtml = ($item.Issues | ForEach-Object {
                    '<span class="badge badge-issue">' + (ConvertTo-NIHtmlText $_) + '</span>'
                }) -join ' '

                $attentionHtml += @"
<tr>
    <td>$(ConvertTo-NIHtmlText $item.ComputerName)</td>
    <td><span class="badge" style="background-color: $statusColor; color: white;">$statusText</span></td>
    <td><span style="color: $scoreColor; font-weight: bold;">$(ConvertTo-NIHtmlText $item.HealthScore)</span></td>
    <td>$issuesHtml</td>
</tr>
"@
            }

            $attentionHtml += '</tbody></table>'
        }

        # ============================================================
        # Final HTML
        # ============================================================

        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>NetInsight Compliance Dashboard</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
    font-family: Segoe UI, Tahoma, Arial, sans-serif;
    background: #f4f6f8;
    margin: 20px;
    color: #1f2937;
}
h1 { color: #1f2937; margin-bottom: 5px; }
h2 { color: #1f2937; margin-top: 30px; margin-bottom: 10px; }
.meta { color: #6b7280; margin-bottom: 20px; font-size: 14px; }
.cards { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 24px; }
.card {
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 16px 20px;
    min-width: 150px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.value { font-size: 28px; font-weight: 700; color: #111827; }
.label { color: #6b7280; margin-top: 4px; font-size: 13px; }
table {
    border-collapse: collapse;
    width: 100%;
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    overflow: hidden;
}
th, td { border: 1px solid #e5e7eb; padding: 10px; text-align: left; font-size: 13px; }
th {
    background: #f9fafb;
    font-weight: 600;
    cursor: pointer;
    user-select: none;
    white-space: nowrap;
}
th:hover { background: #f0f1f3; }
.badge {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    margin: 1px;
}
.badge-ok { background-color: #dcfce7; color: #166534; }
.badge-issue { background-color: #fef2f2; color: #991b1b; }
.no-attention {
    background: #dcfce7;
    color: #166534;
    padding: 16px;
    border-radius: 8px;
    font-weight: 600;
}
.section { margin-bottom: 30px; }
.toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    margin-bottom: 15px;
    align-items: center;
}
.filter-btn {
    padding: 8px 16px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: #ffffff;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
}
.filter-btn:hover { background: #f9fafb; }
.filter-btn.active { background: #3b82f6; color: white; border-color: #3b82f6; }
.search-box {
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    width: 250px;
}
.search-box:focus { outline: none; border-color: #3b82f6; box-shadow: 0 0 0 2px rgba(59,130,246,0.2); }
.sort-arrow { font-size: 10px; margin-left: 4px; }
</style>
</head>
<body>

<h1>NetInsight Compliance Dashboard</h1>
<div class="meta">
Generated: $($summary.Generated)
| Total Computers: $($summary.TotalComputers)
| Avg Health Score: $($summary.AverageHealthScore)
</div>

<div class="section">
<h2>Summary</h2>
<div class="cards">
$summaryCardsHtml
</div>
</div>

<div class="section">
<h2>Security &amp; Hardware Issues</h2>
<div class="cards">
$securityCardsHtml
</div>
</div>

<div class="section">
<h2>Systems Requiring Attention</h2>
$attentionHtml
</div>

<div class="section">
<h2>All Computers</h2>

<div class="toolbar">
    <button class="filter-btn active" data-filter="All" onclick="filterTable('All')">All</button>
    <button class="filter-btn" data-filter="OK" onclick="filterTable('OK')">OK</button>
    <button class="filter-btn" data-filter="Warning" onclick="filterTable('Warning')">Warning</button>
    <button class="filter-btn" data-filter="Critical" onclick="filterTable('Critical')">Critical</button>
    <input type="text" id="searchInput" class="search-box" placeholder="Search computers..." onkeyup="searchTable()">
</div>

<table id="computersTable">
<thead>
<tr>
<th onclick="sortTable(0)">Computer</th>
<th onclick="sortTable(1)">Status</th>
<th onclick="sortTable(2)">Score</th>
<th onclick="sortTable(3)">Issues</th>
<th onclick="sortTable(4)">OS</th>
<th onclick="sortTable(5)">RAM GB</th>
<th onclick="sortTable(6)">SecureBoot</th>
<th onclick="sortTable(7)">FW Domain</th>
<th onclick="sortTable(8)">FW Private</th>
<th onclick="sortTable(9)">FW Public</th>
<th onclick="sortTable(10)">UAC</th>
<th onclick="sortTable(11)">BitLocker</th>
<th onclick="sortTable(12)">Defender</th>
</tr>
</thead>
<tbody>
$computersRowsHtml
</tbody>
</table>
</div>

<script>
function filterTable(status) {
    var rows = document.querySelectorAll('#computersTable tbody tr');
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (status === 'All' || row.getAttribute('data-status') === status) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    }
    var buttons = document.querySelectorAll('.filter-btn');
    for (var j = 0; j < buttons.length; j++) {
        buttons[j].classList.remove('active');
        if (buttons[j].getAttribute('data-filter') === status) {
            buttons[j].classList.add('active');
        }
    }
}

function searchTable() {
    var input = document.getElementById('searchInput');
    var filter = input.value.toLowerCase();
    var rows = document.querySelectorAll('#computersTable tbody tr');
    for (var i = 0; i < rows.length; i++) {
        var text = rows[i].textContent.toLowerCase();
        if (text.indexOf(filter) > -1) {
            rows[i].style.display = '';
        } else {
            rows[i].style.display = 'none';
        }
    }
}

function sortTable(columnIndex) {
    var table = document.getElementById('computersTable');
    var tbody = table.querySelector('tbody');
    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));

    var ascending = table.getAttribute('data-sort-asc') !== 'false';

    rows.sort(function(a, b) {
        var aVal = a.cells[columnIndex].textContent.trim();
        var bVal = b.cells[columnIndex].textContent.trim();

        var aNum = parseFloat(aVal);
        var bNum = parseFloat(bVal);

        if (!isNaN(aNum) && !isNaN(bNum)) {
            return ascending ? aNum - bNum : bNum - aNum;
        }

        return ascending ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
    });

    for (var i = 0; i < rows.length; i++) {
        tbody.appendChild(rows[i]);
    }

    table.setAttribute('data-sort-asc', !ascending);
}
</script>

</body>
</html>
"@

        $parent = Split-Path -Parent $Path

        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        Set-Content -Path $Path -Value $html -Encoding UTF8

        if ($Open) {
            Invoke-Item -Path $Path
        }

        return $Path

    }
}

function Update-NIDashboard {
    [CmdletBinding()]
    param(
        [switch]$SkipCollector,
        [switch]$Open,
        [string]$DashboardPath = "C:\NetInsightServer\Data\Reports\Dashboard.html",
        [string]$CompliancePath = "C:\NetInsightServer\Data\Reports\ComplianceDashboard.html"
    )

    process {

        $result = [ordered]@{
            Success           = $false
            CollectorRun      = $false
            DashboardBuilt    = $false
            ComplianceBuilt   = $false
            Errors            = @()
            DashboardPath     = $null
            CompliancePath    = $null
            Timestamp         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
			HistorySaved      = $false
			AlertsGenerated   = 0
            AlertsSaved       = 0
			ChartDashboardBuilt = $false
        }

        # ============================================================
        # Step 1: Run Collector (optional)
        # ============================================================

        if (-not $SkipCollector) {

            $serverRoot = Split-Path $PSScriptRoot -Parent
            $collectorPath = Join-Path $serverRoot "Collector.ps1"

            if (Test-Path $collectorPath) {
                try {
                    & $collectorPath -ErrorAction Stop
                    $result['CollectorRun'] = $true
                }
                catch {
                    $result['Errors'] += "Collector failed: $($_.Exception.Message)"
                }
            }
            else {
                $result['Errors'] += "Collector not found: $collectorPath"
            }
        }

        # ============================================================
        # Step 2: Build Main Dashboard
        # ============================================================

        try {
            Export-NIDashboardHtml -Path $DashboardPath -ErrorAction Stop
            $result['DashboardBuilt'] = $true
            $result['DashboardPath'] = $DashboardPath
        }
        catch {
            $result['Errors'] += "Dashboard build failed: $($_.Exception.Message)"
        }

        # ============================================================
        # Step 3: Build Compliance Dashboard
        # ============================================================

        try {
            Export-NIComplianceDashboard -Path $CompliancePath -ErrorAction Stop
            $result['ComplianceBuilt'] = $true
            $result['CompliancePath'] = $CompliancePath
        }
        catch {
            $result['Errors'] += "Compliance dashboard build failed: $($_.Exception.Message)"
        }
		# ============================================================
        # Step 3.5: Build Chart Dashboard
        # ============================================================

        try {
            Export-NIChartDashboard -Path (Join-Path (Split-Path $DashboardPath -Parent) "ChartDashboard.html") -ErrorAction Stop
            $result['ChartDashboardBuilt'] = $true
        }
        catch {
            $result['Errors'] += "Chart dashboard build failed: $($_.Exception.Message)"
            $result['ChartDashboardBuilt'] = $false
        }
        # ============================================================
        # Step 4: Save Health History
        # ============================================================

        try {
            $historyResult = Save-NIHealthHistory -ErrorAction Stop
            $result['HistorySaved'] = $historyResult.Success
        }
        catch {
            $result['Errors'] += "History save failed: $($_.Exception.Message)"
            $result['HistorySaved'] = $false
        }
		# ============================================================
        # Step 5: Update Alerts
        # ============================================================

        try {
            $alertResult = Update-NIAlerts -ErrorAction Stop
            $result['AlertsGenerated'] = $alertResult.AlertsGenerated
            $result['AlertsSaved'] = $alertResult.AlertsSaved
        }
        catch {
            $result['Errors'] += "Alerts update failed: $($_.Exception.Message)"
            $result['AlertsGenerated'] = 0
            $result['AlertsSaved'] = 0
        }
        # ============================================================
        # Step 6: Final Status
        # ============================================================

        if ($result['DashboardBuilt'] -and $result['ComplianceBuilt']) {
            $result['Success'] = $true
        }

        $output = [PSCustomObject]$result

        if ($Open -and $result['Success']) {
            if ($result['CompliancePath']) {
                Invoke-Item -Path $result['CompliancePath']
            }
        }

        return $output
    }
}

function Save-NIHealthHistory {
    [CmdletBinding()]
    param(
        [int]$MaxEntries = 500
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $historyFolder = Join-Path $serverRoot "Data\History"
        $historyFile = Join-Path $historyFolder "HealthHistory.json"

        # Ensure folder exists
        if (-not (Test-Path $historyFolder)) {
            New-Item -ItemType Directory -Path $historyFolder -Force | Out-Null
        }

        # Get current health data
        $health = @(Get-NIComputerHealth)

        if ($health.Count -eq 0) {
            return [PSCustomObject]@{
                Success = $false
                Message = "No health data to save"
                EntryCount = 0
            }
        }

        # Build current entry
        $computersData = @()
        foreach ($item in $health) {
            $computersData += [PSCustomObject]@{
                ComputerName   = $item.ComputerName
                Status         = $item.Status
                HealthScore    = $item.HealthScore
                IssueCount     = $item.IssueCount
                Issues         = $item.Issues
                MissingCount   = $item.MissingCount
                TotalRAMGB     = $item.TotalRAMGB
                SecureBoot     = $item.SecureBoot
                FirewallDomain = $item.FirewallDomain
                FirewallPrivate = $item.FirewallPrivate
                FirewallPublic = $item.FirewallPublic
                UAC            = $item.UAC
            }
        }

        $newEntry = [PSCustomObject]@{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Computers = $computersData
        }

        # Load existing history
        $history = $null

        if (Test-Path $historyFile) {
            try {
                $history = Get-Content $historyFile -Raw -Encoding UTF8 | ConvertFrom-Json
            }
            catch {
                $history = $null
            }
        }

        # Initialize if needed
        if ($null -eq $history) {
            $history = [PSCustomObject]@{
                Project     = "NetInsight"
                Version     = "1.0.0"
                MaxEntries  = $MaxEntries
                LastUpdated = ""
                Entries     = @()
            }
        }

        # Add new entry
        $entries = @($history.Entries)
        $entries += $newEntry

        # Trim to max entries
        if ($entries.Count -gt $MaxEntries) {
            $entries = $entries | Select-Object -Last $MaxEntries
        }

        # Update history object
        $history.LastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $history.Entries = $entries
        $history.MaxEntries = $MaxEntries

        # Save
        $history | ConvertTo-Json -Depth 20 | Set-Content -Path $historyFile -Encoding UTF8

        return [PSCustomObject]@{
            Success    = $true
            Message    = "Health history saved successfully"
            EntryCount = $entries.Count
            FilePath   = $historyFile
        }
    }
}

function Get-NIHealthHistory {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [int]$Last = 10
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $historyFile = Join-Path $serverRoot "Data\History\HealthHistory.json"

        if (-not (Test-Path $historyFile)) {
            return @()
        }

        try {
            $history = Get-Content $historyFile -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            return @()
        }

        $entries = @($history.Entries)

        if ($entries.Count -eq 0) {
            return @()
        }

        # Get last N entries
        $entries = $entries | Select-Object -Last $Last

        # Flatten results
        $results = @()

        foreach ($entry in $entries) {
            $timestamp = $entry.Timestamp

            foreach ($computer in $entry.Computers) {
                # Filter by computer name if specified
                if ($PSBoundParameters.ContainsKey('ComputerName')) {
                    if ($computer.ComputerName -ne $ComputerName) {
                        continue
                    }
                }

                $results += [PSCustomObject]@{
                    Timestamp     = $timestamp
                    ComputerName  = $computer.ComputerName
                    Status        = $computer.Status
                    HealthScore   = $computer.HealthScore
                    IssueCount    = $computer.IssueCount
                    Issues        = $computer.Issues
                    MissingCount  = $computer.MissingCount
                    TotalRAMGB    = $computer.TotalRAMGB
                    SecureBoot    = $computer.SecureBoot
                    FirewallDomain = $computer.FirewallDomain
                    FirewallPrivate = $computer.FirewallPrivate
                    FirewallPublic = $computer.FirewallPublic
                    UAC           = $computer.UAC
                }
            }
        }

        return $results
    }
}

function Get-NIHealthTrend {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [int]$CompareEntries = 2
    )

    process {

        if ($PSBoundParameters.ContainsKey('ComputerName')) {
            $history = @(Get-NIHealthHistory -ComputerName $ComputerName -Last $CompareEntries)
        }
        else {
            $history = @(Get-NIHealthHistory -Last $CompareEntries)
        }

        if ($history.Count -lt 2) {
            return [PSCustomObject]@{
                HasTrend      = $false
                Message       = "Not enough history data for trend analysis"
                Computers     = @()
            }
        }

        # Group by computer
        $computerNames = $history | Select-Object -ExpandProperty ComputerName -Unique

        $trends = @()

        foreach ($name in $computerNames) {
            $computerHistory = @($history | Where-Object { $_.ComputerName -eq $name } | Sort-Object Timestamp)

            if ($computerHistory.Count -lt 2) {
                continue
            }

            $oldest = $computerHistory[0]
            $newest = $computerHistory[$computerHistory.Count - 1]

            $scoreChange = $newest.HealthScore - $oldest.HealthScore
            $issueChange = $newest.IssueCount - $oldest.IssueCount

            $trendDirection = "Stable"
            if ($scoreChange -gt 0) { $trendDirection = "Improving" }
            elseif ($scoreChange -lt 0) { $trendDirection = "Declining" }

            $trends += [PSCustomObject]@{
                ComputerName    = $name
                FirstTimestamp  = $oldest.Timestamp
                LastTimestamp   = $newest.Timestamp
                FirstScore      = $oldest.HealthScore
                LastScore       = $newest.HealthScore
                ScoreChange     = $scoreChange
                FirstStatus     = $oldest.Status
                LastStatus      = $newest.Status
                IssueChange     = $issueChange
                TrendDirection  = $trendDirection
            }
        }

        return [PSCustomObject]@{
            HasTrend  = $true
            Computers = $trends
        }
    }
}
function New-NITestInventory {
    [CmdletBinding()]
    param(
        [int]$Count = 10,
        [switch]$IncludeCritical,
        [switch]$IncludeWarning
    )

    process {

        $results = @()

        for ($i = 1; $i -le $Count; $i++) {

            $computerName = "TEST-PC-$($i.ToString('000'))"

            # Determine status based on index
            $status = "OK"
            $secureBoot = $true
            $firewallDomain = 1
            $firewallPrivate = 1
            $firewallPublic = 1
            $uac = 1
            $ram = 8
            $bitLocker = $true
            $defender = $true
            $rdp = $true

            if ($IncludeCritical -and ($i % 5 -eq 0)) {
                $status = "Critical"
                $secureBoot = $false
                $firewallDomain = 0
                $ram = 4
            }
            elseif ($IncludeWarning -and ($i % 3 -eq 0)) {
                $status = "Warning"
                $uac = 0
                $ram = 6
            }

            $results += [PSCustomObject]@{
                ComputerName      = $computerName
                OS                = "Microsoft Windows 10 Pro"
                OSVersion         = "10.0.19045"
                OSBuild           = "19045"
                CPU               = "Intel(R) Core(TM) i5-7400 CPU @ 3.00GHz"
                CPUCores          = 2
                LogicalProcessors = 2
                TotalRAMGB        = $ram
                DiskCount         = 1
                SecureBoot        = $secureBoot
                FirewallDomain    = $firewallDomain
                FirewallPrivate   = $firewallPrivate
                FirewallPublic    = $firewallPublic
                UAC               = $uac
                BitLocker         = $bitLocker
                Defender          = $defender
                Rdp               = $rdp
                InventoryVersion  = "2.1.0"
                InventoryCreated  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            }
        }

        return $results
    }
}

function Test-NIScalability {
    [CmdletBinding()]
    param(
        [int]$ComputerCount = 10,
        [switch]$IncludeCritical,
        [switch]$IncludeWarning
    )

    process {

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $testResults = [ordered]@{
            Success           = $false
            ComputerCount     = $ComputerCount
            QueryResultTime   = 0
            HealthTime        = 0
            ComplianceTime    = 0
            HistoryTime       = 0
            OKCount           = 0
            WarningCount      = 0
            CriticalCount     = 0
            Errors            = @()
        }

        # ============================================================
        # Step 1: Generate Test Data
        # ============================================================

        try {
            $testData = @(New-NITestInventory -Count $ComputerCount -IncludeCritical:$IncludeCritical -IncludeWarning:$IncludeWarning)
        }
        catch {
            $testResults['Errors'] += "Test data generation failed: $($_.Exception.Message)"
            return [PSCustomObject]$testResults
        }

        if ($testData.Count -eq 0) {
            $testResults['Errors'] += "No test data generated"
            return [PSCustomObject]$testResults
        }

        # ============================================================
        # Step 2: Test Query Result
        # ============================================================

        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $queryResult = @(Get-NIQueryResult -Computers $testData)
            $sw.Stop()
            $testResults['QueryResultTime'] = $sw.ElapsedMilliseconds
        }
        catch {
            $testResults['Errors'] += "QueryResult failed: $($_.Exception.Message)"
        }

        # ============================================================
        # Step 3: Test Health
        # ============================================================

        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $health = @(Get-NIComputerHealth -Computers $testData)
            $sw.Stop()
            $testResults['HealthTime'] = $sw.ElapsedMilliseconds

            $testResults['OKCount'] = @($health | Where-Object { $_.Status -eq 'OK' }).Count
            $testResults['WarningCount'] = @($health | Where-Object { $_.Status -eq 'Warning' }).Count
            $testResults['CriticalCount'] = @($health | Where-Object { $_.Status -eq 'Critical' }).Count
        }
        catch {
            $testResults['Errors'] += "Health check failed: $($_.Exception.Message)"
        }

        # ============================================================
        # Step 4: Test Compliance Summary
        # ============================================================

        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $compliance = Get-NIComplianceSummary
            $sw.Stop()
            $testResults['ComplianceTime'] = $sw.ElapsedMilliseconds
        }
        catch {
            $testResults['Errors'] += "Compliance summary failed: $($_.Exception.Message)"
        }

        # ============================================================
        # Final
        # ============================================================

        $stopwatch.Stop()
        $testResults['TotalTime'] = $stopwatch.ElapsedMilliseconds

        if ($testResults['Errors'].Count -eq 0) {
            $testResults['Success'] = $true
        }

        return [PSCustomObject]$testResults
    }
}
function Get-NIAdvancedReport {
    [CmdletBinding()]
    param(
        [ValidateSet('OK', 'Warning', 'Critical')]
        [string]$Status,

        [int]$MinScore,
        [int]$MaxScore,

        [switch]$HasIssues,
        [switch]$NoIssues,
        [switch]$HasMissingData,
        [switch]$LowMemory,
        [switch]$SecureBootDisabled,
        [switch]$FirewallDisabled,
        [switch]$UACDisabled,

        [ValidateSet('ComputerName', 'Status', 'HealthScore', 'IssueCount', 'TotalRAMGB')]
        [string]$SortBy = 'HealthScore',

        [ValidateSet('Ascending', 'Descending')]
        [string]$SortDirection = 'Ascending'
    )

    process {

        $health = @(Get-NIComputerHealth)

        if ($health.Count -eq 0) {
            return @()
        }

        $filtered = $health

        # Filter by Status
        if ($PSBoundParameters.ContainsKey('Status')) {
            $filtered = @($filtered | Where-Object { $_.Status -eq $Status })
        }

        # Filter by MinScore
        if ($PSBoundParameters.ContainsKey('MinScore')) {
            $filtered = @($filtered | Where-Object { $_.HealthScore -ge $MinScore })
        }

        # Filter by MaxScore
        if ($PSBoundParameters.ContainsKey('MaxScore')) {
            $filtered = @($filtered | Where-Object { $_.HealthScore -le $MaxScore })
        }

        # Filter by HasIssues
        if ($HasIssues) {
            $filtered = @($filtered | Where-Object { $_.IssueCount -gt 0 })
        }

        # Filter by NoIssues
        if ($NoIssues) {
            $filtered = @($filtered | Where-Object { $_.IssueCount -eq 0 })
        }

        # Filter by HasMissingData
        if ($HasMissingData) {
            $filtered = @($filtered | Where-Object { $_.MissingCount -gt 0 })
        }

        # Filter by LowMemory
        if ($LowMemory) {
            $filtered = @($filtered | Where-Object { $_.Issues -contains 'LowMemory' })
        }

        # Filter by SecureBootDisabled
        if ($SecureBootDisabled) {
            $filtered = @($filtered | Where-Object { $_.Issues -contains 'SecureBootDisabled' })
        }

        # Filter by FirewallDisabled
        if ($FirewallDisabled) {
            $filtered = @($filtered | Where-Object {
                ($_.Issues -contains 'FirewallDomainDisabled') -or
                ($_.Issues -contains 'FirewallPrivateDisabled') -or
                ($_.Issues -contains 'FirewallPublicDisabled')
            })
        }

        # Filter by UACDisabled
        if ($UACDisabled) {
            $filtered = @($filtered | Where-Object { $_.Issues -contains 'UACDisabled' })
        }

        # Sort
        $descending = ($SortDirection -eq 'Descending')

        if ($descending) {
            $filtered = @($filtered | Sort-Object -Property @{Expression = $SortBy; Descending = $true})
        }
        else {
            $filtered = @($filtered | Sort-Object -Property $SortBy)
        }

        return $filtered
    }
}

function Get-NIHealthRanking {
    [CmdletBinding()]
    param(
        [ValidateSet('Best', 'Worst')]
        [string]$Order = 'Worst',

        [int]$Top = 10
    )

    process {

        $health = @(Get-NIComputerHealth)

        if ($health.Count -eq 0) {
            return @()
        }

        if ($Order -eq 'Worst') {
            $ranked = @($health | Sort-Object -Property @{Expression = 'HealthScore'}, @{Expression = 'ComputerName'})
        }
        else {
            $ranked = @($health | Sort-Object -Property @{Expression = 'HealthScore'; Descending = $true}, @{Expression = 'ComputerName'})
        }

        if ($Top -gt 0 -and $ranked.Count -gt $Top) {
            $ranked = $ranked | Select-Object -First $Top
        }

        # Add rank number
        $results = @()
        $rank = 1

        foreach ($item in $ranked) {
            $results += [PSCustomObject]@{
                Rank            = $rank
                ComputerName    = $item.ComputerName
                Status          = $item.Status
                HealthScore     = $item.HealthScore
                IssueCount      = $item.IssueCount
                Issues          = $item.Issues
                OS              = $item.OS
                TotalRAMGB      = $item.TotalRAMGB
            }
            $rank++
        }

        return $results
    }
}

function Get-NIComparisonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerNames
    )

    process {

        $results = @()

        foreach ($name in $ComputerNames) {
            $health = @(Get-NIComputerHealth -Computers @($name))

            if ($health.Count -eq 0) {
                $results += [PSCustomObject]@{
                    ComputerName = $name
                    Status       = 'NotFound'
                    HealthScore  = $null
                    IssueCount   = $null
                    Issues       = @()
                }
                continue
            }

            $results += $health[0]
        }

        return $results
    }
}

function Export-NIAdvancedReport {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('CSV', 'JSON', 'HTML')]
        [string]$Format = 'CSV',

        [string]$Title = "NetInsight Advanced Report"
    )

    process {

        # If no data provided, get all health data
        if ($null -eq $Data -or @($Data).Count -eq 0) {
            $Data = @(Get-NIComputerHealth)
        }

        $items = @($Data)

        if ($items.Count -eq 0) {
            # Create empty file
            $parent = Split-Path -Parent $Path
            if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            if ($Format -eq 'CSV') {
                Set-Content -Path $Path -Value "ComputerName,Status,HealthScore,IssueCount,Issues,OS,TotalRAMGB" -Encoding UTF8
            }
            elseif ($Format -eq 'JSON') {
                Set-Content -Path $Path -Value '[]' -Encoding UTF8
            }
            else {
                Set-Content -Path $Path -Value "<html><body><h1>$Title</h1><p>No data available.</p></body></html>" -Encoding UTF8
            }
            return $Path
        }

        # Normalize data
        $standardColumns = @(
            'ComputerName', 'Status', 'HealthScore', 'IssueCount', 'Issues',
            'MissingCount', 'OS', 'TotalRAMGB', 'SecureBoot',
            'FirewallDomain', 'FirewallPrivate', 'FirewallPublic', 'UAC'
        )

        $normalized = @($items | ForEach-Object {
            if ($null -eq $_) { return }
            $ordered = [ordered]@{}
            foreach ($column in $standardColumns) {
                if ($_.PSObject.Properties[$column]) {
                    $ordered[$column] = $_.PSObject.Properties[$column].Value
                }
                else {
                    $ordered[$column] = $null
                }
            }
            New-Object -TypeName PSObject -Property $ordered
        })

        # Ensure parent folder
        $parent = Split-Path -Parent $Path
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        # Export
        switch ($Format) {

            'CSV' {
                $normalized | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
            }

            'JSON' {
                $json = ConvertTo-Json -InputObject @($normalized) -Depth 20
                if ($json -notmatch '^\s*\[') { $json = "[$json]" }
                Set-Content -Path $Path -Value $json -Encoding UTF8
            }

            'HTML' {
                $htmlBody = $normalized | ConvertTo-Html -Title $Title -PreContent "<h1>$Title</h1>"
                Set-Content -Path $Path -Value $htmlBody -Encoding UTF8
            }
        }

        return $Path
    }
}
function Get-NIAlertConfig {
    [CmdletBinding()]
    param()

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $configFolder = Join-Path $serverRoot "Data\Alerts"
        $configFile = Join-Path $configFolder "AlertConfig.json"

        if (-not (Test-Path $configFolder)) {
            New-Item -ItemType Directory -Path $configFolder -Force | Out-Null
        }

        if (Test-Path $configFile) {
            try {
                return Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
            }
            catch {
                # Fall through to default
            }
        }

        # Default configuration
        $defaultConfig = [PSCustomObject]@{
            Enabled                    = $true
            HealthScoreThreshold       = 50
            AlertOnCritical            = $true
            AlertOnWarning             = $false
            AlertOnSecureBootDisabled  = $true
            AlertOnFirewallDisabled    = $true
            AlertOnUACDisabled         = $false
            AlertOnLowMemory           = $false
            AlertOnMissingData         = $false
            MaxAlerts                  = 1000
            Email                      = [PSCustomObject]@{
                Enabled    = $false
                SmtpServer = ""
                Port       = 25
                From       = ""
                To         = @()
                Subject    = "NetInsight Alert"
            }
        }

        # Save default config
        $defaultConfig | ConvertTo-Json -Depth 20 | Set-Content -Path $configFile -Encoding UTF8

        return $defaultConfig
    }
}

function Get-NIAlertConfig {
    [CmdletBinding()]
    param()

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $configFolder = Join-Path $serverRoot "Data\Alerts"
        $configFile = Join-Path $configFolder "AlertConfig.json"

        if (-not (Test-Path $configFolder)) {
            New-Item -ItemType Directory -Path $configFolder -Force | Out-Null
        }

        # Default configuration
        $defaultConfig = @{
            Enabled                    = $true
            HealthScoreThreshold       = 50
            AlertOnCritical            = $true
            AlertOnWarning             = $false
            AlertOnSecureBootDisabled  = $true
            AlertOnFirewallDisabled    = $true
            AlertOnUACDisabled         = $false
            AlertOnLowMemory           = $false
            AlertOnMissingData         = $false
            MaxAlerts                  = 1000
            Email                      = @{
                Enabled    = $false
                SmtpServer = ""
                Port       = 25
                From       = ""
                To         = @()
                Subject    = "NetInsight Alert"
            }
        }

        # Try to load existing config
        $loadedConfig = $null

        if (Test-Path $configFile) {
            try {
                $content = Get-Content $configFile -Raw -Encoding UTF8
                if (-not [string]::IsNullOrWhiteSpace($content)) {
                    $loadedConfig = $content | ConvertFrom-Json
                }
            }
            catch {
                $loadedConfig = $null
            }
        }

        # Merge loaded config with defaults
        if ($null -ne $loadedConfig) {
            $keys = @($defaultConfig.Keys)
            foreach ($key in $keys) {
                if ($loadedConfig.PSObject.Properties[$key]) {
                    $defaultConfig[$key] = $loadedConfig.$key
                }
            }
        }

        $result = [PSCustomObject]$defaultConfig

        # Save if file doesn't exist
        if (-not (Test-Path $configFile)) {
            $result | ConvertTo-Json -Depth 20 | Set-Content -Path $configFile -Encoding UTF8
        }

        return $result
    }
}


function Get-NIAlert {
    [CmdletBinding()]
    param(
        [ValidateSet('Critical', 'Warning', 'Info')]
        [string]$Severity,

        [string]$ComputerName,

        [switch]$Unacknowledged,

        [int]$Last = 50
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $alertsFile = Join-Path $serverRoot "Data\Alerts\Alerts.json"

        if (-not (Test-Path $alertsFile)) {
            return @()
        }

        $alertsData = $null

        try {
            $content = Get-Content $alertsFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $alertsData = $content | ConvertFrom-Json
            }
        }
        catch {
            return @()
        }

        if ($null -eq $alertsData) {
            return @()
        }

        # Safe access to Alerts property
        $alerts = @()
        if ($alertsData.PSObject.Properties['Alerts']) {
            $alerts = @($alertsData.Alerts)
        }

        if ($alerts.Count -eq 0) {
            return @()
        }

        # Filter by severity
        if ($PSBoundParameters.ContainsKey('Severity')) {
            $alerts = @($alerts | Where-Object {
                $_.PSObject.Properties['Severity'] -and $_.Severity -eq $Severity
            })
        }

        # Filter by computer name
        if ($PSBoundParameters.ContainsKey('ComputerName')) {
            $alerts = @($alerts | Where-Object {
                $_.PSObject.Properties['ComputerName'] -and $_.ComputerName -eq $ComputerName
            })
        }

        # Filter by unacknowledged
        if ($Unacknowledged) {
            $alerts = @($alerts | Where-Object {
                $_.PSObject.Properties['Acknowledged'] -and (-not $_.Acknowledged)
            })
        }

        # Get last N
        $alerts = $alerts | Select-Object -Last $Last

        return $alerts
    }
}

function Update-NIAlerts {
    [CmdletBinding()]
    param(
        [switch]$SendEmail
    )

    process {

        $config = Get-NIAlertConfig

        # Safe access to config properties with defaults
        $enabled = $true
        $healthScoreThreshold = 50
        $alertOnCritical = $true
        $alertOnWarning = $false
        $alertOnSecureBootDisabled = $true
        $alertOnFirewallDisabled = $true
        $alertOnUACDisabled = $false
        $alertOnLowMemory = $false
        $alertOnMissingData = $false
        $maxAlerts = 1000

        if ($config.PSObject.Properties['Enabled']) { $enabled = $config.Enabled }
        if ($config.PSObject.Properties['HealthScoreThreshold']) { $healthScoreThreshold = $config.HealthScoreThreshold }
        if ($config.PSObject.Properties['AlertOnCritical']) { $alertOnCritical = $config.AlertOnCritical }
        if ($config.PSObject.Properties['AlertOnWarning']) { $alertOnWarning = $config.AlertOnWarning }
        if ($config.PSObject.Properties['AlertOnSecureBootDisabled']) { $alertOnSecureBootDisabled = $config.AlertOnSecureBootDisabled }
        if ($config.PSObject.Properties['AlertOnFirewallDisabled']) { $alertOnFirewallDisabled = $config.AlertOnFirewallDisabled }
        if ($config.PSObject.Properties['AlertOnUACDisabled']) { $alertOnUACDisabled = $config.AlertOnUACDisabled }
        if ($config.PSObject.Properties['AlertOnLowMemory']) { $alertOnLowMemory = $config.AlertOnLowMemory }
        if ($config.PSObject.Properties['AlertOnMissingData']) { $alertOnMissingData = $config.AlertOnMissingData }
        if ($config.PSObject.Properties['MaxAlerts']) { $maxAlerts = $config.MaxAlerts }

        if (-not $enabled) {
            return [PSCustomObject]@{
                Success         = $false
                Message         = "Alerting is disabled"
                AlertsGenerated = 0
                AlertsSaved     = 0
                EmailsSent      = 0
            }
        }

        $health = @(Get-NIComputerHealth)
        $newAlerts = @()

        foreach ($computer in $health) {
            if ($null -eq $computer) { continue }

            # Critical status alert
            if ($alertOnCritical -and $computer.Status -eq 'Critical') {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Critical' `
                    -Type 'HealthStatus' `
                    -Message "Computer status is Critical (Score: $($computer.HealthScore))" `
                    -Details @{
                        HealthScore = $computer.HealthScore
                        Issues      = $computer.Issues
                    }
                $newAlerts += $alert
            }

            # Warning status alert
            if ($alertOnWarning -and $computer.Status -eq 'Warning') {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Warning' `
                    -Type 'HealthStatus' `
                    -Message "Computer status is Warning (Score: $($computer.HealthScore))" `
                    -Details @{
                        HealthScore = $computer.HealthScore
                        Issues      = $computer.Issues
                    }
                $newAlerts += $alert
            }

            # Health score below threshold
            if ($computer.HealthScore -lt $healthScoreThreshold) {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Critical' `
                    -Type 'HealthScore' `
                    -Message "Health score ($($computer.HealthScore)) is below threshold ($healthScoreThreshold)" `
                    -Details @{
                        HealthScore = $computer.HealthScore
                        Threshold   = $healthScoreThreshold
                    }
                $newAlerts += $alert
            }

            # SecureBoot disabled
            if ($alertOnSecureBootDisabled -and ($computer.Issues -contains 'SecureBootDisabled')) {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Critical' `
                    -Type 'SecureBoot' `
                    -Message "SecureBoot is disabled" `
                    -Details @{ SecureBoot = $computer.SecureBoot }
                $newAlerts += $alert
            }

            # Firewall disabled
            if ($alertOnFirewallDisabled) {
                $fwIssues = @($computer.Issues | Where-Object {
                    $_ -eq 'FirewallDomainDisabled' -or
                    $_ -eq 'FirewallPrivateDisabled' -or
                    $_ -eq 'FirewallPublicDisabled'
                })

                if ($fwIssues.Count -gt 0) {
                    $alert = New-NIAlert `
                        -ComputerName $computer.ComputerName `
                        -Severity 'Critical' `
                        -Type 'Firewall' `
                        -Message "Firewall disabled: $($fwIssues -join ', ')" `
                        -Details @{ FirewallIssues = $fwIssues }
                    $newAlerts += $alert
                }
            }

            # UAC disabled
            if ($alertOnUACDisabled -and ($computer.Issues -contains 'UACDisabled')) {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Warning' `
                    -Type 'UAC' `
                    -Message "UAC is disabled" `
                    -Details @{ UAC = $computer.UAC }
                $newAlerts += $alert
            }

            # Low memory
            if ($alertOnLowMemory -and ($computer.Issues -contains 'LowMemory')) {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Warning' `
                    -Type 'LowMemory' `
                    -Message "Low memory detected ($($computer.TotalRAMGB) GB)" `
                    -Details @{ TotalRAMGB = $computer.TotalRAMGB }
                $newAlerts += $alert
            }

            # Missing data
            if ($alertOnMissingData -and $computer.MissingCount -gt 0) {
                $alert = New-NIAlert `
                    -ComputerName $computer.ComputerName `
                    -Severity 'Info' `
                    -Type 'MissingData' `
                    -Message "Missing data detected: $($computer.MissingData -join ', ')" `
                    -Details @{ MissingData = $computer.MissingData }
                $newAlerts += $alert
            }
        }

        # Save alerts
        $savedCount = 0
        foreach ($alert in $newAlerts) {
            $saveResult = Save-NIAlert -Alert $alert -MaxAlerts $maxAlerts
            if ($saveResult.Success) {
                $savedCount++
            }
        }

        # Send email if configured and requested
        $emailsSent = 0

        if ($SendEmail -and $config.PSObject.Properties['Email'] -and $config.Email.Enabled -and $newAlerts.Count -gt 0) {
            try {
                $emailBody = "NetInsight Alert Summary`n`n"
                $emailBody += "Total Alerts: $($newAlerts.Count)`n`n"

                foreach ($alert in $newAlerts) {
                    $emailBody += "[$($alert.Severity)] $($alert.ComputerName): $($alert.Message)`n"
                }

                $emailParams = @{
                    From       = $config.Email.From
                    To         = $config.Email.To
                    Subject    = "$($config.Email.Subject) - $($newAlerts.Count) alert(s)"
                    Body       = $emailBody
                    SmtpServer = $config.Email.SmtpServer
                    Port       = $config.Email.Port
                }

                Send-MailMessage @emailParams
                $emailsSent = 1
            }
            catch {
                # Email failed, but alerts are saved
            }
        }

        return [PSCustomObject]@{
            Success         = $true
            AlertsGenerated = $newAlerts.Count
            AlertsSaved     = $savedCount
            EmailsSent      = $emailsSent
            Timestamp       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
    }
}
function Set-NIAlertAcknowledged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AlertId
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $alertsFile = Join-Path $serverRoot "Data\Alerts\Alerts.json"

        if (-not (Test-Path $alertsFile)) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Alerts file not found"
            }
        }

        $alertsData = $null

        try {
            $content = Get-Content $alertsFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $alertsData = $content | ConvertFrom-Json
            }
        }
        catch {
            return [PSCustomObject]@{
                Success = $false
                Message = "Failed to read alerts file"
            }
        }

        if ($null -eq $alertsData) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Alerts data is empty"
            }
        }

        $alerts = @()
        if ($alertsData.PSObject.Properties['Alerts']) {
            $alerts = @($alertsData.Alerts)
        }

        $found = $false

        foreach ($alert in $alerts) {
            if ($alert.PSObject.Properties['Id'] -and $alert.Id -eq $AlertId) {
                $alert.Acknowledged = $true
                $found = $true
                break
            }
        }

        if (-not $found) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Alert not found: $AlertId"
            }
        }

        $alertsData.Alerts = $alerts
        $alertsData.LastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        $alertsData | ConvertTo-Json -Depth 20 | Set-Content -Path $alertsFile -Encoding UTF8

        return [PSCustomObject]@{
            Success = $true
            Message = "Alert acknowledged: $AlertId"
            AlertId = $AlertId
        }
    }
}

function Clear-NIAlert {
    [CmdletBinding()]
    param(
        [switch]$AcknowledgedOnly,
        [int]$OlderThanDays = 30
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $alertsFile = Join-Path $serverRoot "Data\Alerts\Alerts.json"

        if (-not (Test-Path $alertsFile)) {
            return [PSCustomObject]@{
                Success      = $false
                Message      = "Alerts file not found"
                RemovedCount = 0
            }
        }

        $alertsData = $null

        try {
            $content = Get-Content $alertsFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $alertsData = $content | ConvertFrom-Json
            }
        }
        catch {
            return [PSCustomObject]@{
                Success      = $false
                Message      = "Failed to read alerts file"
                RemovedCount = 0
            }
        }

        if ($null -eq $alertsData) {
            return [PSCustomObject]@{
                Success      = $false
                Message      = "Alerts data is empty"
                RemovedCount = 0
            }
        }

        $alerts = @()
        if ($alertsData.PSObject.Properties['Alerts']) {
            $alerts = @($alertsData.Alerts)
        }

        $originalCount = $alerts.Count
        $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)

        if ($AcknowledgedOnly) {
            $alerts = @($alerts | Where-Object {
                $isOld = $false
                if ($_.PSObject.Properties['Timestamp']) {
                    try {
                        $alertDate = [datetime]::ParseExact($_.Timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
                        $isOld = $alertDate -lt $cutoffDate
                    }
                    catch {
                        $isOld = $false
                    }
                }
                ($_.PSObject.Properties['Acknowledged'] -and $_.Acknowledged) -and $isOld
            })
        }
        else {
            $alerts = @($alerts | Where-Object {
                $isOld = $false
                if ($_.PSObject.Properties['Timestamp']) {
                    try {
                        $alertDate = [datetime]::ParseExact($_.Timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
                        $isOld = $alertDate -lt $cutoffDate
                    }
                    catch {
                        $isOld = $false
                    }
                }
                -not $isOld
            })
        }

        $removedCount = $originalCount - $alerts.Count

        $alertsData.Alerts = $alerts
        $alertsData.LastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        $alertsData | ConvertTo-Json -Depth 20 | Set-Content -Path $alertsFile -Encoding UTF8

        return [PSCustomObject]@{
            Success      = $true
            Message      = "Removed $removedCount alert(s)"
            RemovedCount = $removedCount
            Remaining    = $alerts.Count
        }
    }
}

function Get-NIAlertSummary {
    [CmdletBinding()]
    param()

    process {

        $alerts = @(Get-NIAlert -Last 1000)

        $total = $alerts.Count
        $critical = @($alerts | Where-Object { $_.PSObject.Properties['Severity'] -and $_.Severity -eq 'Critical' }).Count
        $warning = @($alerts | Where-Object { $_.PSObject.Properties['Severity'] -and $_.Severity -eq 'Warning' }).Count
        $info = @($alerts | Where-Object { $_.PSObject.Properties['Severity'] -and $_.Severity -eq 'Info' }).Count
        $acknowledged = @($alerts | Where-Object { $_.PSObject.Properties['Acknowledged'] -and $_.Acknowledged }).Count
        $unacknowledged = $total - $acknowledged

        return [PSCustomObject]@{
            TotalAlerts     = $total
            Critical        = $critical
            Warning         = $warning
            Info            = $info
            Acknowledged    = $acknowledged
            Unacknowledged  = $unacknowledged
            Timestamp       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
    }
}
function Set-NIAlertAcknowledged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AlertId
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $alertsFile = Join-Path $serverRoot "Data\Alerts\Alerts.json"

        if (-not (Test-Path $alertsFile)) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Alerts file not found"
            }
        }

        $alertsData = $null

        try {
            $content = Get-Content $alertsFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $alertsData = $content | ConvertFrom-Json
            }
        }
        catch {
            return [PSCustomObject]@{
                Success = $false
                Message = "Failed to read alerts file"
            }
        }

        if ($null -eq $alertsData) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Alerts data is empty"
            }
        }

        $alerts = @()
        if ($alertsData.PSObject.Properties['Alerts']) {
            $alerts = @($alertsData.Alerts)
        }

        $found = $false

        foreach ($alert in $alerts) {
            if ($alert.PSObject.Properties['Id'] -and $alert.Id -eq $AlertId) {
                $alert.Acknowledged = $true
                $found = $true
                break
            }
        }

        if (-not $found) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Alert not found: $AlertId"
            }
        }

        $alertsData.Alerts = $alerts
        $alertsData.LastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        $alertsData | ConvertTo-Json -Depth 20 | Set-Content -Path $alertsFile -Encoding UTF8

        return [PSCustomObject]@{
            Success = $true
            Message = "Alert acknowledged: $AlertId"
            AlertId = $AlertId
        }
    }
}

function Clear-NIAlert {
    [CmdletBinding()]
    param(
        [switch]$AcknowledgedOnly,
        [int]$OlderThanDays = 30
    )

    process {

        $serverRoot = Split-Path $PSScriptRoot -Parent
        $alertsFile = Join-Path $serverRoot "Data\Alerts\Alerts.json"

        if (-not (Test-Path $alertsFile)) {
            return [PSCustomObject]@{
                Success      = $false
                Message      = "Alerts file not found"
                RemovedCount = 0
            }
        }

        $alertsData = $null

        try {
            $content = Get-Content $alertsFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $alertsData = $content | ConvertFrom-Json
            }
        }
        catch {
            return [PSCustomObject]@{
                Success      = $false
                Message      = "Failed to read alerts file"
                RemovedCount = 0
            }
        }

        if ($null -eq $alertsData) {
            return [PSCustomObject]@{
                Success      = $false
                Message      = "Alerts data is empty"
                RemovedCount = 0
            }
        }

        $alerts = @()
        if ($alertsData.PSObject.Properties['Alerts']) {
            $alerts = @($alertsData.Alerts)
        }

        $originalCount = $alerts.Count
        $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)

        if ($AcknowledgedOnly) {
            $alerts = @($alerts | Where-Object {
                $isOld = $false
                if ($_.PSObject.Properties['Timestamp']) {
                    try {
                        $alertDate = [datetime]::ParseExact($_.Timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
                        $isOld = $alertDate -lt $cutoffDate
                    }
                    catch {
                        $isOld = $false
                    }
                }
                ($_.PSObject.Properties['Acknowledged'] -and $_.Acknowledged) -and $isOld
            })
        }
        else {
            $alerts = @($alerts | Where-Object {
                $isOld = $false
                if ($_.PSObject.Properties['Timestamp']) {
                    try {
                        $alertDate = [datetime]::ParseExact($_.Timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
                        $isOld = $alertDate -lt $cutoffDate
                    }
                    catch {
                        $isOld = $false
                    }
                }
                -not $isOld
            })
        }

        $removedCount = $originalCount - $alerts.Count

        $alertsData.Alerts = $alerts
        $alertsData.LastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        $alertsData | ConvertTo-Json -Depth 20 | Set-Content -Path $alertsFile -Encoding UTF8

        return [PSCustomObject]@{
            Success      = $true
            Message      = "Removed $removedCount alert(s)"
            RemovedCount = $removedCount
            Remaining    = $alerts.Count
        }
    }
}

function Get-NIAlertSummary {
    [CmdletBinding()]
    param()

    process {

        $alerts = @(Get-NIAlert -Last 1000)

        $total = $alerts.Count
        $critical = @($alerts | Where-Object { $_.PSObject.Properties['Severity'] -and $_.Severity -eq 'Critical' }).Count
        $warning = @($alerts | Where-Object { $_.PSObject.Properties['Severity'] -and $_.Severity -eq 'Warning' }).Count
        $info = @($alerts | Where-Object { $_.PSObject.Properties['Severity'] -and $_.Severity -eq 'Info' }).Count
        $acknowledged = @($alerts | Where-Object { $_.PSObject.Properties['Acknowledged'] -and $_.Acknowledged }).Count
        $unacknowledged = $total - $acknowledged

        return [PSCustomObject]@{
            TotalAlerts     = $total
            Critical        = $critical
            Warning         = $warning
            Info            = $info
            Acknowledged    = $acknowledged
            Unacknowledged  = $unacknowledged
            Timestamp       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
    }
}
function Export-NIChartDashboard {
    [CmdletBinding()]
    param(
        [string]$Path = "C:\NetInsightServer\Data\Reports\ChartDashboard.html",
        [switch]$Open
    )

    begin {

        function ConvertTo-NIHtmlText {
            param([object]$Value)
            if ($null -eq $Value) { return '' }
            $text = [string]$Value
            return $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
        }

        function Get-NIStatusColor {
            param([string]$Status)
            switch ($Status) {
                'OK'       { return '#22c55e' }
                'Warning'  { return '#f59e0b' }
                'Critical' { return '#ef4444' }
                default    { return '#6b7280' }
            }
        }

        function Get-NIScoreColor {
            param([int]$Score)
            if ($Score -ge 80) { return '#22c55e' }
            if ($Score -ge 50) { return '#f59e0b' }
            return '#ef4444'
        }

    }

    process {

        $summary = Get-NIComplianceSummary
        $health = @($summary.Computers)
        $history = @(Get-NIHealthHistory -Last 10)

        # ============================================================
        # Calculate Chart Data
        # ============================================================

        $totalComputers = $summary.TotalComputers
        $okCount = $summary.OKComputers
        $warningCount = $summary.WarningComputers
        $criticalCount = $summary.CriticalComputers

        $okPercent = 0
        $warningPercent = 0
        $criticalPercent = 0

        if ($totalComputers -gt 0) {
            $okPercent = [math]::Round(($okCount / $totalComputers) * 100, 1)
            $warningPercent = [math]::Round(($warningCount / $totalComputers) * 100, 1)
            $criticalPercent = [math]::Round(($criticalCount / $totalComputers) * 100, 1)
        }

        # ============================================================
        # Summary Cards
        # ============================================================

        $summaryCards = @(
            [ordered]@{ Label = 'Total Computers'; Value = $totalComputers; Color = '#3b82f6' }
            [ordered]@{ Label = 'Healthy (OK)'; Value = $okCount; Color = '#22c55e' }
            [ordered]@{ Label = 'Warning'; Value = $warningCount; Color = '#f59e0b' }
            [ordered]@{ Label = 'Critical'; Value = $criticalCount; Color = '#ef4444' }
            [ordered]@{ Label = 'Avg Health Score'; Value = $summary.AverageHealthScore; Color = '#6366f1' }
            [ordered]@{ Label = 'Total Issues'; Value = $summary.TotalIssues; Color = '#8b5cf6' }
        )

        $summaryCardsHtml = ''
        foreach ($card in $summaryCards) {
            $summaryCardsHtml += @"
<div class="card" style="border-top: 4px solid $($card.Color);">
    <div class="value" style="color: $($card.Color);">$(ConvertTo-NIHtmlText $card.Value)</div>
    <div class="label">$(ConvertTo-NIHtmlText $card.Label)</div>
</div>
"@
        }

        # ============================================================
        # Status Donut Chart
        # ============================================================

        $statusChartHtml = @"
<div class="chart-box">
    <h3>Status Distribution</h3>
    <div class="chart-flex">
        <div class="donut-chart" style="background: conic-gradient(#22c55e 0% $okPercent%, #f59e0b $okPercent% $($okPercent + $warningPercent)%, #ef4444 $($okPercent + $warningPercent)% 100%);">
            <div class="donut-center">
                <div class="donut-value">$totalComputers</div>
                <div class="donut-label">Total</div>
            </div>
        </div>
        <div class="chart-legend">
            <div class="legend-item"><span class="legend-color" style="background:#22c55e;"></span> OK: $okCount ($okPercent%)</div>
            <div class="legend-item"><span class="legend-color" style="background:#f59e0b;"></span> Warning: $warningCount ($warningPercent%)</div>
            <div class="legend-item"><span class="legend-color" style="background:#ef4444;"></span> Critical: $criticalCount ($criticalPercent%)</div>
        </div>
    </div>
</div>
"@

        # ============================================================
        # Health Score Bar Chart
        # ============================================================

        $barChartHtml = '<div class="chart-box"><h3>Health Scores by Computer</h3><div class="bar-chart">'

        $sortedHealth = @($health | Sort-Object -Property @{Expression = 'HealthScore'; Descending = $true})

        foreach ($computer in $sortedHealth) {
            if ($null -eq $computer) { continue }

            $score = [int]$computer.HealthScore
            $barColor = Get-NIScoreColor -Score $score
            $computerName = ConvertTo-NIHtmlText $computer.ComputerName

            $barChartHtml += @"
<div class="bar-item">
    <div class="bar-label" title="$computerName">$computerName</div>
    <div class="bar-track">
        <div class="bar-fill" style="width: $score%; background: $barColor;"></div>
    </div>
    <div class="bar-value" style="color: $barColor;">$score</div>
</div>
"@
        }

        $barChartHtml += '</div></div>'

        # ============================================================
        # Trend Chart (Simple Table-based)
        # ============================================================

        $trendChartHtml = '<div class="chart-box"><h3>Health Score Trend (Last 10 Entries)</h3>'

        if ($history.Count -eq 0) {
            $trendChartHtml += '<p class="no-data">No history data available. Run Update-NIDashboard to collect data.</p>'
        }
        else {
            $trendChartHtml += '<table class="trend-table"><thead><tr><th>Timestamp</th><th>Computer</th><th>Status</th><th>Score</th><th>Issues</th></tr></thead><tbody>'

            foreach ($entry in $history) {
                $statusColor = Get-NIStatusColor -Status $entry.Status
                $scoreColor = Get-NIScoreColor -Score $entry.HealthScore

                $trendChartHtml += @"
<tr>
    <td>$(ConvertTo-NIHtmlText $entry.Timestamp)</td>
    <td>$(ConvertTo-NIHtmlText $entry.ComputerName)</td>
    <td><span class="badge" style="background-color: $statusColor; color: white;">$(ConvertTo-NIHtmlText $entry.Status)</span></td>
    <td style="color: $scoreColor; font-weight: bold;">$(ConvertTo-NIHtmlText $entry.HealthScore)</td>
    <td>$(ConvertTo-NIHtmlText $entry.IssueCount)</td>
</tr>
"@
            }

            $trendChartHtml += '</tbody></table>'
        }

        $trendChartHtml += '</div>'

        # ============================================================
        # Attention List
        # ============================================================

        $attention = @(Get-NIAttentionComputers)
        $attentionHtml = ''

        if ($attention.Count -eq 0) {
            $attentionHtml = '<p class="no-attention">All systems are healthy. No attention required.</p>'
        }
        else {
            $attentionHtml = '<table><thead><tr><th>Computer</th><th>Status</th><th>Score</th><th>Issues</th></tr></thead><tbody>'

            foreach ($item in $attention) {
                $statusColor = Get-NIStatusColor -Status $item.Status
                $scoreColor = Get-NIScoreColor -Score $item.HealthScore

                $issuesHtml = ($item.Issues | ForEach-Object {
                    '<span class="badge badge-issue">' + (ConvertTo-NIHtmlText $_) + '</span>'
                }) -join ' '

                $attentionHtml += @"
<tr>
    <td>$(ConvertTo-NIHtmlText $item.ComputerName)</td>
    <td><span class="badge" style="background-color: $statusColor; color: white;">$(ConvertTo-NIHtmlText $item.Status)</span></td>
    <td><span style="color: $scoreColor; font-weight: bold;">$(ConvertTo-NIHtmlText $item.HealthScore)</span></td>
    <td>$issuesHtml</td>
</tr>
"@
            }

            $attentionHtml += '</tbody></table>'
        }

        # ============================================================
        # Final HTML
        # ============================================================

        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>NetInsight Chart Dashboard</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
    font-family: Segoe UI, Tahoma, Arial, sans-serif;
    background: #f4f6f8;
    margin: 20px;
    color: #1f2937;
}
h1 { color: #1f2937; margin-bottom: 5px; }
h2 { color: #1f2937; margin-top: 30px; margin-bottom: 10px; }
h3 { color: #374151; margin-bottom: 15px; font-size: 16px; }
.meta { color: #6b7280; margin-bottom: 20px; font-size: 14px; }
.cards { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 24px; }
.card {
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 16px 20px;
    min-width: 150px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.value { font-size: 28px; font-weight: 700; color: #111827; }
.label { color: #6b7280; margin-top: 4px; font-size: 13px; }
.chart-box {
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.chart-flex { display: flex; align-items: center; gap: 30px; flex-wrap: wrap; }
.donut-chart {
    width: 160px;
    height: 160px;
    border-radius: 50%;
    position: relative;
    flex-shrink: 0;
}
.donut-center {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 90px;
    height: 90px;
    background: #ffffff;
    border-radius: 50%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
}
.donut-value { font-size: 24px; font-weight: 700; color: #1f2937; }
.donut-label { font-size: 12px; color: #6b7280; }
.chart-legend { display: flex; flex-direction: column; gap: 10px; }
.legend-item { display: flex; align-items: center; font-size: 14px; color: #374151; }
.legend-color {
    display: inline-block;
    width: 14px;
    height: 14px;
    border-radius: 3px;
    margin-right: 8px;
}
.bar-chart { display: flex; flex-direction: column; gap: 10px; }
.bar-item { display: flex; align-items: center; gap: 10px; }
.bar-label {
    width: 150px;
    font-size: 13px;
    color: #374151;
    text-align: right;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.bar-track {
    flex: 1;
    height: 22px;
    background: #f0f1f3;
    border-radius: 4px;
    overflow: hidden;
}
.bar-fill {
    height: 100%;
    border-radius: 4px;
    transition: width 0.3s ease;
}
.bar-value { width: 40px; font-size: 13px; font-weight: 700; }
table {
    border-collapse: collapse;
    width: 100%;
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    overflow: hidden;
}
th, td { border: 1px solid #e5e7eb; padding: 10px; text-align: left; font-size: 13px; }
th { background: #f9fafb; font-weight: 600; }
.badge {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    margin: 1px;
}
.badge-issue { background-color: #fef2f2; color: #991b1b; }
.no-attention {
    background: #dcfce7;
    color: #166534;
    padding: 16px;
    border-radius: 8px;
    font-weight: 600;
}
.no-data { color: #6b7280; font-style: italic; }
.section { margin-bottom: 30px; }
</style>
</head>
<body>

<h1>NetInsight Chart Dashboard</h1>
<div class="meta">
Generated: $($summary.Generated)
| Total Computers: $totalComputers
| Avg Health Score: $($summary.AverageHealthScore)
</div>

<div class="section">
<h2>Summary</h2>
<div class="cards">
$summaryCardsHtml
</div>
</div>

<div class="section">
<h2>Charts</h2>
$statusChartHtml
$barChartHtml
$trendChartHtml
</div>

<div class="section">
<h2>Systems Requiring Attention</h2>
$attentionHtml
</div>

</body>
</html>
"@

        $parent = Split-Path -Parent $Path

        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        Set-Content -Path $Path -Value $html -Encoding UTF8

        if ($Open) {
            Invoke-Item -Path $Path
        }

        return $Path

    }
}

# =====================================================================
# EXPORT ALL PUBLIC FUNCTIONS
# =====================================================================

# ============================================================
# Alert Functions (Added)
# ============================================================

function Save-NIAlertConfig {
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )
    
    $serverRoot = "C:\NetInsightServer"
    $configFolder = Join-Path $serverRoot "Data\Alerts"
    $configFile = Join-Path $configFolder "AlertConfig.json"
    
    if (-not (Test-Path $configFolder)) {
        New-Item -ItemType Directory -Path $configFolder -Force | Out-Null
    }
    
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding UTF8
    
    return @{
        Success = $true
        Message = "Config saved"
        Path    = $configFile
    }
}

function New-NIAlert {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        
        [Parameter(Mandatory)]
        [string]$Severity,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Type = "General",
        [hashtable]$Details = @{}
    )
    
    $alertId = [guid]::NewGuid().ToString()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    return [PSCustomObject]@{
        Id           = $alertId
        ComputerName = $ComputerName
        Severity     = $Severity
        Type         = $Type
        Message      = $Message
        Details      = $Details
        Timestamp    = $timestamp
        Acknowledged = $false
    }
}

function Save-NIAlert {
    param(
        [Parameter(Mandatory)]
        [object]$Alert,
        
        [int]$MaxAlerts = 1000
    )
    
    $serverRoot = "C:\NetInsightServer"
    $alertsFolder = Join-Path $serverRoot "Data\Alerts"
    $alertsFile = Join-Path $alertsFolder "Alerts.json"
    
    if (-not (Test-Path $alertsFolder)) {
        New-Item -ItemType Directory -Path $alertsFolder -Force | Out-Null
    }
    
    # Read existing alerts
    $existingAlerts = @()
    if (Test-Path $alertsFile) {
        try {
            $content = Get-Content $alertsFile -Raw -Encoding UTF8
            $data = $content | ConvertFrom-Json
            if ($null -ne $data -and $data.PSObject.Properties['Alerts']) {
                $existingAlerts = @($data.Alerts)
            }
        } catch {
            $existingAlerts = @()
        }
    }
    
    # Get alert type (support both Category and Type)
    $alertType = "General"
    if ($Alert.PSObject.Properties['Type']) {
        $alertType = $Alert.Type
    } elseif ($Alert.PSObject.Properties['Category']) {
        $alertType = $Alert.Category
    }
    
    # Check for duplicate (same computer, type, message within 1 hour)
    $isDuplicate = $false
    $cutoff = (Get-Date).AddHours(-1).ToString("yyyy-MM-dd HH:mm:ss")
    
    foreach ($existing in $existingAlerts) {
        $existingType = "General"
        if ($existing.PSObject.Properties['Type']) {
            $existingType = $existing.Type
        } elseif ($existing.PSObject.Properties['Category']) {
            $existingType = $existing.Category
        }
        
        if ($existing.ComputerName -eq $Alert.ComputerName -and 
            $existingType -eq $alertType -and 
            $existing.Message -eq $Alert.Message -and
            $existing.Timestamp -gt $cutoff) {
            $isDuplicate = $true
            break
        }
    }
    
    if ($isDuplicate) {
        return @{
            Success = $false
            Message = "Duplicate alert skipped"
            AlertId = $Alert.Id
        }
    }
    
    # Add new alert
    $existingAlerts += $Alert
    
    # Limit to MaxAlerts
    if ($existingAlerts.Count -gt $MaxAlerts) {
        $existingAlerts = $existingAlerts | Select-Object -Last $MaxAlerts
    }
    
    # Save
    $alertsData = [PSCustomObject]@{
        LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TotalAlerts = $existingAlerts.Count
        Alerts      = $existingAlerts
    }
    
    $alertsData | ConvertTo-Json -Depth 20 | Set-Content -Path $alertsFile -Encoding UTF8
    
    return @{
        Success = $true
        Message = "Alert saved"
        AlertId = $Alert.Id
    }
}


Export-ModuleMember -Function @(
    'Get-NIInventoryIndex',
    'Get-NIComputers',
    'Get-NIComputer',
    'Find-NIComputer',
    'Get-NIComputerSummary',
    'Get-NIStatistics',
    'Test-Module',
    'Get-NIOS',
    'Get-NICPU',
    'Get-NIRAM',
    'Get-NIDisk',
    'Get-NINetwork',
    'Get-NISecurity',
    'Get-NISoftware',
    'Find-NIOSComputer',
    'Find-NICPUComputer',
    'Find-NIRAMComputer',
    'Find-NISecureBoot',
    'Find-NIFirewall',
    'Search-NIComputer',
    'Get-NIQueryResult',
    'ConvertTo-NIStatusBadge',
    'Export-NIQueryResult',
    'Test-NIReportNumericLessThan',
    'Test-NIReportDisabled',
    'Get-NIReportAllComputers',
    'Get-NIReportDefinition',
    'Get-NIReport',
    'Export-NIReport',
    'Get-NIDashboardSummary',
    'Export-NIDashboardHtml',
    'Get-NIComputerHealth',
    'Get-NIComplianceSummary',
    'Get-NIAttentionComputers',
    'Export-NIComplianceDashboard',
    'Update-NIDashboard',
    'Save-NIHealthHistory',
    'Get-NIHealthHistory',
    'Get-NIHealthTrend' ,
	'New-NITestInventory',
    'Test-NIScalability' ,
	'Get-NIAdvancedReport',
    'Get-NIHealthRanking',
    'Get-NIComparisonReport',
    'Export-NIAdvancedReport' ,
	'Get-NIAlertConfig',
    'Save-NIAlertConfig',
    'New-NIAlert',
    'Save-NIAlert',
    'Get-NIAlert',
    'Update-NIAlerts' ,
	'Set-NIAlertAcknowledged',
    'Clear-NIAlert',
    'Get-NIAlertSummary' ,
	'Set-NIAlertAcknowledged',
    'Clear-NIAlert',
    'Get-NIAlertSummary' ,
	'Export-NIChartDashboard'
)












