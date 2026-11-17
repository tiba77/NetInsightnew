# =====================================================================
# NetInsight
# Agent.ps1
# Version : 2.4.0
# =====================================================================

param(
    [switch]$Force
)

Set-StrictMode -Version Latest

$Root = Split-Path $MyInvocation.MyCommand.Path

Import-Module "$Root\Modules\Common.psm1" -Force
Import-Module "$Root\Modules\Hash.psm1" -Force

$config = Read-Config "$Root\Config.json"

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------

$LocalLogFolder    = Join-Path $Root $config.Folders.Logs
$LocalQueueFolder  = Join-Path $Root $config.Folders.Queue
$LocalOutputFolder = Join-Path $Root "Output"

Ensure-Folder $LocalLogFolder
Ensure-Folder $LocalQueueFolder
Ensure-Folder $LocalOutputFolder

$AgentLog = Join-Path $LocalLogFolder "Agent.log"

Write-Log `
    -Module Agent `
    -Message "Agent Started" `
    -LogFile $AgentLog

# ---------------------------------------------------------
# Execute Inventory
# ---------------------------------------------------------

Write-Log `
    -Module Agent `
    -Message "Running Inventory.ps1" `
    -LogFile $AgentLog

powershell.exe `
    -ExecutionPolicy Bypass `
    -NoProfile `
    -File "$Root\Inventory.ps1"

$InventoryFile = Join-Path `
    $LocalOutputFolder `
    "$($env:COMPUTERNAME).json"

if (!(Test-Path $InventoryFile)) {

    Write-ErrorLog `
        -Module Agent `
        -Message "Inventory Output Not Found" `
        -LogFile $AgentLog

    exit 1
}

# ---------------------------------------------------------
# Server / Upload Paths
# ---------------------------------------------------------

$ServerJsonFolder = Join-Path `
    $config.Server.RootPath `
    $config.Folders.Json

$ServerAvailable = Test-ServerPath $config.Server.RootPath

# ---------------------------------------------------------
# Retry Queue
# ---------------------------------------------------------

