[CmdletBinding()]
param(
    [string]$InstallHint,
    [switch]$NonInteractive,
    [switch]$ValidateOnly,
    [string]$StateRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Version = '2.0.0-beta1.15'
$ReleaseRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$SourceRoot = [System.IO.Path]::GetFullPath((Join-Path $ReleaseRoot 'addon\pfQuest'))
$ManifestPath = Join-Path $PSScriptRoot 'payload-manifest.sha256'

if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path $env:LOCALAPPDATA 'QuestieEV'
}
$StateRoot = [System.IO.Path]::GetFullPath($StateRoot)
$LogRoot = Join-Path $StateRoot 'Logs'
$BackupRoot = Join-Path $StateRoot 'Backups'
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$LogPath = Join-Path $LogRoot ("install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

function Write-InstallLog {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    Write-Host $Message -ForegroundColor $Color
}

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Test-AddOnsPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try { $full = Get-NormalizedPath $Path } catch { return $false }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { return $false }
    if ([System.IO.Path]::GetFileName($full) -ine 'AddOns') { return $false }
    return [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($full)) -ieq 'Interface'
}

function Add-Candidate {
    param([System.Collections.Generic.List[string]]$List, [hashtable]$Seen, [string]$Path)
    if (-not (Test-AddOnsPath $Path)) { return }
    $full = Get-NormalizedPath $Path
    $key = $full.ToLowerInvariant()
    if (-not $Seen.ContainsKey($key)) {
        $Seen[$key] = $true
        $List.Add($full)
    }
}

function Add-CandidatesFromHint {
    param([System.Collections.Generic.List[string]]$List, [hashtable]$Seen, [string]$Hint)
    if ([string]::IsNullOrWhiteSpace($Hint)) { return }
    try {
        $full = Get-NormalizedPath $Hint
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $full = [System.IO.Path]::GetDirectoryName($full)
        }
    } catch { return }

    $current = $full
    for ($i = 0; $i -lt 10 -and $current; $i++) {
        Add-Candidate $List $Seen $current
        Add-Candidate $List $Seen (Join-Path $current 'Interface\AddOns')
        Add-Candidate $List $Seen (Join-Path $current 'Azeroth\Interface\AddOns')
        Add-Candidate $List $Seen (Join-Path $current 'live\Azeroth\Interface\AddOns')
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Find-AddOnsPaths {
    $result = New-Object 'System.Collections.Generic.List[string]'
    $seen = @{}
    Add-CandidatesFromHint $result $seen $InstallHint

    $known = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns'),
        (Join-Path $env:LOCALAPPDATA 'Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns'),
        (Join-Path $env:ProgramFiles 'Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns')
    )

    if (${env:ProgramFiles(x86)}) {
        $known += Join-Path ${env:ProgramFiles(x86)} 'Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns'
    }
    foreach ($candidate in $known) { Add-Candidate $result $seen $candidate }
    return $result
}

function Read-PayloadManifest {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Missing payload checksum manifest: $ManifestPath"
    }

    $entries = @()
    foreach ($line in Get-Content -LiteralPath $ManifestPath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([A-Fa-f0-9]{64})\s+\*(addon/pfQuest/.+)$') {
            throw "Invalid payload manifest line: $line"
        }
        $relative = $Matches[2].Substring('addon/pfQuest/'.Length).Replace('/', '\')
        if ([System.IO.Path]::IsPathRooted($relative) -or $relative.Split('\') -contains '..') {
            throw "Unsafe payload manifest path: $relative"
        }
        $entries += [pscustomobject]@{ Hash = $Matches[1].ToUpperInvariant(); Relative = $relative }
    }
    if ($entries.Count -lt 250) { throw "Payload manifest is unexpectedly small ($($entries.Count) files)." }
    return $entries
}

function Assert-Payload {
    param([string]$Root, [object[]]$Manifest, [string]$Label)
    $fullRoot = Get-NormalizedPath $Root
    if (-not (Test-Path -LiteralPath $fullRoot -PathType Container)) { throw "$Label is missing: $fullRoot" }

    $forbidden = Get-ChildItem -LiteralPath $fullRoot -Recurse -File | Where-Object {
        $_.Extension -in @('.exe', '.dll', '.com', '.scr', '.bat', '.cmd', '.ps1')
    }
    if ($forbidden) { throw "$Label contains executable content: $($forbidden[0].FullName)" }

    $actualFiles = @(Get-ChildItem -LiteralPath $fullRoot -Recurse -File)
    if ($actualFiles.Count -ne $Manifest.Count) {
        throw "$Label file count mismatch: expected $($Manifest.Count), found $($actualFiles.Count)."
    }

    foreach ($entry in $Manifest) {
        $file = Join-Path $fullRoot $entry.Relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "$Label is missing $($entry.Relative)." }
        $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actual -ne $entry.Hash) { throw "$Label hash mismatch: $($entry.Relative)." }
    }

    $tocPath = Join-Path $fullRoot 'pfQuest.toc'
    $toc = Get-Content -LiteralPath $tocPath -Raw
    if ($toc -notmatch [regex]::Escape("## Version: EV-$Version")) {
        throw "$Label has the wrong addon version. Expected EV-$Version."
    }

    [xml](Get-Content -LiteralPath (Join-Path $fullRoot 'init\addon.xml') -Raw) | Out-Null
    Write-InstallLog "$Label verified: $($Manifest.Count) files, SHA-256 manifest and version are valid." Green
}

