# Builds a CurseForge-ready zip: releases\Courier-<version>.zip
# The zip contains a single "Courier" folder with only the files the game needs.
# Usage (from the project folder):  powershell -ExecutionPolicy Bypass -File .\build.ps1

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$addon = 'Courier'

# Files that ship in the addon (everything else in the repo stays out of the zip)
$files = @('Courier.toc', 'Data.lua', 'Contacts.lua', 'LICENSE')

# Read the version from the .toc
$versionLine = Select-String -Path (Join-Path $root 'Courier.toc') -Pattern '^## Version:\s*(.+)$'
if (-not $versionLine) { throw 'No "## Version:" line found in Courier.toc' }
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$releases = Join-Path $root 'releases'
$zipPath = Join-Path $releases "$addon-$version.zip"
New-Item -ItemType Directory -Force -Path $releases | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Write entries with forward slashes ("Courier/Data.lua"); Compress-Archive on
# Windows PowerShell uses backslashes, which some unzip tools mis-extract.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($f in $files) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, (Join-Path $root $f), "$addon/$f", 'Optimal') | Out-Null
    }
}
finally {
    $zip.Dispose()
}
Write-Host "Built $zipPath"
