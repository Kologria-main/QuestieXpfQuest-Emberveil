[CmdletBinding()]
param(
    [string]$InstallHint,
    [switch]$NonInteractive,
    [switch]$ValidateOnly,
    [string]$StateRoot,
    [string]$SavedVariablesRoot,
    [switch]$SkipSavedVariablesRepair,
    [switch]$AllowBroadSavedVariablesScan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Version = '2.0.0-beta1.22'
$ReleaseRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$SourceRoot = [System.IO.Path]::GetFullPath((Join-Path $ReleaseRoot 'addon\KoQuest'))
$ManifestPath = Join-Path $PSScriptRoot 'payload-manifest.sha256'

if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path $env:LOCALAPPDATA 'QuestieEV'
}
$StateRoot = [System.IO.Path]::GetFullPath($StateRoot)
$LogRoot = Join-Path $StateRoot 'Logs'
$BackupRoot = Join-Path $StateRoot 'Backups'
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
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

function Get-UniqueExistingDirectory {
    param(
        [AllowEmptyCollection()][System.Collections.Generic.List[string]]$List,
        [AllowEmptyCollection()][hashtable]$Seen,
        [string]$Path
    )

    if ($null -eq $List -or $null -eq $Seen) {
        throw 'Internal SavedVariables scanner state was not initialized.'
    }
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            $full = Get-NormalizedPath $Path
            $key = $full.ToLowerInvariant()
            if (-not $Seen.ContainsKey($key)) {
                $Seen[$key] = $true
                $List.Add($full)
            }
        }
    } catch {}
}

function Get-SavedVariablesSearchRoots {
    param([Parameter(Mandatory = $true)][string]$AddOnsPath)

    $roots = New-Object 'System.Collections.Generic.List[string]'
    $seen = @{}

    # Tests, support sessions, and nonstandard installs can provide one exact
    # root. Never mix an explicit boundary with automatic profile-wide roots.
    if (-not [string]::IsNullOrWhiteSpace($SavedVariablesRoot)) {
        Get-UniqueExistingDirectory -List $roots -Seen $seen -Path $SavedVariablesRoot
        return $roots
    }

    # Walk the Emberveil install ancestry, but add only specifically named data
    # directories. Adding each ancestor itself could recursively scan a drive or
    # the user's whole profile when a custom installation is near its root.
    $current = Get-NormalizedPath $AddOnsPath
    for ($i = 0; $i -lt 10 -and $current; $i++) {
        Get-UniqueExistingDirectory -List $roots -Seen $seen -Path (Join-Path $current 'WTF')
        Get-UniqueExistingDirectory -List $roots -Seen $seen -Path (Join-Path $current 'Saved')
        Get-UniqueExistingDirectory -List $roots -Seen $seen -Path (Join-Path $current 'SavedVariables')

        $parent = [System.IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }

    # Confirmed Emberveil layout:
    # %LOCALAPPDATA%\Azeroth\Saved\Account\<ACCOUNT>\SavedVariables
    $candidates = @((Join-Path $env:LOCALAPPDATA 'Azeroth\Saved\Account'))

    # Broader profile discovery is support-only and requires an explicit switch.
    # It is intentionally never used by normal installation or release tests.
    if ($AllowBroadSavedVariablesScan) {
        $candidates += @(
            (Join-Path $env:LOCALAPPDATA 'Azeroth\Saved'),
            $env:APPDATA,
            (Join-Path $env:USERPROFILE 'Saved Games'),
            (Join-Path $env:USERPROFILE 'Documents')
        )
    }

    foreach ($candidate in $candidates) {
        Get-UniqueExistingDirectory -List $roots -Seen $seen -Path $candidate
    }

    return $roots
}

function Remove-TopLevelLuaAssignment {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Variable
    )

    # WoW SavedVariables are serialized as a sequence of column-zero top-level
    # assignments. We intentionally do NOT parse the malformed table. Instead
    # remove from the target assignment through the next top-level assignment.
    $startRegex = [regex]("(?m)^" + [regex]::Escape($Variable) + "[ `t]*=")
    $start = $startRegex.Match($Text)
    if (-not $start.Success) {
        return [pscustomobject]@{ Changed = $false; Text = $Text }
    }

    $nextRegex = [regex]'(?m)^[A-Za-z_][A-Za-z0-9_]*[ `t]*='
    $next = $nextRegex.Match($Text, $start.Index + $start.Length)
    $end = if ($next.Success) { $next.Index } else { $Text.Length }

    $cleaned = $Text.Remove($start.Index, $end - $start.Index)
    return [pscustomobject]@{ Changed = $true; Text = $cleaned }
}

