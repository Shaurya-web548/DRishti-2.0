# Starts the DRishti Flask app on http://localhost:5000
# Usage:  .\run-local.ps1  [-Port 5000]
param([int]$Port = 5000)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path $venvPython)) {
    Write-Host "No .venv found. Creating one and installing dependencies..."
    python -m venv (Join-Path $root ".venv")
    & $venvPython -m pip install --upgrade pip
    & $venvPython -m pip install -r (Join-Path $root "app\python\requirements.txt")
    & $venvPython -m pip install "matlabengine==26.1.12"
}

# Load .env (KEY=VALUE lines, # comments ignored) into the process environment.
$envFile = Join-Path $root ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=\s][^=]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}

Write-Host "DRishti running at http://localhost:$Port  (Ctrl+C to stop)"
Push-Location (Join-Path $root "app\python")
try {
    & $venvPython -m flask --app app run --port $Port --debug --no-reload
} finally {
    Pop-Location
}
