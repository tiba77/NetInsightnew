param([string]$ListFile = "C:\NetInsight-Project\fleet-exceptions.csv")
$rows = Import-Csv $ListFile
Write-Host ("Identifying {0} hosts (no admin needed)..." -f $rows.Count) -ForegroundColor Cyan
$out = foreach ($r in $rows) {
    $ip = $r.IP
    $name = "(unknown)"; $wg = ""; $user = ""; $mac = ""
    $nb = & nbtstat.exe -A $ip 2>&1 | Out-String
    if ($nb -match "(?m)^\s*(\S+)\s+<00>\s+UNIQUE") { $name = $Matches[1] }
    if ($nb -match "(?m)^\s*(\S+)\s+<00>\s+GROUP")  { $wg   = $Matches[1] }
    if ($nb -match "(?m)^\s*(\S+)\s+<03>\s+UNIQUE") { $user = $Matches[1] }
    if ($nb -match "([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}") { $mac = $Matches[0] }
    $dns = "(no PTR)"
    try { $dns = ([Net.Dns]::GetHostEntry($ip)).HostName } catch { }
    $sh = & net.exe view "\\$ip" 2>&1 | Out-String
    $sn = ([regex]::Matches($sh, "(?m)^(\S+)\s+Disk") | ForEach-Object { $_.Groups[1].Value }) -join ";"
    $site = if ($ip -like "192.168.1.*") { "Subnet-90" } elseif ($ip -like "192.168.2.*") { "Subnet-91" } else { "Other" }
    [pscustomobject]@{ IP=$ip; Name=$name; Workgroup=$wg; LoggedUser=$user; MAC=$mac; DNS=$dns; Shares=$sn; Site=$site; Access=$r.Access }
}
$out | Format-Table IP, Name, LoggedUser, Site, Access -AutoSize
$csv = "C:\NetInsight-Project\host-identity-$(Get-Date -Format yyyyMMdd-HHmm).csv"
$out | Export-Csv $csv -NoTypeInformation -Encoding UTF8
Write-Host "Saved: $csv" -ForegroundColor Yellow

