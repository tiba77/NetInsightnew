param(
    [string]$ComputerListFile = "C:\NetInsight-Project\computers.txt",
    [string]$CredFile = "C:\NetInsight-Project\deploy.cred",
    [int]$TimeoutMs = 800
)
$cred = Import-Clixml $CredFile
$user = $cred.UserName
$pass = $cred.GetNetworkCredential().Password
$computers = Get-Content $ComputerListFile | Where-Object { $_ -and $_ -notmatch "^\s*#" } | ForEach-Object { $_.Trim() }
Write-Host ("Scanning {0} hosts (no changes made)..." -f $computers.Count) -ForegroundColor Cyan
$res = @(); $i = 0
foreach ($c in $computers) {
    $i++
    Write-Progress -Activity "Scanning" -Status $c -PercentComplete (100*$i/$computers.Count)
    $row = [pscustomobject]@{ IP=$c; Ping=$false; SMB=$false; WinRM=$false; AdminAuth="n/a"; Shares=""; Category="" }
    $row.Ping = Test-Connection $c -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($row.Ping) {
        foreach ($p in @(445,5985)) {
            $tc = New-Object Net.Sockets.TcpClient
            $ok = $tc.ConnectAsync($c,$p).Wait($TimeoutMs)
            if ($p -eq 445) { $row.SMB = $ok } else { $row.WinRM = $ok }
            $tc.Close()
        }
        if ($row.SMB) {
            & net.exe use "\\$c\IPC$" /user:"$c\$user" $pass 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $row.AdminAuth = "OK"
                $sh = & net.exe view "\\$c" 2>&1 | Out-String
                $names = ([regex]::Matches($sh, "(?m)^(\S+)\s+Disk") | ForEach-Object { $_.Groups[1].Value }) -join ";"
                $row.Shares = $names
                & net.exe use "\\$c\IPC$" /delete /y 2>&1 | Out-Null
            } else { $row.AdminAuth = "DENIED($LASTEXITCODE)" }
        }
    }
    $row.Category = 
        if (-not $row.Ping) { "OFFLINE" }
        elseif ($row.AdminAuth -eq "OK") { "READY" }
        elseif ($row.SMB) { "WRONG_CREDS" }
        else { "SMB_BLOCKED" }
    $res += $row
}
Write-Progress -Activity "Scanning" -Completed
$out = "C:\NetInsight-Project\access-scan-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$res | Export-Csv $out -NoTypeInformation -Encoding UTF8
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$res | Group-Object Category | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Report: $out" -ForegroundColor Yellow
$res | Where-Object { $_.Category -eq "READY" } | Select-Object -ExpandProperty IP |
    Set-Content "C:\NetInsight-Project\computers-ready.txt" -Encoding UTF8
Write-Host "Ready list: computers-ready.txt" -ForegroundColor Green
