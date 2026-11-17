param(
    [string]$ServerIP = "192.168.1.10",
    [string]$ComputerListFile = "C:\NetInsight-Project\computers.txt",
    [string]$CredFile = "C:\NetInsight-Project\deploy.cred",
    [string]$PsExec = "C:\NetInsight-Project\tools\PsExec.exe",
    [int]$ThrottleDelaySec = 2,
    [switch]$DryRun
)
$ErrorActionPreference = "Continue"
if (-not (Test-Path $PsExec)) { Write-Host "PsExec not found" -ForegroundColor Red; return }
$cred = Import-Clixml $CredFile
$user = $cred.UserName
$pass = $cred.GetNetworkCredential().Password
$svcPass = Read-Host "niagent password (same as on server)"
$computers = Get-Content $ComputerListFile | Where-Object { $_ -and $_ -notmatch "^\s*#" } | ForEach-Object { $_.Trim() }
Write-Host ("Targets: {0}  Admin: {1}" -f $computers.Count, $user) -ForegroundColor Cyan
if ($DryRun) { $computers | ForEach-Object { Write-Host "  would deploy: $_" }; return }
$ok=0; $nowrite=0; $bad=0; $t0=Get-Date; $report=@()
foreach ($c in $computers) {
    Write-Host "[$c]" -ForegroundColor Cyan -NoNewline
    if (-not (Test-Connection $c -Count 1 -Quiet)) { Write-Host " OFFLINE" -ForegroundColor Yellow; $bad++; $report += [pscustomobject]@{IP=$c;Result="offline"}; continue }
    try {
        $adm = "\\$c\C$\NetInsight"
        & net.exe use "\\$c\C$" /user:"$c\$user" $pass 2>&1 | Out-Null
        if (-not (Test-Path $adm)) { New-Item -ItemType Directory $adm -Force | Out-Null }
        Copy-Item "\\$ServerIP\NetInsightClient\*" $adm -Recurse -Force -ErrorAction Stop
        $svcPass | Set-Content "$adm\_p.tmp" -Encoding ASCII -Force
    } catch {
        Write-Host " COPY_FAIL" -ForegroundColor Red; $bad++; $report += [pscustomobject]@{IP=$c;Result="copy_fail"}
        & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null; continue
    }
    $out = & $PsExec "\\$c" -u "$c\$user" -p $pass -accepteula -nobanner -h -s powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\NetInsight\Setup-Task.ps1" -ServerIP $ServerIP 2>&1
    $txt = ($out | Out-String)
    & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null
    if ($txt -match "OK_NOWRITE") { Write-Host " INSTALLED (no share write)" -ForegroundColor Yellow; $nowrite++; $report += [pscustomobject]@{IP=$c;Result="no_write"} }
    elseif ($txt -match "\bOK\b") { Write-Host " OK" -ForegroundColor Green; $ok++; $report += [pscustomobject]@{IP=$c;Result="ok"} }
    else { Write-Host " FAIL" -ForegroundColor Red; $bad++; $report += [pscustomobject]@{IP=$c;Result="fail";Detail=$txt.Substring(0,[Math]::Min(200,$txt.Length))} }
    Start-Sleep -Seconds $ThrottleDelaySec
}
$d = (Get-Date) - $t0
Write-Host ("`nDone {0:hh\:mm\:ss}  OK={1} NO_WRITE={2} FAIL={3}" -f $d,$ok,$nowrite,$bad) -ForegroundColor Cyan
$rep = "C:\NetInsight-Project\deploy-report-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$report | Export-Csv $rep -NoTypeInformation -Encoding UTF8
Write-Host "Report: $rep" -ForegroundColor Yellow

