param([string]$ComputerListFile = "C:\NetInsight-Project\computers-bulk.txt", [string]$ServerIP = "192.168.1.10")
$ErrorActionPreference = "Continue"
$cred = Import-Clixml "C:\NetInsight-Project\deploy.cred"
$au = $cred.UserName; $ap = $cred.GetNetworkCredential().Password
$svcPass = Read-Host "niagent password"
$ps = "C:\NetInsight-Project\tools\PsExec.exe"
$wrapSrc = "C:\NetInsightServer\ClientDistribution\AgentWrapper.ps1"
$computers = Get-Content $ComputerListFile | Where-Object { $_ -and $_ -notmatch "^\s*#" } | ForEach-Object { $_.Trim() }
Write-Host ("Fixing {0} machines..." -f $computers.Count) -ForegroundColor Cyan
$ok=0; $bad=0; $t0=Get-Date
foreach ($c in $computers) {
    Write-Host "[$c]" -ForegroundColor Cyan -NoNewline
    if (-not (Test-Connection $c -Count 1 -Quiet)) { Write-Host " OFFLINE" -ForegroundColor Yellow; $bad++; continue }
    try {
        & net.exe use "\\$c\C$" /user:"$c\$au" $ap 2>&1 | Out-Null
        Copy-Item $wrapSrc "\\$c\C$\NetInsight\AgentWrapper.ps1" -Force -ErrorAction Stop
        $fixLines = @(
            "`$dir = `"C:\NetInsight`"",
            "`$passFile = `"`$dir\svc.pass`"",
            "`$svcUser = `"$ServerIP\niagent`"",
            "`$svcPass = `"$svcPass`"",
            "`$svcPass | Set-Content `$passFile -Encoding ASCII -Force",
            "`$acl = Get-Acl `$passFile; `$acl.SetAccessRuleProtection(`$true, `$false)",
            "`$r1 = New-Object System.Security.AccessControl.FileSystemAccessRule(`"SYSTEM`",`"FullControl`",`"Allow`")",
            "`$acl.AddAccessRule(`$r1); Set-Acl `$passFile `$acl",
            "`$svcUser | Set-Content (`"`$dir\svc.user`") -Encoding ASCII -Force",
            "`$acl2 = Get-Acl (`"`$dir\svc.user`"); `$acl2.SetAccessRuleProtection(`$true, `$false)",
            "`$acl2.AddAccessRule(`$r1); Set-Acl (`"`$dir\svc.user`") `$acl2",
            "`$act = New-ScheduledTaskAction -Execute `"PowerShell.exe`" -Argument `"-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \`"`$dir\AgentWrapper.ps1\`"`"",
            "`$trg = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes((Get-Random -Minimum 5 -Maximum 120)) -RepetitionInterval (New-TimeSpan -Hours 6)",
            "Register-ScheduledTask -TaskName `"NetInsight Agent`" -Action `$act -Trigger `$trg -User `"SYSTEM`" -RunLevel Highest -Force | Out-Null",
            "Start-ScheduledTask -TaskName `"NetInsight Agent`"",
            "Write-Output FIXED"
        )
        $fixLines | Set-Content "\\$c\C$\NetInsight\Fix-Local.ps1" -Encoding UTF8
        & net.exe use "\\$c\C$" /delete /y 2>&1 | Out-Null
    } catch { Write-Host " COPY_FAIL" -ForegroundColor Red; $bad++; continue }
    $out = & $ps "\\$c" -u "$c\$au" -p $ap -accepteula -nobanner -h -s powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\NetInsight\Fix-Local.ps1 2>&1
    $txt = ($out | Out-String)
    if ($txt -match "FIXED") { Write-Host " OK" -ForegroundColor Green; $ok++ } else { Write-Host " FAIL" -ForegroundColor Red; $bad++ }
    Start-Sleep -Seconds 2
}
$d = (Get-Date) - $t0
Write-Host ("`nDone {0:hh\:mm\:ss}  OK={1} FAIL={2}" -f $d,$ok,$bad) -ForegroundColor Cyan

