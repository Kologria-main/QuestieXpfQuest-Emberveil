[CmdletBinding()]
param(
    [switch]$SkipInstallerTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$addon = Join-Path $repo 'addon\pfQuest'
$manifestPath = Join-Path $repo 'installer\payload-manifest.sha256'
$installer = Join-Path $repo 'installer\Install-Questie-Emberveil.ps1'

function Read-Manifest {
    $entries = @()
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([A-Fa-f0-9]{64})\s+\*addon/pfQuest/(.+)$') { throw "Invalid manifest line: $line" }
        $entries += [pscustomobject]@{
            Hash = $Matches[1].ToUpperInvariant()
            Relative = $Matches[2].Replace('/', '\')
        }
    }
    return $entries
}

function Assert-TreeMatchesManifest {
    param([string]$Root, [object[]]$Manifest)
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File)
    if ($files.Count -ne $Manifest.Count) { throw "File count mismatch under $Root" }
    foreach ($entry in $Manifest) {
        $file = Join-Path $Root $entry.Relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing $($entry.Relative) under $Root" }
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($hash -ne $entry.Hash) { throw "Hash mismatch for $($entry.Relative) under $Root" }
    }
}

function Invoke-InstallerProcess {
    param([string]$Script, [string]$AddOns, [string]$State, [switch]$ValidateOnly)
    $hostExe = (Get-Process -Id $PID).Path
    $args = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script,
        '-InstallHint', $AddOns, '-NonInteractive', '-StateRoot', $State)
    if ($ValidateOnly) { $args += '-ValidateOnly' }
    & $hostExe @args | ForEach-Object { Write-Host $_ }
    $code = $LASTEXITCODE
    return $code
}

$manifest = @(Read-Manifest)
if ($manifest.Count -lt 250) { throw 'Payload manifest is unexpectedly small.' }
Assert-TreeMatchesManifest $addon $manifest

foreach ($xmlFile in Get-ChildItem -LiteralPath $addon -Recurse -Filter '*.xml' -File) {
    [xml](Get-Content -LiteralPath $xmlFile.FullName -Raw) | Out-Null
}

$validateState = Join-Path ([System.IO.Path]::GetTempPath()) ('.qev-validate-' + [guid]::NewGuid().ToString('N'))
try {
    $exitCode = Invoke-InstallerProcess $installer $repo $validateState -ValidateOnly
    if ($exitCode -ne 0) { throw "Installer validation-only mode failed with exit code $exitCode." }
} finally {
    if (Test-Path -LiteralPath $validateState) {
        $resolved = [System.IO.Path]::GetFullPath($validateState)
        if ([System.IO.Path]::GetFileName($resolved).StartsWith('.qev-validate-')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

if (-not $SkipInstallerTests) {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('.qev-installer-test-' + [guid]::NewGuid().ToString('N'))
    $addOns = Join-Path $testRoot 'Games\Emberveil\live\Azeroth\Interface\AddOns'
    $state = Join-Path $testRoot 'State'
    try {
        New-Item -ItemType Directory -Path $addOns -Force | Out-Null

        $exitCode = Invoke-InstallerProcess $installer $addOns $state
        if ($exitCode -ne 0) { throw "Clean installer test failed with exit code $exitCode." }
        $installed = Join-Path $addOns 'pfQuest'
        Assert-TreeMatchesManifest $installed $manifest

        $legacyMarker = Join-Path $installed 'legacy-marker.txt'
        Set-Content -LiteralPath $legacyMarker -Value 'backup-test' -Encoding ASCII
        $exitCode = Invoke-InstallerProcess $installer $addOns $state
        if ($exitCode -ne 0) { throw "Upgrade installer test failed with exit code $exitCode." }
        Assert-TreeMatchesManifest $installed $manifest
        if (Test-Path -LiteralPath $legacyMarker) { throw 'Upgrade left an obsolete file in the installed addon.' }
        $backupMarker = Get-ChildItem -LiteralPath (Join-Path $state 'Backups') -Recurse -Filter 'legacy-marker.txt' -File
        if (-not $backupMarker) { throw 'Upgrade did not preserve the previous addon in a backup.' }

        $tamperedRoot = Join-Path $testRoot 'TamperedRelease'
        New-Item -ItemType Directory -Path (Join-Path $tamperedRoot 'addon') -Force | Out-Null
        Copy-Item -LiteralPath $addon -Destination (Join-Path $tamperedRoot 'addon') -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $repo 'installer') -Destination $tamperedRoot -Recurse -Force
        Add-Content -LiteralPath (Join-Path $tamperedRoot 'addon\pfQuest\compat\emberveil.lua') -Value '-- tampered'
        $tamperedInstaller = Join-Path $tamperedRoot 'installer\Install-Questie-Emberveil.ps1'
        $exitCode = Invoke-InstallerProcess $tamperedInstaller $addOns (Join-Path $testRoot 'TamperedState')
        if ($exitCode -eq 0) { throw 'Tampered-payload installer test unexpectedly succeeded.' }
        Assert-TreeMatchesManifest $installed $manifest

        Write-Host 'PASS: installer clean install, upgrade/backup, and tamper rejection passed.' -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $testRoot) {
            $resolved = [System.IO.Path]::GetFullPath($testRoot)
            if ([System.IO.Path]::GetFileName($resolved).StartsWith('.qev-installer-test-')) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    }
}

Write-Host "PASS: release source and $($manifest.Count)-file payload manifest are valid." -ForegroundColor Green
