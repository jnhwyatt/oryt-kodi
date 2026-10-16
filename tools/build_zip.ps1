<#
.SYNOPSIS
    Builds a release zip for the Oryt Kodi addon (plugin.video.oryttv).

.DESCRIPTION
    Stages a clean copy of the addon, optionally stamps the build-time update
    channel (ORYT_UPDATE_USER / ORYT_UPDATE_REPO in resources/lib/modules/updater.py),
    sets the addon.xml version, prepends a dated entry to changelog.txt, optionally
    bundles a pre-authorized account file, then zips the result into
    kodi-addon/packages/ and refreshes the oryt_version / oryt_changes manifests.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_zip.ps1 -Version 1.0.1 -GitHubUser myuser -GitHubRepo myrepo

.NOTES
    Windows PowerShell 5.1 compatible. ASCII only.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$GitHubUser,

    [string]$GitHubRepo,

    [string]$SecretsPath
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths -----------------------------------------------------------
$scriptDir     = $PSScriptRoot
$addonRepoDir  = Split-Path -Parent $scriptDir          # kodi-addon
$workspaceRoot = Split-Path -Parent $addonRepoDir       # workspace root
$addonSrc      = Join-Path $addonRepoDir 'plugin.video.oryttv'
$packagesDir   = Join-Path $addonRepoDir 'packages'
$zipName       = "plugin.video.oryttv-$Version.zip"
$zipPath       = Join-Path $packagesDir $zipName

if ([string]::IsNullOrWhiteSpace($SecretsPath)) {
    $SecretsPath = Join-Path $workspaceRoot 'secrets\oryt_account.json'
}

# --- Validate input ----------------------------------------------------------
if ($Version -match '[\\/:*?"<>|]') { throw "Invalid -Version value: $Version" }
$userProvided = -not [string]::IsNullOrWhiteSpace($GitHubUser)
$repoProvided = -not [string]::IsNullOrWhiteSpace($GitHubRepo)
if ($userProvided -xor $repoProvided) { throw 'Provide both -GitHubUser and -GitHubRepo, or neither.' }
if ($userProvided) {
    if ($GitHubUser -notmatch '^[A-Za-z0-9]([A-Za-z0-9._-]*)$') { throw "Invalid -GitHubUser value: $GitHubUser" }
    if ($GitHubRepo -notmatch '^[A-Za-z0-9]([A-Za-z0-9._-]*)$') { throw "Invalid -GitHubRepo value: $GitHubRepo" }
}
if (-not (Test-Path $addonSrc)) { throw "Addon source not found: $addonSrc" }
if (-not (Test-Path $packagesDir)) { New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null }

$stagingRoot  = Join-Path $env:TEMP ('oryt_build_' + [Guid]::NewGuid().ToString('N'))
$stagedAddon  = Join-Path $stagingRoot 'plugin.video.oryttv'
$today        = Get-Date -Format 'yyyy-MM-dd'
$crlf         = "`r`n"

