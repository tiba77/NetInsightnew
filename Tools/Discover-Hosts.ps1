param([string[]]$Subnets = @("192.168.1","192.168.2"), [int]$TimeoutMs = 400)
$found = New-Object System.Collections.Generic.List[string]
$total = $Subnets.Count * 254; $i = 0
foreach ($sn in $Subnets) {
    Write-Host "Sweeping $sn.0/24 ..." -ForegroundColor Cyan
    $tasks = @()
    foreach ($n in 1..254) {
        $ip = "$sn.$n"
        $ping = New-Object Net.NetworkInformation.Ping
        $tasks += [pscustomobject]@{ IP=$ip; Task=$ping.SendPingAsync($ip,$TimeoutMs) }
    }
    foreach ($t in $tasks) {
        try {
            $r = $t.Task.Result
            if ($r.Status -eq "Success") {
                $tc = New-Object Net.Sockets.TcpClient
                $smb = $tc.ConnectAsync($t.IP,445).Wait(300)
                $tc.Close()
                if ($smb) { $found.Add($t.IP); Write-Host ("  {0} (SMB)" -f $t.IP) -ForegroundColor Green }
            }
        } catch { }
    }
}
$out = "C:\NetInsight-Project\computers-discovered.txt"
$found | Set-Content $out -Encoding UTF8
Write-Host ("`nFound {0} Windows hosts with SMB" -f $found.Count) -ForegroundColor Cyan
Write-Host "Saved: $out" -ForegroundColor Yellow