function Remove-PrivateDirectory {
    param([string]$Path, [string]$ExpectedParent, [string]$RequiredPrefix)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $full = Get-NormalizedPath $Path
    $parent = Get-NormalizedPath ([System.IO.Path]::GetDirectoryName($full))
    $leaf = [System.IO.Path]::GetFileName($full)
    if ($parent -ine (Get-NormalizedPath $ExpectedParent) -or -not $leaf.StartsWith($RequiredPrefix)) {
        throw "Refusing unsafe cleanup path: $full"
    }
    Remove-Item -LiteralPath $full -Recurse -Force
}

try {
    Write-InstallLog "Questie Emberveil installer $Version" Cyan
    Write-InstallLog "No network access, telemetry, or remote downloads are used by this installer."

    $manifest = @(Read-PayloadManifest)
    Assert-Payload $SourceRoot $manifest 'Bundled source payload'

    if ($ValidateOnly) {
        Write-InstallLog "Validation-only mode completed successfully." Green
        exit 0
    }

    $candidates = @(Find-AddOnsPaths)
    if ($candidates.Count -eq 0 -and -not $NonInteractive) {
        Write-Host ''
        Write-Host 'Could not auto-detect Emberveil. Paste the AddOns folder or any parent Emberveil folder:' -ForegroundColor Yellow
        $manual = Read-Host 'Path'
        $InstallHint = $manual
        $candidates = @(Find-AddOnsPaths)
    }
    if ($candidates.Count -eq 0) { throw 'No valid Emberveil Interface\AddOns folder was found.' }

    $addOns = $candidates[0]
    if ($candidates.Count -gt 1 -and -not $NonInteractive) {
        Write-Host ''
        for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host "[$($i + 1)] $($candidates[$i])" }
        $selection = Read-Host 'Choose the Emberveil AddOns folder (default 1)'
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $candidates.Count) {
            $addOns = $candidates[[int]$selection - 1]
        }
    }
    if (-not (Test-AddOnsPath $addOns)) { throw "Unsafe or invalid AddOns target: $addOns" }

    $target = Get-NormalizedPath (Join-Path $addOns 'pfQuest')
    if ((Get-NormalizedPath ([System.IO.Path]::GetDirectoryName($target))) -ine (Get-NormalizedPath $addOns) -or
        [System.IO.Path]::GetFileName($target) -ine 'pfQuest') {
        throw "Refusing unexpected target path: $target"
    }
    if ($target -ieq $SourceRoot) { throw 'Source and installation target resolve to the same path.' }

    Write-InstallLog "Target: $target" Cyan
    $token = [guid]::NewGuid().ToString('N')
    $stageRoot = Join-Path $addOns ".qev-stage-$token"
    $stageTarget = Join-Path $stageRoot 'pfQuest'
    $rollback = Join-Path $addOns ".qev-rollback-$token"
    $installed = $false

    try {
        New-Item -ItemType Directory -Path $stageRoot | Out-Null
        Copy-Item -LiteralPath $SourceRoot -Destination $stageRoot -Recurse -Force
        Assert-Payload $stageTarget $manifest 'Staged payload'

        if (Test-Path -LiteralPath $target -PathType Container) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupParent = Join-Path $BackupRoot "$stamp-$token"
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $backupParent -Recurse -Force
            Write-InstallLog "Existing pfQuest backed up to: $backupParent" Yellow
            Move-Item -LiteralPath $target -Destination $rollback
        }

        try {
            Move-Item -LiteralPath $stageTarget -Destination $target
            Assert-Payload $target $manifest 'Installed payload'
            $installed = $true
        } catch {
            if (Test-Path -LiteralPath $target) {
                Remove-PrivateDirectory $target $addOns 'pfQuest'
            }
            if (Test-Path -LiteralPath $rollback) {
                Move-Item -LiteralPath $rollback -Destination $target
                Write-InstallLog 'Installation failed; the previous pfQuest folder was restored.' Yellow
            }
            throw
        }

        if (Test-Path -LiteralPath $rollback) {
            Remove-PrivateDirectory $rollback $addOns '.qev-rollback-'
        }
    } finally {
        if (Test-Path -LiteralPath $stageRoot) {
            Remove-PrivateDirectory $stageRoot $addOns '.qev-stage-'
        }
    }

    if (-not $installed) { throw 'Installation did not reach the verified state.' }
    Write-InstallLog "DONE: Questie Emberveil $Version installed and verified." Green
    Write-InstallLog 'Restart Emberveil completely, then enable pfQuest in the AddOns list.' Green
    Write-InstallLog "Log: $LogPath"
    exit 0
} catch {
    Write-InstallLog ("ERROR: " + $_.Exception.Message) Red
    Write-InstallLog "Nothing unverified was left installed. Log: $LogPath" Yellow
    exit 1
}
