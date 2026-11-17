# =====================================================================
# NetInsight
# Module      : Defender.psm1
# Version     : 1.1.0
# Description : Windows Defender status collection (StrictMode-safe)
# =====================================================================

Set-StrictMode -Version Latest

function Get-NIDefenderStatus {
    
    $result = [PSCustomObject]@{
        Installed           = $false
        Enabled             = $false
        RealTimeProtection  = $false
        AntivirusEnabled    = $false
        AntispywareEnabled  = $false
        BehaviorMonitor     = $false
        OnAccessProtection  = $false
        SignatureUpToDate   = $false
        SignatureAge        = -1
        LastFullScan        = $null
        LastQuickScan       = $null
        ThreatCount         = 0
        Issues              = @()
    }
    
    # Helper function for safe property access
    function Get-SafeProperty {
        param($Object, [string]$PropertyName, $Default = $null)
        if ($null -eq $Object) { return $Default }
        if ($Object.PSObject.Properties[$PropertyName]) {
            return $Object.$PropertyName
        }
        return $Default
    }
    
    try {
        $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
    } catch {
        $result.Issues += "DefenderNotInstalled"
        return $result
    }
    
    if ($null -eq $defenderStatus) {
        $result.Issues += "DefenderNotInstalled"
        return $result
    }
    
    $result.Installed = $true
    
    # AM Engine enabled
    $result.AntivirusEnabled   = (Get-SafeProperty $defenderStatus "AMEngineEnabled" $false) -eq $true
    $result.AntispywareEnabled = (Get-SafeProperty $defenderStatus "AntispywareEnabled" $false) -eq $true
    $result.RealTimeProtection = (Get-SafeProperty $defenderStatus "RealTimeProtectionEnabled" $false) -eq $true
    $result.BehaviorMonitor    = (Get-SafeProperty $defenderStatus "BehaviorMonitorEnabled" $false) -eq $true
    $result.OnAccessProtection = (Get-SafeProperty $defenderStatus "OnAccessProtectionEnabled" $false) -eq $true
    
    $result.Enabled = $result.AntivirusEnabled -and $result.RealTimeProtection
    
    # Signature status
    $sigAge = Get-SafeProperty $defenderStatus "AntivirusSignatureAge" -1
    if ($null -ne $sigAge -and $sigAge -ge 0) {
        $result.SignatureAge = $sigAge
        $result.SignatureUpToDate = ($sigAge -le 3)
        if (-not $result.SignatureUpToDate) {
            $result.Issues += "SignatureOutdated"
        }
    } else {
        $result.Issues += "SignatureUnknown"
    }
    
    # Last full scan
    $fullScanTime = Get-SafeProperty $defenderStatus "FullScanEndTime" $null
    if ($null -ne $fullScanTime -and $fullScanTime -is [datetime]) {
        $result.LastFullScan = $fullScanTime.ToString("yyyy-MM-dd HH:mm:ss")
        $daysSinceFullScan = ((Get-Date) - $fullScanTime).Days
        if ($daysSinceFullScan -gt 7) {
            $result.Issues += "FullScanOverdue"
        }
    } else {
        $result.Issues += "NoFullScan"
    }
    
    # Last quick scan
    $quickScanTime = Get-SafeProperty $defenderStatus "QuickScanEndTime" $null
    if ($null -ne $quickScanTime -and $quickScanTime -is [datetime]) {
        $result.LastQuickScan = $quickScanTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Threat detection (separate try block)
    try {
        $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue
        if ($null -ne $threats) {
            $activeThreats = @($threats | Where-Object { 
                $_.PSObject.Properties['IsActive'] -and $_.IsActive -eq $true 
            })
            $result.ThreatCount = $activeThreats.Count
            if ($result.ThreatCount -gt 0) {
                $result.Issues += "ActiveThreats"
            }
        }
    } catch {
        # Threat detection query failed - not critical, skip silently
    }
    
    # Check for disabled real-time protection
    if (-not $result.RealTimeProtection) {
        $result.Issues += "RealTimeProtectionDisabled"
    }
    
    return $result
}

Export-ModuleMember -Function Get-NIDefenderStatus