try {
    # (a) Stage a temp copy of the addon --------------------------------------
    Write-Host "Staging $addonSrc -> $stagedAddon"
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    Copy-Item -Path $addonSrc -Destination $stagedAddon -Recurse
    Get-ChildItem -Path $stagedAddon -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force
    Get-ChildItem -Path $stagedAddon -Recurse -Force -File -Include '*.pyc', '*.pyo' | Remove-Item -Force

    # (b) Stamp the build-time update channel ---------------------------------
    $updaterPath = Join-Path $stagedAddon 'resources\lib\modules\updater.py'
    $updaterText = [System.IO.File]::ReadAllText($updaterPath)
    if ($userProvided) {
        $updaterText = $updaterText.Replace("ORYT_UPDATE_USER = 'ORYT_UPDATE_USER'", "ORYT_UPDATE_USER = '$GitHubUser'")
        $updaterText = $updaterText.Replace("ORYT_UPDATE_REPO = 'ORYT_UPDATE_REPO'", "ORYT_UPDATE_REPO = '$GitHubRepo'")
        if ($updaterText -notmatch [regex]::Escape("ORYT_UPDATE_USER = '$GitHubUser'")) { throw 'Failed to stamp ORYT_UPDATE_USER in updater.py' }
        if ($updaterText -notmatch [regex]::Escape("ORYT_UPDATE_REPO = '$GitHubRepo'")) { throw 'Failed to stamp ORYT_UPDATE_REPO in updater.py' }
        [System.IO.File]::WriteAllText($updaterPath, $updaterText)
        Write-Host "Stamped update channel: $GitHubUser/$GitHubRepo"
    }
    else {
        Write-Host 'No -GitHubUser/-GitHubRepo given: updater.py placeholders left intact (updates disabled in this build).'
    }

    # (c) Set the staged addon.xml version ------------------------------------
    $addonXmlPath = Join-Path $stagedAddon 'addon.xml'
    $xmlText      = [System.IO.File]::ReadAllText($addonXmlPath)
    $xmlPattern   = '(<addon id="plugin\.video\.oryttv"[^>]*?\sversion=")[^"]*(")'
    $xmlReplacement = '${1}' + $Version.Replace('$', '$$') + '${2}'
    $xmlNew       = [regex]::Replace($xmlText, $xmlPattern, $xmlReplacement)
    if (-not [regex]::IsMatch($xmlText, $xmlPattern)) { throw 'Failed to set version in addon.xml (pattern not matched)' }
    [System.IO.File]::WriteAllText($addonXmlPath, $xmlNew)
    Write-Host "Set addon.xml version to $Version"

    # (d) Prepend a dated entry to the staged changelog.txt --------------------
    $changelogPath = Join-Path $stagedAddon 'resources\text\changelog.txt'
    $entry         = "[COLOR dodgerblue][B]Version $Version ($today)[/B][/COLOR]" + $crlf + "- Oryt $Version release."
    $existingLog   = [System.IO.File]::ReadAllText($changelogPath)
    [System.IO.File]::WriteAllText($changelogPath, $entry + $crlf + $crlf + $existingLog)
    Write-Host "Prepended Version $Version ($today) entry to changelog.txt"

    # (e) Bundle the pre-authorized account, if present ------------------------
    if (Test-Path $SecretsPath) {
        $dataDir = Join-Path $stagedAddon 'resources\data'
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        Copy-Item -Path $SecretsPath -Destination (Join-Path $dataDir 'oryt_account.json') -Force
        Write-Host "Bundled pre-authorized account from $SecretsPath"
    }
    else {
        Write-Host ''
        Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Yellow
        Write-Host 'WARNING: secrets file not found:' -ForegroundColor Yellow
        Write-Host "  $SecretsPath" -ForegroundColor Yellow
        Write-Host 'The zip will have NO pre-authorized account bundled.' -ForegroundColor Yellow
        Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Yellow
        Write-Host ''
    }

    # (f) Zip the staged folder (folder itself at the zip root) ---------------
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path $stagedAddon -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Wrote $zipPath"

    # (g) Refresh the packages/ manifests --------------------------------------
    # oryt_version: bare version string, no trailing newline.
    # oryt_changes: latest changelog entry only (Kodi BBCode, CRLF, no trailing newline).
    [System.IO.File]::WriteAllText((Join-Path $packagesDir 'oryt_version'), $Version)
    [System.IO.File]::WriteAllText((Join-Path $packagesDir 'oryt_changes'), $entry)
    Write-Host 'Updated packages/oryt_version and packages/oryt_changes'

    # (h) Print git next steps -------------------------------------------------
    Write-Host ''
    Write-Host 'Build complete. Git next steps:'
    Write-Host "  cd `"$addonRepoDir`""
    Write-Host "  git add packages/oryt_version packages/oryt_changes packages/$zipName"
    Write-Host "  git commit -m `"Release plugin.video.oryttv $Version`""
    Write-Host '  git push origin main'
    if (-not $userProvided) {
        Write-Host ''
        Write-Host 'NOTE: this build has updates disabled. Rebuild with -GitHubUser/-GitHubRepo' -ForegroundColor Yellow
        Write-Host '      to enable the self-managed update channel.' -ForegroundColor Yellow
    }
}
finally {
    if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
