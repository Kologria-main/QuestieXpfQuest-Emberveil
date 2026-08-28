[CmdletBinding()]
param(
    [switch]$SkipInstallerTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$addon = Join-Path $repo 'addon\KoQuest'
$manifestPath = Join-Path $repo 'installer\payload-manifest.sha256'
$installer = Join-Path $repo 'installer\Install-Questie-Emberveil.ps1'
$linuxInstaller = Join-Path $repo 'INSTALL_KOQUEST_LINUX.sh'

function Read-Manifest {
    $entries = @()
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([A-Fa-f0-9]{64})\s+\*addon/KoQuest/(.+)$') { throw "Invalid manifest line: $line" }
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
    param([string]$Script, [string]$AddOns, [string]$State, [string]$SavedVariables, [switch]$ValidateOnly)
    $hostExe = (Get-Process -Id $PID).Path
    $args = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script,
        '-InstallHint', $AddOns, '-NonInteractive', '-StateRoot', $State,
        '-SavedVariablesRoot', $SavedVariables)
    if ($ValidateOnly) { $args += '-ValidateOnly' }
    & $hostExe @args | ForEach-Object { Write-Host $_ }
    $code = $LASTEXITCODE
    return $code
}

function Convert-ToMsysPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        return ('/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/'))
    }
    return $full.Replace('\', '/')
}

