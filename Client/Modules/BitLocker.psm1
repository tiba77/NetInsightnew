# =====================================================================
# NetInsight
# Module      : BitLocker.psm1
# Version     : 1.0.0
# Description : BitLocker encryption status collection
# =====================================================================

Set-StrictMode -Version Latest

function Get-NIBitLockerStatus {
    
    $result = [PSCustomObject]@{
        Supported       = $false
        Enabled         = $false
        EncryptionMethod = "None"
        ProtectionStatus = "Off"
        Volumes         = @()
        Issues          = @()
    }
    
    try {
        # Check if BitLocker is available
        $bitlockerService = Get-Service -Name "BDESVC" -ErrorAction SilentlyContinue
        
        if ($null -eq $bitlockerService) {
            $result.Issues += "BitLockerServiceNotFound"
            return $result
        }
        
        $result.Supported = $true
        
        # Get BitLocker status for all volumes
        $volumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
        
        if ($null -eq $volumes) {
            $result.Issues += "NoBitLockerVolumes"
            return $result
        }
        
        $volumeList = @()
        $encryptedCount = 0
        $totalCriticalVolumes = 0
        
        foreach ($volume in $volumes) {
            $volInfo = [PSCustomObject]@{
                MountPoint       = $volume.MountPoint
                ProtectionStatus = $volume.ProtectionStatus.ToString()
                EncryptionMethod = $volume.EncryptionMethod.ToString()
                EncryptionPercentage = $volume.EncryptionPercentage
                KeyProtectors    = @($volume.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() })
            }
            
            $volumeList += $volInfo
            
            # Count critical volumes (C: drive)
            if ($volume.MountPoint -eq "C:") {
                $totalCriticalVolumes++
                if ($volume.ProtectionStatus -eq "On") {
                    $encryptedCount++
                    $result.Enabled = $true
                    $result.EncryptionMethod = $volume.EncryptionMethod.ToString()
                    $result.ProtectionStatus = "On"
                }
            }
        }
        
        $result.Volumes = $volumeList
        
        # Check if system drive is encrypted
        if ($totalCriticalVolumes -gt 0 -and $encryptedCount -eq 0) {
            $result.Issues += "SystemDriveNotEncrypted"
        }
        
        # Check for TPM protector
        $hasTPM = $false
        foreach ($volume in $volumes) {
            if ($volume.MountPoint -eq "C:") {
                foreach ($protector in $volume.KeyProtector) {
                    if ($protector.KeyProtectorType -eq "Tpm" -or 
                        $protector.KeyProtectorType -eq "TpmAndPin" -or
                        $protector.KeyProtectorType -eq "TpmAndStartupKey") {
                        $hasTPM = $true
                        break
                    }
                }
            }
        }
        
        if (-not $hasTPM -and $result.Enabled) {
            $result.Issues += "NoTPMProtector"
        }
        
    } catch {
        $result.Issues += "BitLockerQueryFailed"
    }
    
    return $result
}

Export-ModuleMember -Function Get-NIBitLockerStatus
