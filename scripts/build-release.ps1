[CmdletBinding()]
param(
    [string]$Version = '2.0.0-beta1.20'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$dist = Join-Path $repo 'dist'
$packageName = "KoQuest_Emberveil_v$Version"
$zipPath = Join-Path $dist "$packageName.zip"
$checksumPath = Join-Path $dist 'SHA256SUMS.txt'
$fixedTime = [DateTimeOffset]::Parse('2026-08-25T00:00:00Z')

& (Join-Path $PSScriptRoot 'update-payload-manifest.ps1')
& (Join-Path $PSScriptRoot 'validate-release.ps1') -SkipInstallerTests

New-Item -ItemType Directory -Path $dist -Force | Out-Null
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$rootFiles = @(
    'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md',
    'RELEASE_NOTES.md', 'INSTALL_KOQUEST.cmd', 'INSTALL_KOQUEST_LINUX.sh',
    'INSTALL_QUESTIE_EMBERVEIL.cmd'
)
$trees = @('addon', 'installer', 'docs', 'assets')
$items = @()
foreach ($name in $rootFiles) {
    $source = Join-Path $repo $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing release file: $name" }
    $items += [pscustomobject]@{ Source = $source; Relative = $name.Replace('\', '/') }
}
foreach ($tree in $trees) {
    $base = Join-Path $repo $tree
    foreach ($file in Get-ChildItem -LiteralPath $base -Recurse -File) {
        $relative = $file.FullName.Substring($repo.Length).TrimStart('\').Replace('\', '/')
        $items += [pscustomobject]@{ Source = $file.FullName; Relative = $relative }
    }
}
$items = @($items | Sort-Object Relative)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew)
try {
    $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($item in $items) {
            $entryName = "$packageName/$($item.Relative)"
            $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTime
            $input = [System.IO.File]::OpenRead($item.Source)
            $output = $entry.Open()
            try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $stream.Dispose() }

$readArchive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $seen = @{}
    $buffer = New-Object byte[] 65536
    foreach ($entry in $readArchive.Entries) {
        $name = $entry.FullName
        if ($name.StartsWith('/') -or $name -match '(^|/)\.\.(/|$)') { throw "Unsafe ZIP entry: $name" }
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { throw "Duplicate ZIP entry: $name" }
        $seen[$key] = $true
        $entryStream = $entry.Open()
        try { while ($entryStream.Read($buffer, 0, $buffer.Length) -gt 0) {} } finally { $entryStream.Dispose() }
    }

    foreach ($required in @(
        "$packageName/README.md",
        "$packageName/INSTALL_KOQUEST.cmd",
        "$packageName/INSTALL_KOQUEST_LINUX.sh",
        "$packageName/INSTALL_QUESTIE_EMBERVEIL.cmd",
        "$packageName/installer/payload-manifest.sha256",
        "$packageName/addon/pfQuest/pfQuest.toc"
    )) {
        if (-not $seen.ContainsKey($required.ToLowerInvariant())) { throw "ZIP missing required entry: $required" }
    }
} finally { $readArchive.Dispose() }

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText($checksumPath, "$hash *$([System.IO.Path]::GetFileName($zipPath))`n", (New-Object System.Text.UTF8Encoding($false)))

Write-Host "PASS: built and fully read $($items.Count)-file release ZIP." -ForegroundColor Green
Write-Host "ZIP: $zipPath"
Write-Host "SHA256: $hash"