function Find-PosixShell {
    $command = Get-Command bash -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($candidate in @(
        'C:\Program Files\Git\bin\bash.exe',
        'C:\Program Files\Git\usr\bin\sh.exe',
        'C:\Program Files (x86)\Git\bin\bash.exe',
        '/bin/sh'
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

$manifest = @(Read-Manifest)
if ($manifest.Count -lt 250) { throw 'Payload manifest is unexpectedly small.' }
Assert-TreeMatchesManifest $addon $manifest

foreach ($xmlFile in Get-ChildItem -LiteralPath $addon -Recurse -Filter '*.xml' -File) {
    [xml](Get-Content -LiteralPath $xmlFile.FullName -Raw) | Out-Null
}

$validateState = Join-Path ([System.IO.Path]::GetTempPath()) ('.qev-validate-' + [guid]::NewGuid().ToString('N'))
try {
    $validateSavedVariables = Join-Path $validateState 'SavedVariables'
    New-Item -ItemType Directory -Path $validateSavedVariables -Force | Out-Null
    $exitCode = Invoke-InstallerProcess $installer $repo $validateState $validateSavedVariables -ValidateOnly
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
    $savedVariables = Join-Path $testRoot 'SavedVariables'
    try {
        New-Item -ItemType Directory -Path $addOns -Force | Out-Null
        New-Item -ItemType Directory -Path $savedVariables -Force | Out-Null

        $savedVariableFile = Join-Path $savedVariables 'pfQuest.lua'
        @(
            'pfQuest_track = {'
            '  texture = "Interface\\AddOns\\pfQuest\\img\\tracking\\available"'
            '}'
            'pfQuest_config = { allquestgivers = "1" }'
        ) | Set-Content -LiteralPath $savedVariableFile -Encoding ASCII
        $historyOnlyRoot = Join-Path $savedVariables 'AccountWide'
        New-Item -ItemType Directory -Path $historyOnlyRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $historyOnlyRoot 'pfQuest.lua') `
            -Value 'pfQuest_history = { [42] = { 1, 10 } }' -Encoding ASCII

        $legacy = Join-Path $addOns 'pfQuest'
        New-Item -ItemType Directory -Path $legacy -Force | Out-Null
        @(
            '## Title: KoQuest (legacy folder)'
            '## Version: EV-2.0.0-beta1.20'
        ) | Set-Content -LiteralPath (Join-Path $legacy 'pfQuest.toc') -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $legacy 'legacy-marker.txt') -Value 'legacy-koquest' -Encoding ASCII

        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $exitCode = Invoke-InstallerProcess $installer $addOns $state $savedVariables
        $timer.Stop()
        if ($exitCode -ne 0) { throw "Clean installer test failed with exit code $exitCode." }
        if ($timer.Elapsed.TotalSeconds -gt 45) { throw "Installer isolation test exceeded 45 seconds." }
        $repairedText = Get-Content -LiteralPath $savedVariableFile -Raw
        if ($repairedText -match '(?m)^pfQuest_track[ `t]*=') {
            throw 'Installer did not remove the unsafe pfQuest_track assignment.'
        }
        if ($repairedText -notmatch '(?m)^pfQuest_config[ `t]*=') {
            throw 'Installer damaged unrelated SavedVariables data.'
        }
        $savedBackup = @(Get-ChildItem -LiteralPath (Join-Path $state 'Backups') -Recurse -Filter '*pfQuest.lua' -File)
        if ($savedBackup.Count -eq 0) { throw 'Installer did not back up the repaired SavedVariables file.' }
        $migratedSavedVariableFile = Join-Path $savedVariables 'KoQuest.lua'
        if (-not (Test-Path -LiteralPath $migratedSavedVariableFile -PathType Leaf)) {
            throw 'Installer did not create isolated KoQuest SavedVariables.'
        }
        $migratedText = Get-Content -LiteralPath $migratedSavedVariableFile -Raw
        if ($migratedText -notmatch '(?m)^KoQuest_config[ `t]*=') {
            throw 'Installer did not migrate KoQuest_config into the isolated namespace.'
        }
        if ($migratedText -match '(?m)^pfQuest_config[ `t]*=') {
            throw 'Installer left a legacy pfQuest_config assignment in KoQuest SavedVariables.'
        }
        $historyOnlyMigrated = Get-Content -LiteralPath (Join-Path $historyOnlyRoot 'KoQuest.lua') -Raw
        if ($historyOnlyMigrated -notmatch '(?m)^KoQuest_history[ `t]*=') {
            throw 'Installer skipped a history-only account-wide KoQuest SavedVariables file.'
        }
        if (Test-Path -LiteralPath $legacy) {
            throw 'Installer left the recognized legacy KoQuest pfQuest folder active.'
        }

        $installed = Join-Path $addOns 'KoQuest'
        Assert-TreeMatchesManifest $installed $manifest

        $legacyMarker = Join-Path $installed 'legacy-marker.txt'
        Set-Content -LiteralPath $legacyMarker -Value 'backup-test' -Encoding ASCII
        $exitCode = Invoke-InstallerProcess $installer $addOns $state $savedVariables
        if ($exitCode -ne 0) { throw "Upgrade installer test failed with exit code $exitCode." }
        Assert-TreeMatchesManifest $installed $manifest
        if (Test-Path -LiteralPath $legacyMarker) { throw 'Upgrade left an obsolete file in the installed addon.' }
        $backupMarker = @(Get-ChildItem -LiteralPath (Join-Path $state 'Backups') -Recurse -Filter 'legacy-marker.txt' -File)
        if (-not $backupMarker) { throw 'Upgrade did not preserve the previous addon in a backup.' }

        # A genuine upstream pfQuest installation is not KoQuest legacy and
        # must survive an install/upgrade byte-for-byte.
        New-Item -ItemType Directory -Path $legacy -Force | Out-Null
        @(
            '## Title: pfQuest'
            '## Version: 6.0.0'
        ) | Set-Content -LiteralPath (Join-Path $legacy 'pfQuest.toc') -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $legacy 'upstream-marker.txt') -Value 'preserve-me' -Encoding ASCII
        $exitCode = Invoke-InstallerProcess $installer $addOns $state $savedVariables
        if ($exitCode -ne 0) { throw "Coexistence installer test failed with exit code $exitCode." }
        if (-not (Test-Path -LiteralPath (Join-Path $legacy 'upstream-marker.txt') -PathType Leaf)) {
            throw 'Installer modified or removed a genuine upstream pfQuest installation.'
        }
        Assert-TreeMatchesManifest $installed $manifest

        $tamperedRoot = Join-Path $testRoot 'TamperedRelease'
        New-Item -ItemType Directory -Path (Join-Path $tamperedRoot 'addon') -Force | Out-Null
        Copy-Item -LiteralPath $addon -Destination (Join-Path $tamperedRoot 'addon') -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $repo 'installer') -Destination $tamperedRoot -Recurse -Force
        Add-Content -LiteralPath (Join-Path $tamperedRoot 'addon\KoQuest\compat\emberveil.lua') -Value '-- tampered'
        $tamperedInstaller = Join-Path $tamperedRoot 'installer\Install-Questie-Emberveil.ps1'
        $exitCode = Invoke-InstallerProcess $tamperedInstaller $addOns (Join-Path $testRoot 'TamperedState') $savedVariables
        if ($exitCode -eq 0) { throw 'Tampered-payload installer test unexpectedly succeeded.' }
        Assert-TreeMatchesManifest $installed $manifest

        $posixShell = Find-PosixShell
        if (-not $posixShell) { throw 'No POSIX shell is available to validate the advertised Linux installer.' }
        & $posixShell -n (Convert-ToMsysPath $linuxInstaller)
        if ($LASTEXITCODE -ne 0) { throw "Linux installer syntax validation failed with exit code $LASTEXITCODE." }
        $linuxAddOns = Join-Path $testRoot 'Linux\Emberveil\live\Azeroth\Interface\AddOns'
        $linuxSavedVariables = Join-Path $testRoot 'Linux\SavedVariables'
        New-Item -ItemType Directory -Path $linuxAddOns -Force | Out-Null
        New-Item -ItemType Directory -Path $linuxSavedVariables -Force | Out-Null
        $linuxLegacy = Join-Path $linuxAddOns 'pfQuest'
        New-Item -ItemType Directory -Path $linuxLegacy -Force | Out-Null
        @(
            '## Title: KoQuest (legacy folder)'
            '## Version: EV-2.0.0-beta1.20'
        ) | Set-Content -LiteralPath (Join-Path $linuxLegacy 'pfQuest.toc') -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $linuxSavedVariables 'pfQuest.lua') -Value 'pfQuest_config = { allquestgivers = "1" }' -Encoding ASCII
        & $posixShell (Convert-ToMsysPath $linuxInstaller) (Convert-ToMsysPath $linuxAddOns) (Convert-ToMsysPath $linuxSavedVariables) |
            ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Linux installer test failed with exit code $LASTEXITCODE." }
        Assert-TreeMatchesManifest (Join-Path $linuxAddOns 'KoQuest') $manifest
        if (Test-Path -LiteralPath $linuxLegacy) { throw 'Linux installer left the legacy KoQuest pfQuest folder active.' }
        $linuxMigrated = Get-Content -LiteralPath (Join-Path $linuxSavedVariables 'KoQuest.lua') -Raw
        if ($linuxMigrated -notmatch '(?m)^KoQuest_config[ `t]*=') {
            throw 'Linux installer did not migrate isolated KoQuest SavedVariables.'
        }

        Write-Host 'PASS: namespace migration, pfQuest coexistence, Windows install/upgrade, tamper rejection, and Linux install passed.' -ForegroundColor Green
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

# The tamper-rejection test intentionally launches an installer that exits 1.
# PowerShell 7 retains that native process code in $LASTEXITCODE even after every
# assertion succeeds, so finish explicitly with the validation result.
exit 0
