# =====================================================================
# NetInsight
# Module      : Hash.psm1
# Version     : 2.3.0
# =====================================================================

Set-StrictMode -Version Latest

function Get-NIFileHash {

    param(
        [Parameter(Mandatory)]
        [string]$File
    )

    if (!(Test-Path $File)) {
        return $null
    }

    (Get-FileHash `
        -Path $File `
        -Algorithm SHA256).Hash

}

function Save-NIHash {

    param(
        [Parameter(Mandatory)]
        [string]$Hash,

        [Parameter(Mandatory)]
        [string]$File
    )

    $Hash | Set-Content `
        -Path $File `
        -Encoding UTF8

}

function Get-NILastHash {

    param(
        [Parameter(Mandatory)]
        [string]$File
    )

    if (!(Test-Path $File)) {
        return $null
    }

    (Get-Content $File -Raw).Trim()

}
function Get-NIInventoryHash {

    param(
        [Parameter(Mandatory)]
        [string]$InventoryFile
    )

    if (!(Test-Path $InventoryFile)) {
        return $null
    }

    $Inventory = Get-Content `
        $InventoryFile `
        -Raw | ConvertFrom-Json

    $Inventory = Normalize-Inventory $Inventory

    $Json = $Inventory | ConvertTo-Json -Depth 20

    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)

    $SHA = [System.Security.Cryptography.SHA256]::Create()

    $Hash = $SHA.ComputeHash($Bytes)

    return ([BitConverter]::ToString($Hash)).Replace("-","")

}

Export-ModuleMember -Function *

