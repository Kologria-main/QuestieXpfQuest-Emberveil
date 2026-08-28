[CmdletBinding()]
param(
    [string]$Version = '2.0.0-beta1.21'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$addon = Join-Path $repo 'addon\KoQuest'
$dist = Join-Path $repo 'dist'
$packageName = "KoQuest_Emberveil_v$Version"
$launcherZipPath = Join-Path $dist "$packageName.zip"
$offlineZipPath = Join-Path $dist "${packageName}_Full_Offline_Package.zip"
$checksumPath = Join-Path $dist 'SHA256SUMS.txt'
$fixedTime = [DateTimeOffset]::Parse('2026-08-28T00:00:00Z')

& (Join-Path $PSScriptRoot 'update-payload-manifest.ps1')
& (Join-Path $PSScriptRoot 'validate-release.ps1') -SkipInstallerTests

New-Item -ItemType Directory -Path $dist -Force | Out-Null

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-DeterministicZip {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $archive = New-Object System.IO.Compression.ZipArchive(
            $stream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            foreach ($item in @($Items | Sort-Object Relative)) {
                $entry = $archive.CreateEntry($item.Relative, [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = $fixedTime
                $input = [System.IO.File]::OpenRead($item.Source)
                $output = $entry.Open()
                try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
}

function Assert-Zip {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Required,
        [Parameter(Mandatory = $true)][string]$Label,
        [switch]$LauncherArchive
    )

    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt 64MB) { throw "$Label exceeds Emberveil's 64 MiB ZIP limit." }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $seen = @{}
        $total = [int64]0
        $buffer = New-Object byte[] 65536
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name -match '(^|/)\.\.(/|$)') {
                throw "$Label contains unsafe ZIP entry: $name"
            }
            if ($entry.Length -gt 256MB) { throw "$Label entry exceeds 256 MiB: $name" }
            $total += $entry.Length
            if ($total -gt 512MB) { throw "$Label exceeds Emberveil's 512 MiB unpacked limit." }

            $key = $name.ToLowerInvariant()
            if ($seen.ContainsKey($key)) { throw "$Label contains duplicate ZIP entry: $name" }
            $seen[$key] = $true

            if ($LauncherArchive) {
                if (-not $name.StartsWith('KoQuest/')) {
                    throw "Launcher ZIP must contain only the KoQuest folder at its root: $name"
                }
                if ($name -match '(^|/)(WTF|SavedVariables|Cache|\.git)(/|$)') {
                    throw "Launcher ZIP contains forbidden client/repository data: $name"
                }
            }

            $entryStream = $entry.Open()
            try { while ($entryStream.Read($buffer, 0, $buffer.Length) -gt 0) {} }
            finally { $entryStream.Dispose() }
        }

        foreach ($requiredEntry in $Required) {
            if (-not $seen.ContainsKey($requiredEntry.ToLowerInvariant())) {
                throw "$Label is missing required entry: $requiredEntry"
            }
        }
    } finally { $archive.Dispose() }
}

$launcherItems = foreach ($file in Get-ChildItem -LiteralPath $addon -Recurse -File) {
    $relative = $file.FullName.Substring($addon.Length).TrimStart('\').Replace('\', '/')
    [pscustomobject]@{ Source = $file.FullName; Relative = "KoQuest/$relative" }
}
New-DeterministicZip -Path $launcherZipPath -Items @($launcherItems)
Assert-Zip -Path $launcherZipPath -Label 'Launcher ZIP' -LauncherArchive -Required @(
    'KoQuest/KoQuest.toc',
    'KoQuest/init/addon.xml',
    'KoQuest/compat/emberveil.lua'
)

$rootFiles = @(
    'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md',
    'RELEASE_NOTES.md', 'INSTALL_KOQUEST.cmd', 'INSTALL_KOQUEST_LINUX.sh',
    'INSTALL_QUESTIE_EMBERVEIL.cmd'
)
$trees = @('addon', 'installer', 'docs', 'assets')
$offlineItems = @()
foreach ($name in $rootFiles) {
    $source = Join-Path $repo $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing release file: $name" }
    $offlineItems += [pscustomobject]@{ Source = $source; Relative = "$packageName/$name" }
}
foreach ($tree in $trees) {
    $base = Join-Path $repo $tree
    foreach ($file in Get-ChildItem -LiteralPath $base -Recurse -File) {
        $relative = $file.FullName.Substring($repo.Length).TrimStart('\').Replace('\', '/')
        $offlineItems += [pscustomobject]@{ Source = $file.FullName; Relative = "$packageName/$relative" }
    }
}
New-DeterministicZip -Path $offlineZipPath -Items @($offlineItems)
Assert-Zip -Path $offlineZipPath -Label 'Offline ZIP' -Required @(
    "$packageName/README.md",
    "$packageName/INSTALL_KOQUEST.cmd",
    "$packageName/INSTALL_KOQUEST_LINUX.sh",
    "$packageName/installer/payload-manifest.sha256",
    "$packageName/addon/KoQuest/KoQuest.toc"
)

$hashLines = foreach ($path in @($launcherZipPath, $offlineZipPath)) {
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash *$([System.IO.Path]::GetFileName($path))"
}
[System.IO.File]::WriteAllText(
    $checksumPath,
    ($hashLines -join "`n") + "`n",
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host "PASS: built and fully read the launcher and offline release ZIPs." -ForegroundColor Green
Write-Host "Launcher: $launcherZipPath"
Write-Host "Offline:  $offlineZipPath"
Get-Content -LiteralPath $checksumPath | ForEach-Object { Write-Host "SHA256:  $_" }
