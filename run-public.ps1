# Puts DRishti on a public https:// link through a Cloudflare quick tunnel.
#
#   .\run-public.ps1              then share the link it prints
#   Ctrl+C                        stops the server and the tunnel
#
# Differences from run-local.ps1:
#   - production server (waitress), debug OFF - the Flask debugger must never
#     be reachable from the internet
#   - per-visitor rate limits and 24-hour deletion of uploaded photographs
#   - listens on 127.0.0.1 only; the public reaches it through cloudflared
#
# The link changes every time this script starts, and it only works while
# this laptop is on and the script is running.
param([int]$Port = 5000)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = Join-Path $root ".venv\Scripts\python.exe"
$appDir = Join-Path $root "app\python"
$logDir = Join-Path $root "logs"
$cloudflared = Join-Path $root "tools\cloudflared\cloudflared.exe"

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }

# Stop a process and everything it started (the MATLAB engine is a child of
# the Python server, and would otherwise keep running after Ctrl+C).
function Stop-Tree([int]$ProcessId) {
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Tree $_.ProcessId }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------ dependencies
if (-not (Test-Path $venvPython)) {
    Write-Step "Creating .venv and installing dependencies"
    python -m venv (Join-Path $root ".venv")
    & $venvPython -m pip install --upgrade pip
    & $venvPython -m pip install -r (Join-Path $appDir "requirements.txt")
    & $venvPython -m pip install "matlabengine==26.1.12"
}
& $venvPython -c "import waitress" 2>$null
if ($LASTEXITCODE -ne 0) { & $venvPython -m pip install waitress }

if (-not (Test-Path $cloudflared)) {
    Write-Step "Downloading cloudflared"
    New-Item -ItemType Directory -Force (Split-Path $cloudflared) | Out-Null
    Invoke-WebRequest -UseBasicParsing -OutFile $cloudflared `
        -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    $sig = Get-AuthenticodeSignature $cloudflared
    if ($sig.Status -ne "Valid" -or $sig.SignerCertificate.Subject -notmatch "Cloudflare") {
        Remove-Item $cloudflared -Force
        throw "Downloaded cloudflared is not signed by Cloudflare; refusing to run it."
    }
}

# ------------------------------------------------------------ environment
$envFile = Join-Path $root ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=\s][^=]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}
$env:PORT = "$Port"
$env:PYTHONUNBUFFERED = "1"

if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    throw "Port $Port is already in use. Close the run-local.ps1 window (or whatever uses it) first."
}

New-Item -ItemType Directory -Force $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$serverOut = Join-Path $logDir "server-$stamp.log"
$serverErr = Join-Path $logDir "server-$stamp.err.log"
$tunnelLog = Join-Path $logDir "tunnel-$stamp.log"

$server = $null
$tunnel = $null
$announced = $false
try {
    # -------------------------------------------------------- web server
    Write-Step "Starting the production server on 127.0.0.1:$Port"
    $server = Start-Process -FilePath $venvPython -ArgumentList "serve.py" -WorkingDirectory $appDir `
        -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr -WindowStyle Hidden -PassThru

    $up = $false
    for ($i = 0; $i -lt 90 -and -not $up; $i++) {
        Start-Sleep -Seconds 1
        if ($server.HasExited) { throw "The server stopped during start-up. See $serverErr" }
        try { $up = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:$Port/").StatusCode -eq 200 } catch { }
    }
    if (-not $up) { throw "The server did not answer within 90 seconds. See $serverErr" }

    # ------------------------------------------------------------ tunnel
    Write-Step "Opening the Cloudflare tunnel"
    $tunnel = Start-Process -FilePath $cloudflared `
        -ArgumentList "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$Port" `
        -RedirectStandardError $tunnelLog -RedirectStandardOutput "$tunnelLog.out" -WindowStyle Hidden -PassThru

    $url = $null
    for ($i = 0; $i -lt 60 -and -not $url; $i++) {
        Start-Sleep -Seconds 1
        if ($tunnel.HasExited) { throw "cloudflared stopped. See $tunnelLog" }
        $hit = Select-String -Path $tunnelLog -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { $url = $hit.Matches[0].Value }
    }
    if (-not $url) { throw "No public link appeared within 60 seconds. See $tunnelLog" }

    Set-Content -Path (Join-Path $logDir "public-url.txt") -Value $url

    # Tell the permanent GitHub Pages site, so its scan page links here.
    try {
        & (Join-Path $root "tools\live-status.ps1") -Url $url
        $announced = $true
    } catch {
        Write-Warning "Live, but the GitHub Pages site could not be told: $($_.Exception.Message)"
    }

    $siteUrl = $null
    try { $siteUrl = (Get-Content (Join-Path $appDir "content	eam.json") -Raw | ConvertFrom-Json).project.projectPage } catch { }
    Write-Host ""
    Write-Host "  DRishti is live at:  $url" -ForegroundColor Green
    Write-Host "  Simulink demo:       $url/simulink?preset=growth" -ForegroundColor Green
    if ($siteUrl) { Write-Host "  Permanent website:   $siteUrl  (its scan page now links here)" -ForegroundColor Green }
    Write-Host ""
    Write-Host "  Keep this window open. Press Ctrl+C to take the site offline."
    Start-Process $url

    while (-not $server.HasExited -and -not $tunnel.HasExited) { Start-Sleep -Seconds 2 }
    Write-Warning "The server or the tunnel stopped. Logs are in $logDir"
}
finally {
    foreach ($p in @($tunnel, $server)) {
        if ($p) { Stop-Tree $p.Id }
    }
    if ($announced) {
        try { & (Join-Path $root "tools\live-status.ps1") -Offline } catch { Write-Warning "Could not mark the website offline: $($_.Exception.Message)" }
    }
    Write-Host "DRishti is offline."
}
