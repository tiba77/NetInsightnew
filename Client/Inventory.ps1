# =====================================================================
# NetInsight
# Inventory.ps1
# Version : 2.4.0
# =====================================================================

Set-StrictMode -Version Latest

$Root = Split-Path $MyInvocation.MyCommand.Path

Import-Module "$Root\Modules\Common.psm1" -Force
Import-Module "$Root\Modules\Hardware.psm1" -Force
Import-Module "$Root\Modules\Windows.psm1" -Force
Import-Module "$Root\Modules\Network.psm1" -Force
Import-Module "$Root\Modules\Security.psm1" -Force
Import-Module "$Root\Modules\BitLocker.psm1" -Force
Import-Module "$Root\Modules\Defender.psm1" -Force
Import-Module "$Root\Modules\Rdp.psm1" -Force

$config = Read-Config "$Root\Config.json"

Ensure-Folder $config.Local.LogFolder
Ensure-Folder $config.Local.OutputFolder
Ensure-Folder $config.Local.CacheFolder
Ensure-Folder $config.Local.QueueFolder

$LogFile = Join-Path $config.Local.LogFolder "Inventory.log"

Write-Log `
    -Module Inventory `
    -Message "Inventory Started" `
    -LogFile $LogFile

#---------------------------------------------------------
# Collect Inventory
#---------------------------------------------------------

Write-Log `
    -Module Inventory `
    -Message "Collecting Hardware..." `
    -LogFile $LogFile

$Hardware = Get-NIHardware


Write-Log `
    -Module Inventory `
    -Message "Collecting Windows..." `
    -LogFile $LogFile

$Windows = Get-NIWindows


Write-Log `
    -Module Inventory `
    -Message "Collecting Network..." `
    -LogFile $LogFile

$Network = Get-NINetwork


Write-Log `
    -Module Inventory `
    -Message "Collecting Security..." `
    -LogFile $LogFile

$Security = Get-NISecurity


Write-Log `
    -Module Inventory `
    -Message "Collecting BitLocker..." `
    -LogFile $LogFile

$BitLocker = Get-NIBitLockerStatus


Write-Log `
    -Module Inventory `
    -Message "Collecting Defender..." `
    -LogFile $LogFile

$Defender = Get-NIDefenderStatus
    $Rdp = Get-NIRdpStatus


# Add BitLocker and Defender to Security object
$Security | Add-Member -MemberType NoteProperty -Name "BitLocker" -Value $BitLocker -Force
$Security | Add-Member -MemberType NoteProperty -Name "Defender" -Value $Defender -Force
$Security | Add-Member -MemberType NoteProperty -Name "Rdp" -Value $Rdp -Force


#---------------------------------------------------------
# Build Inventory Object
#---------------------------------------------------------

$Inventory = [ordered]@{

    Project   = $config.General.Project

    Version   = $config.General.Version

    Computer  = $env:COMPUTERNAME

    Created   = Get-TimeStamp

    Hardware  = $Hardware

    Windows   = $Windows

    Network   = $Network

    Security  = $Security

}

#---------------------------------------------------------
# Save Inventory
#---------------------------------------------------------

$JsonFile = Join-Path `
    $config.Local.OutputFolder `
    "$($env:COMPUTERNAME).json"

Save-Json `
    -Object $Inventory `
    -File $JsonFile

Write-Log `
    -Module Inventory `
    -Message "Inventory saved : $JsonFile" `
    -LogFile $LogFile

#---------------------------------------------------------
# Summary
#---------------------------------------------------------

Write-Host ""
Write-Host "========================================="
Write-Host " NetInsight Inventory Completed"
Write-Host "========================================="
Write-Host " Computer : $($env:COMPUTERNAME)"
Write-Host " Output   : $JsonFile"
Write-Host " Time     : $(Get-TimeStamp)"
Write-Host "========================================="

Write-Log `
    -Module Inventory `
    -Message "Inventory Finished Successfully" `
    -LogFile $LogFile

exit 0

