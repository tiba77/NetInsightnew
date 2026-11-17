param([string]$ServerIP = "192.168.1.10", [string]$PassFile = "C:\NetInsight\_p.tmp")
$ErrorActionPreference = "Stop"
$dir = "C:\NetInsight"
$svc = "niagent"
if (-not (Test-Path $PassFile)) { Write-Output "NO_PASSFILE"; exit 1 }
$pass = (Get-Content $PassFile -Raw).Trim()
Remove-Item $PassFile -Force -ErrorAction SilentlyContinue
$sec = ConvertTo-SecureString $pass -AsPlainText -Force
if (-not (Get-LocalUser -Name $svc -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $svc -Password $sec -PasswordNeverExpires -AccountNeverExpires | Out-Null
} else { Set-LocalUser -Name $svc -Password $sec }
$cfgPath = "$dir\Config.json"
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$cfg.Server.RootPath = "\\$ServerIP\InventoryShare"
$cfg | ConvertTo-Json -Depth 10 | Set-Content $cfgPath -Encoding UTF8
$probe = "\\$ServerIP\InventoryShare\Data\JSON\_probe_$env:COMPUTERNAME.txt"
& net.exe use "\\$ServerIP\InventoryShare" /user:"$ServerIP\$svc" $pass 2>&1 | Out-Null
try { "probe" | Set-Content $probe -Encoding UTF8 -ErrorAction Stop; $writeOk = Test-Path $probe } catch { $writeOk = $false }
if ($writeOk) { Remove-Item $probe -Force -ErrorAction SilentlyContinue }
& net.exe use "\\$ServerIP\InventoryShare" /delete /y 2>&1 | Out-Null
$act = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dir\Agent.ps1`""
$delay = Get-Random -Minimum 5 -Maximum 120
$trg = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($delay) -RepetitionInterval (New-TimeSpan -Hours 6)
Register-ScheduledTask -TaskName "NetInsight Agent" -Action $act -Trigger $trg -User "$env:COMPUTERNAME\$svc" -Password $pass -RunLevel Highest -Description "NetInsight collect+upload" -Force | Out-Null
Start-ScheduledTask -TaskName "NetInsight Agent"
if ($writeOk) { Write-Output "OK" } else { Write-Output "OK_NOWRITE" }

