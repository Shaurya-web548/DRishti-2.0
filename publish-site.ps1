# Publishes the DRishti website to GitHub Pages.
#
#   .\publish-site.ps1
#
# Builds the static copy of the site (tools/pages/build_pages.py) and pushes
# ONLY that output - HTML, CSS, JavaScript - to the public site repository
# named in app/python/content/team.json (project.siteRepository). The source
# code repository can stay private: GitHub's free plan cannot publish Pages
# from a private repository, so the website lives in its own public one.
#
# Re-run it whenever the site changes. Nothing needs MATLAB.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) { $venvPython = "python" }

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "Install the GitHub CLI (gh) and run 'gh auth login' first." }

$team = Get-Content (Join-Path $root "app\python\content\team.json") -Raw | ConvertFrom-Json
$siteRepo = ($team.project.siteRepository -replace '^https://github.com/', '').TrimEnd('/')
$siteUrl = $team.project.projectPage
if ($siteRepo -notmatch '^[\w.-]+/[\w.-]+$' -or -not $siteUrl) {
    throw "Set project.siteRepository and project.projectPage in app/python/content/team.json."
}
$siteUri = [Uri]$siteUrl
$basePath = $siteUri.AbsolutePath.TrimEnd('/')
# A custom domain (e.g. drishti.example.com) is served from the site root and
# needs a CNAME file; a github.io project page is served under /<repo>.
$customDomain = if ($siteUri.Host -notlike "*.github.io") { $siteUri.Host } else { $null }

# ------------------------------------------------------------ repository
gh repo view $siteRepo --json name 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Step "Creating public repository $siteRepo (website files only)"
    gh repo create $siteRepo --public `
        --description "Website for DRishti - diabetic retinopathy screening and a district capacity model. Built files only." `
        --homepage $siteUrl | Out-Null
}

# ----------------------------------------------------------------- build
$out = Join-Path $root "site"
Write-Step "Building the static site (base path $basePath)"
# --base=<value> in one argument: Windows PowerShell drops an empty "" argument.
& $venvPython (Join-Path $root "tools\pages\build_pages.py") "--base=$basePath" --out $out
if ($LASTEXITCODE -ne 0) { throw "The site build failed." }
if ($customDomain) {
    [IO.File]::WriteAllText((Join-Path $out "CNAME"), "$customDomain`n")
}

# --------------------------------------------------------------- publish
$codeCommit = (git -C $root rev-parse --short HEAD 2>$null)
$work = Join-Path ([IO.Path]::GetTempPath()) "drishti-site-publish"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
Copy-Item $out $work -Recurse

Write-Step "Publishing to github.com/$siteRepo"
Push-Location $work
try {
    git init -q -b main
    git add -A
    git commit -q -m "site: publish $(Get-Date -Format 'yyyy-MM-dd HH:mm') from code $codeCommit"
    # The site repo holds build output only, so each publish replaces main.
    # The separate `live` branch (live-screening status) is left alone.
    git push -q --force "https://github.com/$siteRepo.git" main
    if ($LASTEXITCODE -ne 0) { throw "git push to $siteRepo failed." }
} finally {
    Pop-Location
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

# ----------------------------------------------------------------- pages
gh api "repos/$siteRepo/pages" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Step "Turning on GitHub Pages"
    gh api -X POST "repos/$siteRepo/pages" -f "source[branch]=main" -f "source[path]=/" | Out-Null
}

Write-Step "Checking the website responds (GitHub can take 1-2 minutes to show a new version)"
$ok = $false
for ($i = 0; $i -lt 60 -and -not $ok; $i++) {
    Start-Sleep -Seconds 5
    try { $ok = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 $siteUrl).StatusCode -eq 200 } catch { }
}
if ($ok) {
    Write-Host ""
    Write-Host "  Website live at: $siteUrl" -ForegroundColor Green
} else {
    Write-Warning "Published, but $siteUrl is not answering yet. GitHub can take a few minutes the first time."
}