function Test-PfQuestSavedVariableCandidate {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

    try {
        if ($File.Length -gt 16777216) { return $false }

        $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
        $encoding = [System.Text.Encoding]::GetEncoding(28591)
        $text = $encoding.GetString($bytes)

        return (
            $text -match '(?m)^pfQuest_config[ `t]*=' -or
            $text -match '(?m)^pfQuest_track[ `t]*=' -or
            $text -match '(?is)Interface.{0,80}AddOns.{0,80}pfQuest.{0,80}img.{0,80}tracking'
        )
    } catch {
        return $false
    }
}

function Find-PfQuestSavedVariableFiles {
    param([Parameter(Mandatory = $true)][string]$AddOnsPath)

    $roots = @(Get-SavedVariablesSearchRoots -AddOnsPath $AddOnsPath)
    $files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    $seenFiles = @{}
    $excludedBackupRoot = (Get-NormalizedPath $BackupRoot).ToLowerInvariant()

    Write-InstallLog ("SavedVariables search roots: " + $roots.Count) DarkGray

    foreach ($root in $roots) {
        Write-InstallLog ("  scanning: " + $root) DarkGray

        # Fast pass: exact pfQuest SavedVariables filenames.
        $named = @()
        try {
            $named = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -ieq 'pfQuest.lua' -or
                $_.Name -ieq 'pfQuest.lua.bak'
            })
        } catch {}

        foreach ($file in $named) {
            $full = Get-NormalizedPath $file.FullName
            if ($full.ToLowerInvariant().StartsWith($excludedBackupRoot)) { continue }
            $key = $full.ToLowerInvariant()
            if (-not $seenFiles.ContainsKey($key) -and (Test-PfQuestSavedVariableCandidate -File $file)) {
                $seenFiles[$key] = $true
                $files.Add($file)
            }
        }
    }

    if ($files.Count -gt 0) { return $files }

    # Fallback pass: some Unreal-era clients may store addon SavedVariables in
    # a differently named .lua file. Limit this content scan to directories
    # whose path strongly indicates persisted addon/user state.
    foreach ($root in $roots) {
        $luaFiles = @()
        try {
            $luaFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.lua' -ErrorAction SilentlyContinue | Where-Object {
                $_.FullName -match '(?i)SavedVariables|\\WTF\\|\\Saved\\|Azeroth|Emberveil'
            })
        } catch {}

        foreach ($file in $luaFiles) {
            $full = Get-NormalizedPath $file.FullName
            if ($full.ToLowerInvariant().StartsWith($excludedBackupRoot)) { continue }
            $key = $full.ToLowerInvariant()
            if (-not $seenFiles.ContainsKey($key) -and (Test-PfQuestSavedVariableCandidate -File $file)) {
                $seenFiles[$key] = $true
                $files.Add($file)
            }
        }
    }

    return $files
}

