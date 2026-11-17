$ErrorActionPreference = "Continue"
$dir = Split-Path $MyInvocation.MyCommand.Path
$passFile = Join-Path $dir "svc.pass"
$userFile = Join-Path $dir "svc.user"

if ((Test-Path $passFile) -and (Test-Path $userFile)) {
    $pw = (Get-Content $passFile -Raw).Trim()
    $un = (Get-Content $userFile -Raw).Trim()
    $cfg = Get-Content (Join-Path $dir "Config.json") -Raw | ConvertFrom-Json
    $share = $cfg.Server.RootPath
    & net.exe use $share /user:$un $pw /persistent:no 2>&1 | Out-Null
}

& (Join-Path $dir "Agent.ps1")

if (Test-Path $passFile) {
    try {
        $cfg = Get-Content (Join-Path $dir "Config.json") -Raw | ConvertFrom-Json
        & net.exe use $cfg.Server.RootPath /delete /y 2>&1 | Out-Null
    } catch { }
}
