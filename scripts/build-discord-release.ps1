[CmdletBinding()]
param(
    [string]$Version = '2.0.0-beta1.21',
    [long]$MaxBytes = 20000000,
    [string]$SevenZipPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$dist = [System.IO.Path]::GetFullPath((Join-Path $repo 'dist'))
$work = [System.IO.Path]::GetFullPath((Join-Path $repo 'work'))
$packageName = "KoQuest_Emberveil_v$Version"
$sourceZip = Join-Path $dist "$packageName.zip"
$archiveName = "${packageName}_Discord.7z"
$archivePath = Join-Path $dist $archiveName
$checksumPath = "$archivePath.sha256"

if ($MaxBytes -le 0) { throw 'MaxBytes must be positive.' }

if ([string]::IsNullOrWhiteSpace($SevenZipPath)) {
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles '7-Zip\7z.exe'
    }
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $candidates += Join-Path $programFilesX86 '7-Zip\7z.exe'
    }
    $command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    $SevenZipPath = $candidates | Where-Object {
        Test-Path -LiteralPath $_ -PathType Leaf
    } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($SevenZipPath) -or
    -not (Test-Path -LiteralPath $SevenZipPath -PathType Leaf)) {
    throw '7-Zip is required to build the compact Discord archive. Install 7-Zip or pass -SevenZipPath.'
}
$SevenZipPath = [System.IO.Path]::GetFullPath($SevenZipPath)

function Invoke-SevenZip {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Action
    )

    & $SevenZipPath @Arguments | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip $Action failed with exit code $LASTEXITCODE."
    }
}

& (Join-Path $PSScriptRoot 'build-release.ps1') -Version $Version
if (-not (Test-Path -LiteralPath $sourceZip -PathType Leaf)) {
    throw "Standard release ZIP was not created: $sourceZip"
}

New-Item -ItemType Directory -Path $work -Force | Out-Null
$stageRoot = Join-Path $work ('.qev-discord-' + [guid]::NewGuid().ToString('N'))
$stageRoot = [System.IO.Path]::GetFullPath($stageRoot)
$expectedWorkPrefix = $work.TrimEnd('\') + '\'
if (-not $stageRoot.StartsWith($expectedWorkPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe Discord staging path: $stageRoot"
}

try {
    New-Item -ItemType Directory -Path $stageRoot | Out-Null
    Invoke-SevenZip -Action 'source extraction' -Arguments @(
        'x', $sourceZip, "-o$stageRoot", '-y'
    )

    $stagedPackage = Join-Path $stageRoot $packageName
    if (-not (Test-Path -LiteralPath $stagedPackage -PathType Container)) {
        throw "Extracted release root is missing: $stagedPackage"
    }

    $temporaryArchive = Join-Path $stageRoot $archiveName
    Invoke-SevenZip -Action 'archive creation' -Arguments @(
        'a', '-t7z', $temporaryArchive, $stagedPackage,
        '-xr!assets',
        '-mx=9', '-m0=lzma2:d=64m', '-ms=on', '-mmt=1',
        '-mtm=off', '-mta=off', '-mtr=off'
    )
    Invoke-SevenZip -Action 'archive integrity test' -Arguments @('t', $temporaryArchive)

    $listing = @(& $SevenZipPath 'l' '-ba' $temporaryArchive)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the Discord archive.' }
    $listingText = $listing -join "`n"
    if ($listingText -match '[\\/]assets[\\/]') {
        throw 'Discord archive unexpectedly contains repository-only assets.'
    }
    foreach ($required in @(
        "$packageName\INSTALL_KOQUEST.cmd",
        "$packageName\INSTALL_KOQUEST_LINUX.sh",
        "$packageName\installer\Install-Questie-Emberveil.ps1",
        "$packageName\installer\payload-manifest.sha256",
        "$packageName\addon\pfQuest\pfQuest.toc",
        "$packageName\addon\pfQuest_Locale_deDE\pfQuest_Locale_deDE.toc",
        "$packageName\addon\pfQuest_Locale_esES\pfQuest_Locale_esES.toc",
        "$packageName\addon\pfQuest_Locale_frFR\pfQuest_Locale_frFR.toc",
        "$packageName\addon\pfQuest_Locale_koKR\pfQuest_Locale_koKR.toc",
        "$packageName\addon\pfQuest_Locale_ptBR\pfQuest_Locale_ptBR.toc",
        "$packageName\addon\pfQuest_Locale_ruRU\pfQuest_Locale_ruRU.toc",
        "$packageName\addon\pfQuest_Locale_zhCN\pfQuest_Locale_zhCN.toc",
        "$packageName\addon\pfQuest_Locale_zhTW\pfQuest_Locale_zhTW.toc"
    )) {
        if ($listingText.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Discord archive is missing required entry: $required"
        }
    }

    $archive = Get-Item -LiteralPath $temporaryArchive
    if ($archive.Length -ge $MaxBytes) {
        throw "Discord archive is $($archive.Length) bytes; it must stay below $MaxBytes bytes."
    }

    $validationRoot = Join-Path $stageRoot 'validation'
    New-Item -ItemType Directory -Path $validationRoot | Out-Null
    Invoke-SevenZip -Action 'validation extraction' -Arguments @(
        'x', $temporaryArchive, "-o$validationRoot", '-y'
    )
    $validationInstaller = Join-Path $validationRoot "$packageName\installer\Install-Questie-Emberveil.ps1"
    $powerShellHost = (Get-Process -Id $PID).Path
    & $powerShellHost -NoProfile -File $validationInstaller -ValidateOnly
    if ($LASTEXITCODE -ne 0) {
        throw "Compact installer validation failed with exit code $LASTEXITCODE."
    }

    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    $resolvedArchivePath = [System.IO.Path]::GetFullPath($archivePath)
    $expectedDistPrefix = $dist.TrimEnd('\') + '\'
    if (-not $resolvedArchivePath.StartsWith($expectedDistPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe Discord output path: $resolvedArchivePath"
    }
    if (Test-Path -LiteralPath $resolvedArchivePath) {
        Remove-Item -LiteralPath $resolvedArchivePath -Force
    }
    Move-Item -LiteralPath $temporaryArchive -Destination $resolvedArchivePath

    $hash = (Get-FileHash -LiteralPath $resolvedArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText(
        $checksumPath,
        "$hash *$archiveName`n",
        (New-Object System.Text.UTF8Encoding($false))
    )

    $final = Get-Item -LiteralPath $resolvedArchivePath
    Write-Host "PASS: compact installer contains the complete 302-file addon payload and is below the Discord limit." -ForegroundColor Green
    Write-Host "ARCHIVE: $resolvedArchivePath"
    Write-Host "SIZE: $($final.Length) bytes ($([math]::Round($final.Length / 1MB, 2)) MiB)"
    Write-Host "SHA256: $hash"
} finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = [System.IO.Path]::GetFullPath($stageRoot)
        if (-not $resolvedStage.StartsWith($expectedWorkPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing unsafe Discord staging cleanup: $resolvedStage"
        }
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
