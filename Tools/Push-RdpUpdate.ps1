param(
    [string]$ComputerListFile = "C:\NetInsight-Project\computers-bulk.txt",
    [string]$CredFile = "C:\NetInsight-Project\deploy.cred",
    [string]$PsExec = "C:\NetInsight-Project\tools\PsExec.exe",
    [string]$Dist = "C:\NetInsightServer\ClientDistribution"
)
$ErrorActionPreference = "Continue"
$cred = Import-Clixml $CredFile
$au = $cred.UserName
$ap = $cred.GetNetworkCredential().Password
$computers = Get-Content $ComputerListFile | Where-Object { $_ -and $_ -notmatch "^\s*#" } | ForEach-Object { $_.Trim() }
Write-Host ("Updating RDP inventory on {0} computers..." -f $computers.Count) -ForegroundColor Cyan

$ok = 0; $needFix = 0; $notInstalled = 0; $offline = 0; $fail = 0; $report = @()

foreach ($c in $computers) {
    Write-Host "[$c]" -ForegroundColor Cyan -NoNewline

    if (-not (Test-Connection $c -Count 1 -Quiet)) {
        Write-Host " OFFLINE" -ForegroundColor Yellow
        $offline++
        $report += [pscustomobject]@{ IP = $c; Result = "offline" }
        continue
    }

    try {
        & net.exe use "\\$c\C$" /user:"$c\$au" $ap 2>&1 | Out-Null
        $base = "\\$c\C$\NetInsight"

        if (-not (Test-Path $base)) {
            Write-Host " NOT_INSTALLED" -ForegroundColor Yellow
            $notInstalled++
            $report += [pscustomobject]@{ IP = $c; Result = "not_installed" }
            & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null
            continue
        }

        if (-not (Test-Path "$base\AgentWrapper.ps1")) {
            Write-Host " NEED_FIX" -ForegroundColor Yellow
            $needFix++
            $report += [pscustomobject]@{ IP = $c; Result = "need_fix" }
            & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null
            continue
        }

        Copy-Item "$Dist\Inventory.ps1" "$base\Inventory.ps1" -Force -ErrorAction Stop
        if (-not (Test-Path "$base\Modules")) { New-Item -ItemType Directory -Path "$base\Modules" -Force | Out-Null }
        Copy-Item "$Dist\Modules\Rdp.psm1" "$base\Modules\Rdp.psm1" -Force -ErrorAction Stop
        Remove-Item "$base\Hash\*" -Force -ErrorAction SilentlyContinue
        & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null
    } catch {
        Write-Host " COPY_FAIL" -ForegroundColor Red
        $fail++
        $report += [pscustomobject]@{ IP = $c; Result = "copy_fail" }
        & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null
        continue
    }

    $out = & $PsExec "\\$c" -u "$c\$au" -p $ap -accepteula -nobanner -h -s powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\NetInsight\AgentWrapper.ps1 2>&1
    $txt = ($out | Out-String)

    if ($txt -match "UPLOAD REQUIRED") {
        Write-Host " UPDATED_UPLOADED" -ForegroundColor Green
        $ok++
        $report += [pscustomobject]@{ IP = $c; Result = "ok_upload" }
    } elseif ($txt -match "SKIP") {
        Write-Host " UPDATED_SKIP" -ForegroundColor Yellow
        $ok++
        $report += [pscustomobject]@{ IP = $c; Result = "ok_skip" }
    } else {
        Write-Host " RUN_FAIL" -ForegroundColor Red
        $fail++
        $report += [pscustomobject]@{ IP = $c; Result = "run_fail" }
    }

    Start-Sleep -Seconds 1
}

Write-Host ("`nDone: OK={0} OFFLINE={1} NEED_FIX={2} NOT_INSTALLED={3} FAIL={4}" -f $ok, $offline, $needFix, $notInstalled, $fail) -ForegroundColor Cyan
$rep = "C:\NetInsight-Project\rdp-update-report-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$report | Export-Csv $rep -NoTypeInformation -Encoding UTF8
Write-Host "Report: $rep" -ForegroundColor Yellow
