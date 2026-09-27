# Tells the GitHub Pages site whether live screening is running.
#
#   .\tools\live-status.ps1 -Url https://abc.trycloudflare.com   # online
#   .\tools\live-status.ps1 -Url <project.liveUrl in team.json>  # online, named tunnel
#   .\tools\live-status.ps1 -Offline                              # offline
#
# Writes live.json to the `live` branch of the public site repository named in
# app/python/content/team.json (project.siteRepository), using the GitHub CLI (gh) you are logged in
# with. The branch holds only that one file, so this never touches main and
# never triggers a site rebuild. The Pages scan page reads it and then pings
# the server itself, so a stale "online" (laptop switched off) is harmless.
param(
    [string]$Url,
    [switch]$Offline
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$team = Get-Content (Join-Path $root "app\python\content\team.json") -Raw | ConvertFrom-Json
$liveUrl = "$($team.project.liveUrl)".Trim().TrimEnd('/')

if (-not $Offline -and $Url -notmatch '^https://[a-z0-9-]+\.trycloudflare\.com$' -and -not ($liveUrl -and $Url -eq $liveUrl)) {
    throw "Pass -Url https://<name>.trycloudflare.com (or the project.liveUrl from team.json), or -Offline."
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "The GitHub CLI (gh) is not installed, so the Pages site cannot be told."
}

# The public site repository: the code repository may be private, and the
# website has to be able to read this file without logging in.
$repo = ($team.project.siteRepository -replace '^https://github.com/', '').TrimEnd('/')
if ($repo -notmatch '^[\w.-]+/[\w.-]+$') { throw "team.json has no usable project.siteRepository." }

$status = [ordered]@{
    online  = -not $Offline
    url     = $(if ($Offline) { "" } else { $Url })
    updated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}
$content = $status | ConvertTo-Json -Compress

function Invoke-GhJson([string]$Method, [string]$Path, $Body) {
    $tmp = New-TemporaryFile
    try {
        # No byte-order mark: Windows PowerShell 5's utf8 adds one, which gh rejects.
        [IO.File]::WriteAllText($tmp, ($Body | ConvertTo-Json -Depth 6 -Compress))
        $out = gh api -X $Method $Path --input $tmp 2>&1
        if ($LASTEXITCODE -ne 0) { throw "gh api $Method $Path failed: $out" }
        return $out | ConvertFrom-Json
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

# Current tip of the live branch, if it exists yet.
$parent = $null
$ref = gh api "repos/$repo/git/ref/heads/live" 2>$null
if ($LASTEXITCODE -eq 0) { $parent = ($ref | ConvertFrom-Json).object.sha }

$tree = Invoke-GhJson POST "repos/$repo/git/trees" @{
    tree = @(@{ path = "live.json"; mode = "100644"; type = "blob"; content = $content })
}
$commitBody = @{
    message = $(if ($Offline) { "live: offline" } else { "live: online at $Url" })
    tree    = $tree.sha
    parents = @($(if ($parent) { $parent }))
}
if (-not $parent) { $commitBody.parents = @() }
$commit = Invoke-GhJson POST "repos/$repo/git/commits" $commitBody

if ($parent) {
    Invoke-GhJson PATCH "repos/$repo/git/refs/heads/live" @{ sha = $commit.sha; force = $true } | Out-Null
} else {
    Invoke-GhJson POST "repos/$repo/git/refs" @{ ref = "refs/heads/live"; sha = $commit.sha } | Out-Null
}

$state = $(if ($Offline) { "offline" } else { "online at $Url" })
Write-Host "Pages site told: live screening is $state"
