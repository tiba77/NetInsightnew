# =====================================================================

# NetInsight

# Module      : Network.psm1

# Version     : 2.3.1

# Build       : 002

# Purpose     : Stable network inventory for Delta Detection

# =====================================================================

Set-StrictMode -Version Latest

if (-not (Get-Module Common)) {
Import-Module "$PSScriptRoot\Common.psm1" -Force
}

#---------------------------------------------------------

# PRIVATE

#---------------------------------------------------------

function Get-NINetworkAdapters {

try {

    $Adapters = Get-NetAdapter -ErrorAction Stop |
        Sort-Object Name

    $Result = foreach ($Adapter in $Adapters) {

        [PSCustomObject]@{

            Name          = [string]$Adapter.Name
            Description   = [string]$Adapter.InterfaceDescription
            Status        = [string]$Adapter.Status
            LinkSpeed     = [string]$Adapter.LinkSpeed
            MACAddress    = [string]$Adapter.MacAddress
            DriverVersion = [string]$Adapter.DriverVersion

        }

    }

    @($Result)

}

catch {

    @()

}

}

function Get-NIIPConfiguration {

try {

    $Configurations = Get-NetIPConfiguration -ErrorAction Stop |
        Sort-Object InterfaceAlias

    $Result = foreach ($Config in $Configurations) {

        $IPv4 = @(
            $Config.IPv4Address |
                ForEach-Object {
                    [string]$_.IPAddress
                }
        ) | Sort-Object

        $IPv6 = @(
            $Config.IPv6Address |
                ForEach-Object {
                    [string]$_.IPAddress
                }
        ) | Sort-Object

        $Gateway = @(
            $Config.IPv4DefaultGateway |
                ForEach-Object {
                    [string]$_.NextHop
                }
        ) | Sort-Object

        $DNS = @(
            $Config.DNSServer |
                ForEach-Object {
                    $_.ServerAddresses
                }
        ) |
            ForEach-Object {
                [string]$_
            } |
            Sort-Object -Unique

        [PSCustomObject]@{

            InterfaceAlias = [string]$Config.InterfaceAlias

            IPv4Address = ($IPv4 -join ", ")

            IPv6Address = ($IPv6 -join ", ")

            Gateway = ($Gateway -join ", ")

            DNS = ($DNS -join ", ")

        }

    }

    @($Result)

}

catch {

    @()

}

}

function Get-NIRouteTable {

try {

    $Routes = Get-NetRoute -ErrorAction Stop |
        Where-Object {
            $_.DestinationPrefix -and
            $_.NextHop -and
            $_.InterfaceAlias
        } |
        Sort-Object `
            DestinationPrefix,
            NextHop,
            InterfaceAlias,
            RouteMetric,
            Protocol

    $Result = foreach ($Route in $Routes) {

        [PSCustomObject]@{

            Destination = [string]$Route.DestinationPrefix
            NextHop     = [string]$Route.NextHop
            Interface   = [string]$Route.InterfaceAlias
            Metric      = [int]$Route.RouteMetric
            Protocol    = [string]$Route.Protocol

        }

    }

    @($Result)

}

catch {

    @()

}

}

function Get-NIDNSConfiguration {

try {

    $DNSConfigurations = Get-DnsClientServerAddress -ErrorAction Stop |
        Sort-Object InterfaceAlias, AddressFamily

    $Result = foreach ($DNS in $DNSConfigurations) {

        $Servers = @(
            $DNS.ServerAddresses
        ) |
            ForEach-Object {
                [string]$_
            } |
            Sort-Object -Unique

        [PSCustomObject]@{

            InterfaceAlias = [string]$DNS.InterfaceAlias

            AddressFamily = [int]$DNS.AddressFamily

            DNSServers = ($Servers -join ", ")

        }

    }

    @($Result)

}

catch {

    @()

}

}

#---------------------------------------------------------

# TCP CONNECTIONS

#

# TCP connections are intentionally NOT included in the

# persistent inventory.

#

# Reason:

# - Local ephemeral ports change constantly

# - Remote endpoints change constantly

# - TCP state changes constantly

# - Process ownership changes constantly

#

# Including this data in the inventory hash would make

# Delta Detection report a change on almost every run.

#

# The function is kept available for future diagnostic

# use, but Get-NINetwork does not include its output.

#---------------------------------------------------------

function Get-NITCPConnections {

try {

    $Connections = Get-NetTCPConnection -ErrorAction Stop |
        Sort-Object `
            LocalAddress,
            LocalPort,
            RemoteAddress,
            RemotePort,
            State,
            OwningProcess

    $Result = foreach ($Connection in $Connections) {

        [PSCustomObject]@{

            LocalAddress  = [string]$Connection.LocalAddress
            LocalPort     = [int]$Connection.LocalPort
            RemoteAddress = [string]$Connection.RemoteAddress
            RemotePort    = [int]$Connection.RemotePort
            State         = [string]$Connection.State
            ProcessId     = [int]$Connection.OwningProcess

        }

    }

    @($Result)

}

catch {

    @()

}

}

function Get-NIShares {

try {

    $Shares = Get-SmbShare -ErrorAction Stop |
        Where-Object {
            $_.Name -notmatch '^(ADMIN\$|C\$|IPC\$|PRINT\$)$'
        } |
        Sort-Object Name

    $Result = foreach ($Share in $Shares) {

        [PSCustomObject]@{

            Name        = [string]$Share.Name
            Path        = [string]$Share.Path
            Description = [string]$Share.Description

        }

    }

    @($Result)

}

catch {

    @()

}

}

#---------------------------------------------------------

# PUBLIC

#---------------------------------------------------------

function Get-NINetwork {

try {

    # IMPORTANT:
    # Do not add TimeStamp/Get-TimeStamp here.
    #
    # Inventory JSON must describe the machine/network
    # configuration, not the execution time.
    #
    # Do not add TCPConnections here because TCP state
    # is volatile and would continuously invalidate
    # Delta Detection.

    $Data = [ordered]@{

        Adapters        = Get-NINetworkAdapters

        IPConfiguration  = Get-NIIPConfiguration

        RouteTable      = Get-NIRouteTable

        DNS             = Get-NIDNSConfiguration

        Shares           = Get-NIShares

    }

    [PSCustomObject]@{

        Module  = "Network"

        Success = $true

        Version = "2.3.1"

        Data    = $Data

    }

}

catch {

    [PSCustomObject]@{

        Module  = "Network"

        Success = $false

        Version = "2.3.1"

        Error   = [string]$_.Exception.Message

    }

}

}

function Test-Module {

try {

    $Result = Get-NINetwork

    return [bool]$Result.Success

}

catch {

    return $false

}

}

#---------------------------------------------------------

# EXPORT

#---------------------------------------------------------

Export-ModuleMember -Function `    Get-NINetwork,`
Test-Module
