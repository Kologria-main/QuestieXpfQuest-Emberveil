[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$addon = Join-Path $repo 'addon\KoQuest'
$manifest = Join-Path $repo 'installer\payload-manifest.sha256'

if (-not (Test-Path -LiteralPath $addon -PathType Container)) { throw "Missing addon source: $addon" }

$lines = foreach ($file in Get-ChildItem -LiteralPath $addon -Recurse -File | Sort-Object FullName) {
    $relative = $file.FullName.Substring($addon.Length).TrimStart('\').Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash *addon/KoQuest/$relative"
}

if ($lines.Count -lt 250) { throw "Refusing to write unexpectedly small manifest ($($lines.Count) files)." }
$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($manifest, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote $($lines.Count) payload hashes to $manifest" -ForegroundColor Green
