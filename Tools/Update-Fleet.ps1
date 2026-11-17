param([string]$ServerIP = "192.168.1.10", [switch]$SkipDiscovery)
$root = "C:\NetInsight-Project"
$jsonDir = "C:\NetInsightServer\Data\JSON"
if (-not $SkipDiscovery) { & "$root\Discover-Hosts.ps1" }
& "$root\Test-ClientAccess.ps1" -ComputerListFile "$root\computers-discovered.txt"
$scan = Import-Csv (Get-ChildItem "$root\access-scan-*.csv" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
$known = New-Object System.Collections.Generic.HashSet[string]
foreach ($jf in Get-ChildItem $jsonDir -Filter *.json) {
    $raw = Get-Content $jf.FullName -Raw
    foreach ($m in [regex]::Matches($raw, "\b(?:\d{1,3}\.){3}\d{1,3}\b")) { [void]$known.Add($m.Value) }
}
Write-Host ("Known IPs from server JSON: {0}" -f $known.Count) -ForegroundColor Cyan
$rows = foreach ($s in $scan) {
    $state = if ($known.Contains($s.IP)) { "REPORTING" } else { "NEW" }
    [pscustomobject]@{ IP = $s.IP; Access = $s.Category; State = $state }
}
Write-Host "=== Fleet matrix ===" -ForegroundColor Cyan
$rows | Group-Object -Property Access, State | Select-Object Name, Count | Format-Table -AutoSize
$newReady = @($rows | Where-Object { $_.Access -eq "READY" -and $_.State -eq "NEW" -and $_.IP -ne $ServerIP })
$rows | Where-Object { $_.Access -ne "READY" } | Export-Csv "$root\fleet-exceptions.csv" -NoTypeInformation -Encoding UTF8
$newReady | ForEach-Object { $_.IP } | Set-Content "$root\computers-new.txt" -Encoding UTF8
Write-Host ("NEW + READY to install: {0}" -f $newReady.Count) -ForegroundColor Green
if ($newReady.Count -gt 0) {
    & "$root\Deploy-PsExec.ps1" -ComputerListFile "$root\computers-new.txt"
    & "$root\Fix-All.ps1"      -ComputerListFile "$root\computers-new.txt"
    & "$root\Force-Upload.ps1" -ComputerListFile "$root\computers-new.txt"
}
Import-Module "C:\NetInsightServer\Modules\Query.psm1" -Force
$d = Update-NIDashboard
Write-Host ("Dashboard rebuilt: {0}" -f $d.Success) -ForegroundColor Green
$cnt = (Get-ChildItem $jsonDir -Filter *.json).Count
Write-Host ("Total reporting files: {0}" -f $cnt) -ForegroundColor Cyan