function Repair-PfQuestSavedVariables {
    param([Parameter(Mandatory = $true)][string]$AddOnsPath)

    $files = @(Find-PfQuestSavedVariableFiles -AddOnsPath $AddOnsPath)

    if ($files.Count -eq 0) {
        $exactFiles = @()
        foreach ($root in @(Get-SavedVariablesSearchRoots -AddOnsPath $AddOnsPath)) {
            try {
                $exactFiles += @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -ieq 'pfQuest.lua' -or $_.Name -ieq 'pfQuest.lua.bak'
                })
            } catch {}
        }
        if ($exactFiles.Count -gt 0) {
            Write-InstallLog "No unsafe beta1.15 tracking signature found in $($exactFiles.Count) legacy SavedVariables file(s)." Green
            return [pscustomobject]@{
                Found = $exactFiles.Count
                Repaired = 0
                Quarantined = 0
                Diagnostic = $null
            }
        }

        Write-InstallLog 'WARNING: No pfQuest SavedVariables file was found to inspect.' Yellow
        Write-InstallLog 'If this machine previously crashed with the beta1.15 tracking-path LUA PANIC, recovery was NOT performed.' Yellow
        Write-InstallLog 'A diagnostic file will be written so the SavedVariables location can be identified.' Yellow

        $diag = Join-Path $LogRoot ("savedvars-search-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
        $roots = @(Get-SavedVariablesSearchRoots -AddOnsPath $AddOnsPath)
        @(
            'KoQuest SavedVariables search diagnostic'
            ('Time: ' + (Get-Date).ToString('s'))
            ('AddOns: ' + $AddOnsPath)
            ''
            'Search roots:'
        ) | Set-Content -LiteralPath $diag -Encoding UTF8
        $roots | Add-Content -LiteralPath $diag -Encoding UTF8

        Write-InstallLog ("SavedVariables diagnostic: " + $diag) Cyan
        return [pscustomobject]@{
            Found = 0
            Repaired = 0
            Quarantined = 0
            Diagnostic = $diag
        }
    }

    $byteEncoding = [System.Text.Encoding]::GetEncoding(28591)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $BackupRoot ("SavedVariables-{0}-{1}" -f $stamp, ([guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null

    $repaired = 0
    $quarantined = 0
    $index = 0

    foreach ($file in $files) {
        $index++
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $text = $byteEncoding.GetString($bytes)

        $hasTrackAssignment = $text -match '(?m)^pfQuest_track[ `t]*='
        $hasUnsafeTrackingPath = $text -match '(?is)Interface.{0,80}AddOns.{0,80}pfQuest.{0,80}img.{0,80}tracking'

        Write-InstallLog ("Found pfQuest SavedVariables: " + $file.FullName) Cyan

        $backupFile = Join-Path $backup ("{0:D3}-{1}" -f $index, $file.Name)
        Copy-Item -LiteralPath $file.FullName -Destination $backupFile -Force
        Add-Content -LiteralPath (Join-Path $backup 'SOURCE_PATHS.txt') `
            -Value ("{0}`t{1}" -f [System.IO.Path]::GetFileName($backupFile), $file.FullName) -Encoding UTF8

        if ($hasTrackAssignment) {
            $result = Remove-TopLevelLuaAssignment -Text $text -Variable 'pfQuest_track'
            if ($result.Changed) {
                [System.IO.File]::WriteAllBytes($file.FullName, $byteEncoding.GetBytes($result.Text))
                $repaired++
                Write-InstallLog ("Repaired pfQuest_track in: " + $file.FullName) Green
                continue
            }
        }

        if ($hasUnsafeTrackingPath) {
            # We found the exact beta1.15 crash signature but cannot isolate the
            # assignment. Preserve the original backup and remove this persisted
            # file so Emberveil can start and regenerate safe state.
            Remove-Item -LiteralPath $file.FullName -Force
            $quarantined++
            Write-InstallLog ("Quarantined malformed pfQuest SavedVariables: " + $file.FullName) Yellow
        } else {
            Write-InstallLog ("No unsafe pfQuest_track state found in: " + $file.FullName) DarkGray
        }
    }

    Write-InstallLog ("SavedVariables backup: " + $backup) Cyan
    Write-InstallLog ("SavedVariables recovery: found=$($files.Count) repaired=$repaired quarantined=$quarantined") Green

    return [pscustomobject]@{
        Found = $files.Count
        Repaired = $repaired
        Quarantined = $quarantined
        Diagnostic = $null
    }
}

function Test-LegacyKoQuestFolder {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    foreach ($tocName in @('pfQuest.toc', 'KoQuest.toc')) {
        $tocPath = Join-Path $Path $tocName
        if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) { continue }
        try {
            $toc = Get-Content -LiteralPath $tocPath -Raw
            if ($toc -match '(?im)^## Title:.*KoQuest' -and $toc -match '(?im)^## Version:\s*EV-') {
                return $true
            }
        } catch {}
    }
    return $false
}

function Migrate-LegacyKoQuestSavedVariables {
    param([Parameter(Mandatory = $true)][string]$AddOnsPath)

    # Once the installed folder metadata has proved this is legacy KoQuest,
    # migrate every exact pfQuest.lua file inside the already-scoped roots.
    # Some account-wide files contain only history/cache tables and therefore
    # do not match the older crash-repair signature filter.
    $files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    $seenFiles = @{}
    $excludedBackupRoot = (Get-NormalizedPath $BackupRoot).ToLowerInvariant()
    foreach ($root in @(Get-SavedVariablesSearchRoots -AddOnsPath $AddOnsPath)) {
        $named = @()
        try {
            $named = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -ieq 'pfQuest.lua' -and $_.Length -le 16777216
            })
        } catch {}
        foreach ($file in $named) {
            $full = Get-NormalizedPath $file.FullName
            if ($full.ToLowerInvariant().StartsWith($excludedBackupRoot)) { continue }
            $key = $full.ToLowerInvariant()
            if (-not $seenFiles.ContainsKey($key)) {
                $seenFiles[$key] = $true
                $files.Add($file)
            }
        }
    }

    if ($files.Count -eq 0) {
        Write-InstallLog 'No legacy KoQuest SavedVariables were found to migrate.' DarkGray
        return 0
    }

    $replacements = @(
        @('pfQuest_confirmedAvailable', 'KoQuest_confirmedAvailable'),
        @('pfQuest_questcache', 'KoQuest_questcache'),
        @('pfQuest_config', 'KoQuest_config'),
        @('pfBrowser_fav', 'KoBrowser_fav'),
        @('pfQuest_history', 'KoQuest_history'),
        @('pfQuest_colors', 'KoQuest_colors'),
        @('pfQuest_server', 'KoQuest_server'),
        @('pfQuest_track', 'KoQuest_track'),
        @('Interface\\AddOns\\pfQuest', 'Interface\\AddOns\\KoQuest')
    )
    $byteEncoding = [System.Text.Encoding]::GetEncoding(28591)
    $migrated = 0

    foreach ($file in $files) {
        $target = Join-Path $file.DirectoryName 'KoQuest.lua'
        if (Test-Path -LiteralPath $target) {
            Write-InstallLog "Kept existing KoQuest SavedVariables: $target" Yellow
            continue
        }

        $text = $byteEncoding.GetString([System.IO.File]::ReadAllBytes($file.FullName))
        foreach ($pair in $replacements) { $text = $text.Replace($pair[0], $pair[1]) }
        [System.IO.File]::WriteAllBytes($target, $byteEncoding.GetBytes($text))
        $migrated++
        Write-InstallLog "Migrated legacy KoQuest SavedVariables to: $target" Green
    }

    return $migrated
}