if ($ServerAvailable) {

    try {

        Ensure-Folder $ServerJsonFolder

        $QueueFiles = Get-ChildItem `
            -Path $LocalQueueFolder `
            -Filter *.json `
            -File `
            -ErrorAction SilentlyContinue

        foreach ($File in $QueueFiles) {

            try {

                $QueueDestination = Join-Path `
                    $ServerJsonFolder `
                    $File.Name

                Copy-Item `
                    -Path $File.FullName `
                    -Destination $QueueDestination `
                    -Force `
                    -ErrorAction Stop

                if (Test-Path $QueueDestination) {

                    Remove-Item `
                        -Path $File.FullName `
                        -Force `
                        -ErrorAction Stop

                    Write-Log `
                        -Module Agent `
                        -Message "Queued file uploaded : $($File.Name)" `
                        -LogFile $AgentLog
                }
                else {
                    throw "Queued file destination was not created."
                }
            }
            catch {
                Write-ErrorLog `
                    -Module Agent `
                    -Message "Retry failed : $($File.Name) - $($_.Exception.Message)" `
                    -LogFile $AgentLog
            }
        }
    }
    catch {
        Write-ErrorLog `
            -Module Agent `
            -Message "Queue scan failed : $($_.Exception.Message)" `
            -LogFile $AgentLog
    }
}

# ---------------------------------------------------------
# Delta Detection (Enhanced)
# ---------------------------------------------------------

$HashFolder = Join-Path $Root "Hash"
Ensure-Folder $HashFolder

$HashFile = Join-Path `
    $HashFolder `
    "$($env:COMPUTERNAME).sha256"

$ServerFile = Join-Path `
    $HashFolder `
    "$($env:COMPUTERNAME).server"

$CurrentHash  = Get-NIInventoryHash $InventoryFile
$PreviousHash = Get-NILastHash $HashFile

# Read previous server address
$PreviousServer = $null
if (Test-Path $ServerFile) {
    $PreviousServer = (Get-Content $ServerFile -Raw).Trim()
}

$CurrentServer = $config.Server.RootPath

Write-Host "Previous: [$PreviousHash]"
Write-Host "Current : [$CurrentHash]"
Write-Host "Equal   : $($CurrentHash -eq $PreviousHash)"
Write-Host "Server  : [$CurrentServer]"
Write-Host "Force   : [$Force]"

# Determine if upload is needed
$UploadRequired = $true
$SkipReason = ""

# Check 1: Force parameter
if ($Force) {
    $SkipReason = "Force mode enabled"
}
# Check 2: Server changed
elseif ($null -ne $PreviousServer -and $PreviousServer -ne $CurrentServer) {
    $SkipReason = "Server changed: [$PreviousServer] -> [$CurrentServer]"
}
# Check 3: No previous hash (first run)
elseif ($null -eq $PreviousHash) {
    $SkipReason = "First run - no previous hash"
}
# Check 4: Hash changed
elseif ($CurrentHash -ne $PreviousHash) {
    $SkipReason = "Changes detected"
}
# Check 5: File missing on server
elseif ($ServerAvailable) {
    $ServerInventoryFile = Join-Path $ServerJsonFolder "$($env:COMPUTERNAME).json"
    if (!(Test-Path $ServerInventoryFile)) {
        $SkipReason = "File missing on server"
    }
    else {
        $UploadRequired = $false
        $SkipReason = "No changes detected"
    }
}

# Report decision
if ($UploadRequired) {
    Write-Host "Decision: UPLOAD REQUIRED - $SkipReason" -ForegroundColor Green
    Write-Log `
        -Module Agent `
        -Message "Upload required. Reason: $SkipReason" `
        -LogFile $AgentLog
}
else {
    Write-Host "Decision: SKIP - $SkipReason" -ForegroundColor Yellow
    Write-Log `
        -Module Agent `
        -Message "Upload skipped. Reason: $SkipReason" `
        -LogFile $AgentLog
    exit 0
}

# ---------------------------------------------------------
# Upload Current Inventory
# ---------------------------------------------------------

if ($ServerAvailable) {

    try {

        Ensure-Folder $ServerJsonFolder

        $Destination = Join-Path `
            $ServerJsonFolder `
            "$($env:COMPUTERNAME).json"

        Copy-Item `
            -Path $InventoryFile `
            -Destination $Destination `
            -Force `
            -ErrorAction Stop

        if (!(Test-Path $Destination)) {
            throw "Inventory destination was not created."
        }

        # Save hash and server address
        Save-NIHash `
            -Hash $CurrentHash `
            -File $HashFile

        $CurrentServer | Set-Content `
            -Path $ServerFile `
            -Encoding UTF8

        Write-Log `
            -Module Agent `
            -Message "Inventory uploaded successfully." `
            -LogFile $AgentLog

    }
    catch {

        Write-ErrorLog `
            -Module Agent `
            -Message "Inventory upload failed. Moving file to Queue. $($_.Exception.Message)" `
            -LogFile $AgentLog

        try {

            $QueueFile = Join-Path `
                $LocalQueueFolder `
                "$($env:COMPUTERNAME).json"

            Copy-Item `
                -Path $InventoryFile `
                -Destination $QueueFile `
                -Force `
                -ErrorAction Stop

            Save-NIHash `
                -Hash $CurrentHash `
                -File $HashFile

            $CurrentServer | Set-Content `
                -Path $ServerFile `
                -Encoding UTF8

            Write-Log `
                -Module Agent `
                -Message "Inventory moved to Queue successfully." `
                -LogFile $AgentLog

        }
        catch {
            Write-ErrorLog `
                -Module Agent `
                -Message "Queue write failed. Inventory was NOT marked as processed. $($_.Exception.Message)" `
                -LogFile $AgentLog
            exit 1
        }
    }
}
else {

    Write-ErrorLog `
        -Module Agent `
        -Message "Server unavailable. Moving file to Queue." `
        -LogFile $AgentLog

    try {

        $QueueFile = Join-Path `
            $LocalQueueFolder `
            "$($env:COMPUTERNAME).json"

        Copy-Item `
            -Path $InventoryFile `
            -Destination $QueueFile `
            -Force `
            -ErrorAction Stop

        Save-NIHash `
            -Hash $CurrentHash `
            -File $HashFile

        $CurrentServer | Set-Content `
            -Path $ServerFile `
            -Encoding UTF8

        Write-Log `
            -Module Agent `
            -Message "Inventory moved to Queue successfully." `
            -LogFile $AgentLog

    }
    catch {
        Write-ErrorLog `
            -Module Agent `
            -Message "Queue write failed. Inventory was NOT marked as processed. $($_.Exception.Message)" `
            -LogFile $AgentLog
        exit 1
    }
}