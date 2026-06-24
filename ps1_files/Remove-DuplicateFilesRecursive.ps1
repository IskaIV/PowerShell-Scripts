# Remove-DuplicateFiles.ps1
# Deletes duplicate files named "FileName (N).ext", keeping the original "FileName.ext"
# If no original exists, keeps the lowest-numbered duplicate and deletes the rest.
# Recurses through all subfolders.

param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [switch]$WhatIf
)

# ── Validate folder ──────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
    Write-Error "Folder not found: $FolderPath"
    exit 1
}

# ── Regex: matches " (N)" suffix before the extension ────────────────────────
$duplicatePattern = '^(.+) \((\d+)\)(\.[^.]+)?$'

$deletedCount = 0
$wouldDeleteCount = 0
$skippedCount = 0

Write-Host ""
Write-Host "Scanning: $FolderPath" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "*** WHATIF MODE — no files will actually be deleted ***" -ForegroundColor Yellow
}
Write-Host ""

# ── Collect all duplicate files, grouped by folder + base name ───────────────
# Key: "FolderPath|BaseName|Extension"  →  Value: list of (Number, FileInfo)

$groups = @{}

Get-ChildItem -LiteralPath $FolderPath -Recurse -File | ForEach-Object {
    if ($_.BaseName -match $duplicatePattern) {
        $baseName  = $Matches[1]          # e.g. "invoice"
        $number    = [int]$Matches[2]     # e.g. 1
        $extension = $_.Extension         # e.g. ".docx"
        $key       = "$($_.DirectoryName)|$baseName|$extension"

        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @()
        }
        $groups[$key] += [PSCustomObject]@{
            Number = $number
            File   = $_
        }
    }
}

# ── Process each group ────────────────────────────────────────────────────────
foreach ($key in $groups.Keys) {
    $parts      = $key -split '\|'
    $folderName = $parts[0]
    $baseName   = $parts[1]
    $extension  = $parts[2]
    $originalPath = Join-Path $folderName ($baseName + $extension)

    $entries = $groups[$key] | Sort-Object Number

    if (Test-Path -LiteralPath $originalPath) {
        # ── Original exists → delete ALL numbered duplicates ──────────────
        Write-Host "Original found: $($baseName + $extension)" -ForegroundColor Cyan

        foreach ($entry in $entries) {
            if ($WhatIf) {
                Write-Host "  [WHATIF] Would delete: $($entry.File.FullName)" -ForegroundColor DarkYellow
            } else {
                try {
                    Remove-Item -LiteralPath $entry.File.FullName -Force
                    Write-Host "  Deleted : $($entry.File.FullName)" -ForegroundColor Green
                    $deletedCount++
                } catch {
                    Write-Warning "  Could not delete: $($entry.File.FullName) — $_"
                }
            }
            $wouldDeleteCount++
        }
    } else {
        # ── No original → keep lowest number, delete the rest ────────────
        $keep     = $entries[0]
        $toDelete = $entries | Select-Object -Skip 1

        if ($toDelete.Count -eq 0) {
            # Only one numbered file and no original — nothing to do
            Write-Host "Only copy : $($keep.File.FullName) — nothing to delete" -ForegroundColor DarkGray
            $skippedCount++
            continue
        }

        Write-Host "No original for '$($baseName + $extension)' — keeping lowest: $($keep.File.Name)" -ForegroundColor Cyan

        foreach ($entry in $toDelete) {
            if ($WhatIf) {
                Write-Host "  [WHATIF] Would delete: $($entry.File.FullName)" -ForegroundColor DarkYellow
            } else {
                try {
                    Remove-Item -LiteralPath $entry.File.FullName -Force
                    Write-Host "  Deleted : $($entry.File.FullName)" -ForegroundColor Green
                    $deletedCount++
                } catch {
                    Write-Warning "  Could not delete: $($entry.File.FullName) — $_"
                }
            }
            $wouldDeleteCount++
        }
    }

    Write-Host ""
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "─────────────────────────────────────" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "Would delete : $wouldDeleteCount file(s)" -ForegroundColor Yellow
} else {
    Write-Host "Deleted  : $deletedCount file(s)" -ForegroundColor Green
}
Write-Host "Skipped  : $skippedCount file(s) (sole copy, no action needed)" -ForegroundColor DarkGray
Write-Host "─────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""