function Read-PayloadManifest {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Missing payload checksum manifest: $ManifestPath"
    }

    $entries = @()
    foreach ($line in Get-Content -LiteralPath $ManifestPath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([A-Fa-f0-9]{64})\s+\*(addon/KoQuest/.+)$') {
            throw "Invalid payload manifest line: $line"
        }
        $relative = $Matches[2].Substring('addon/KoQuest/'.Length).Replace('/', '\')
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

    $tocPath = Join-Path $fullRoot 'KoQuest.toc'
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
    Write-InstallLog "KoQuest installer $Version" Cyan
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

    $target = Get-NormalizedPath (Join-Path $addOns 'KoQuest')
    if ((Get-NormalizedPath ([System.IO.Path]::GetDirectoryName($target))) -ine (Get-NormalizedPath $addOns) -or
        [System.IO.Path]::GetFileName($target) -ine 'KoQuest') {
        throw "Refusing unexpected target path: $target"
    }
    if ($target -ieq $SourceRoot) { throw 'Source and installation target resolve to the same path.' }

    $legacy = Get-NormalizedPath (Join-Path $addOns 'pfQuest')
    $legacyKoQuest = Test-LegacyKoQuestFolder -Path $legacy

    Write-InstallLog "Target: $target" Cyan
    if ($SkipSavedVariablesRepair) {
        Write-InstallLog 'SavedVariables recovery skipped by explicit request.' Yellow
    } else {
        Write-InstallLog 'Checking pfQuest SavedVariables for the beta1.15 tracking-path serialization crash...' Cyan
        $savedVarRecovery = Repair-PfQuestSavedVariables -AddOnsPath $addOns
        if ($savedVarRecovery.Found -eq 0) {
            Write-InstallLog 'NOTE: Addon installation will continue, but no legacy SavedVariables file was located.' Yellow
        }
    }
    if ($legacyKoQuest) {
        Write-InstallLog 'Recognized a beta1.20-or-older KoQuest installation in the legacy pfQuest folder.' Yellow
        $migratedSavedVariables = Migrate-LegacyKoQuestSavedVariables -AddOnsPath $addOns
        Write-InstallLog "Legacy KoQuest SavedVariables migrated: $migratedSavedVariables file(s)." Cyan
    }

    $token = [guid]::NewGuid().ToString('N')
    $stageRoot = Join-Path $addOns ".qev-stage-$token"
    $stageTarget = Join-Path $stageRoot 'KoQuest'
    $rollback = Join-Path $addOns ".qev-rollback-$token"
    $legacyRollback = Join-Path $addOns ".koquest-legacy-$token"
    $installed = $false
    $legacyMoved = $false

    try {
        New-Item -ItemType Directory -Path $stageRoot | Out-Null
        Copy-Item -LiteralPath $SourceRoot -Destination $stageRoot -Recurse -Force
        Assert-Payload $stageTarget $manifest 'Staged payload'

        $hasCurrent = Test-Path -LiteralPath $target -PathType Container
        if ($hasCurrent -or $legacyKoQuest) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupParent = Join-Path $BackupRoot "$stamp-$token"
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        }

        if ($hasCurrent) {
            Copy-Item -LiteralPath $target -Destination $backupParent -Recurse -Force
            Write-InstallLog "Existing KoQuest backed up to: $backupParent" Yellow
            Move-Item -LiteralPath $target -Destination $rollback
        }

        if ($legacyKoQuest) {
            Copy-Item -LiteralPath $legacy -Destination (Join-Path $backupParent 'pfQuest-legacy-KoQuest') -Recurse -Force
            Move-Item -LiteralPath $legacy -Destination $legacyRollback
            $legacyMoved = $true
            Write-InstallLog "Legacy KoQuest pfQuest folder backed up to: $backupParent" Yellow
        }

        try {
            Move-Item -LiteralPath $stageTarget -Destination $target
            Assert-Payload $target $manifest 'Installed payload'
            $installed = $true
        } catch {
            if (Test-Path -LiteralPath $target) {
                Remove-PrivateDirectory $target $addOns 'KoQuest'
            }
            if (Test-Path -LiteralPath $rollback) {
                Move-Item -LiteralPath $rollback -Destination $target
                Write-InstallLog 'Installation failed; the previous KoQuest folder was restored.' Yellow
            }
            if ($legacyMoved -and (Test-Path -LiteralPath $legacyRollback) -and -not (Test-Path -LiteralPath $legacy)) {
                Move-Item -LiteralPath $legacyRollback -Destination $legacy
                Write-InstallLog 'Installation failed; the legacy KoQuest pfQuest folder was restored.' Yellow
            }
            throw
        }

        if (Test-Path -LiteralPath $rollback) {
            Remove-PrivateDirectory $rollback $addOns '.qev-rollback-'
        }
        if (Test-Path -LiteralPath $legacyRollback) {
            Remove-PrivateDirectory $legacyRollback $addOns '.koquest-legacy-'
        }
    } catch {
        # Cover failures during backup/migration as well as payload placement.
        # The inner catch handles the common install failure; these guards are
        # idempotent when that recovery has already completed.
        if (Test-Path -LiteralPath $rollback) {
            if (Test-Path -LiteralPath $target) {
                Remove-PrivateDirectory $target $addOns 'KoQuest'
            }
            Move-Item -LiteralPath $rollback -Destination $target
            Write-InstallLog 'Recovered the previous KoQuest folder after an installer error.' Yellow
        }
        if ($legacyMoved -and (Test-Path -LiteralPath $legacyRollback) -and -not (Test-Path -LiteralPath $legacy)) {
            Move-Item -LiteralPath $legacyRollback -Destination $legacy
            Write-InstallLog 'Recovered the legacy KoQuest pfQuest folder after an installer error.' Yellow
        }
        throw
    } finally {
        if (Test-Path -LiteralPath $stageRoot) {
            Remove-PrivateDirectory $stageRoot $addOns '.qev-stage-'
        }
    }

    if (-not $installed) { throw 'Installation did not reach the verified state.' }
    Write-InstallLog "DONE: KoQuest $Version installed and verified." Green
    Write-InstallLog 'Restart Emberveil completely, then enable KoQuest in the AddOns list.' Green
    Write-InstallLog "Log: $LogPath"
    exit 0
} catch {
    Write-InstallLog ("ERROR: " + $_.Exception.Message) Red
    Write-InstallLog "Nothing unverified was left installed. Log: $LogPath" Yellow
    exit 1
}
