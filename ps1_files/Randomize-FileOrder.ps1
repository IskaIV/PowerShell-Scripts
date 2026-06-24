<#
.SYNOPSIS
    Randomizes the playback order of files in a folder by renaming them with random numeric prefixes.

.DESCRIPTION
    Renames all files in the target folder by prepending a zero-padded random number,
    so that sorting by name produces a shuffled order. Existing numeric prefixes
    (added by a previous run of this script) are stripped before renaming.

.PARAMETER FolderPath
    Path to the folder containing the files to shuffle.
    Defaults to the current directory if not specified.

.PARAMETER Filter
    Optional file extension filter (e.g. "*.mp3", "*.mp4").
    Defaults to all files ("*.*").

.PARAMETER Prefix
    A short label inserted between the random number and the original filename.
    Defaults to no prefix label.

.EXAMPLE
    .\Randomize-FileOrder.ps1 -FolderPath "C:\Music\Playlist"

.EXAMPLE
    .\Randomize-FileOrder.ps1 -FolderPath "C:\Videos" -Filter "*.mp4"

.EXAMPLE
    .\Randomize-FileOrder.ps1 -FolderPath "C:\Music" -Filter "*.mp3" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Position = 0)]
    [string]$FolderPath = (Get-Location).Path,

    [Parameter()]
    [string]$Filter = "*.*"
)

# ── Validate folder ────────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
    Write-Error "Folder not found: $FolderPath"
    exit 1
}

$FolderPath = (Resolve-Path -LiteralPath $FolderPath).Path

# ── Collect files ──────────────────────────────────────────────────────────────
$files = Get-ChildItem -LiteralPath $FolderPath -Filter $Filter -File

if ($files.Count -eq 0) {
    Write-Warning "No files matching '$Filter' found in: $FolderPath"
    exit 0
}

Write-Host "Found $($files.Count) file(s) in: $FolderPath" -ForegroundColor Cyan

# ── Strip any existing numeric prefix added by this script ─────────────────────
# Matches an optional leading number block like "0042 - " or "0042_"
$prefixPattern = '^\d+[\s_-]+\s*'

# ── Build a shuffled list of zero-padded numbers ───────────────────────────────
$padWidth  = $files.Count.ToString().Length   # e.g. 3 digits for up to 999 files
$numbers   = 1..$files.Count | Sort-Object { Get-Random }  # Fisher-Yates via Sort-Object

# ── Rename files ───────────────────────────────────────────────────────────────
$errors  = 0
$renamed = 0

foreach ($pair in [System.Linq.Enumerable]::Zip(
        [object[]]$files,
        [object[]]$numbers,
        [Func[object,object,object]]{ param($f,$n) @{ File=$f; Number=$n } }
    )) {

    $file      = $pair.File
    $number    = $pair.Number
    $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $ext       = $file.Extension

    # Strip previous prefix if present
    $cleanName = $baseName -replace $prefixPattern, ''

    $newName = "{0:D$padWidth} - {1}{2}" -f $number, $cleanName, $ext
    $newPath = Join-Path $FolderPath $newName

    if ($file.FullName -eq $newPath) {
        Write-Verbose "Skipped (unchanged): $($file.Name)"
        continue
    }

    try {
        if ($PSCmdlet.ShouldProcess($file.Name, "Rename to '$newName'")) {
            Rename-Item -LiteralPath $file.FullName -NewName $newName -ErrorAction Stop
            Write-Verbose "Renamed: $($file.Name)  →  $newName"
            $renamed++
        }
    }
    catch {
        Write-Warning "Failed to rename '$($file.Name)': $_"
        $errors++
    }
}

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
if ($PSBoundParameters.ContainsKey('WhatIf')) {
    Write-Host "WhatIf mode — no files were actually renamed." -ForegroundColor Yellow
} else {
    Write-Host "Done. $renamed file(s) renamed." -ForegroundColor Green
    if ($errors -gt 0) {
        Write-Host "$errors file(s) could not be renamed (see warnings above)." -ForegroundColor Red
    }
}