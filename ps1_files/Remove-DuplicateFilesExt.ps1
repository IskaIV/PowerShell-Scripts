# Remove-DuplicateFiles.ps1
#
# Deletes duplicate files named "FileName (N).ext", keeping the original "FileName.ext"
#
# Resolution order:
#   1. If an unnumbered original exists ANYWHERE in the tree  → delete all numbered copies
#   2. If no original exists, but numbered copies exist ANYWHERE in the tree
#      → keep the lowest-numbered one, delete the rest
#
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

# ── Pass 1: Catalog every file in the tree ───────────────────────────────────
#
# $originals : "BaseName|Extension" → list of full paths (unnumbered files)
# $numbered  : "BaseName|Extension" → list of { Number, FullPath }

$originals = @{}
$numbered  = @{}

Get-ChildItem -LiteralPath $FolderPath -Recurse -File | ForEach-Object {
    $file = $_

    if ($file.BaseName -match $duplicatePattern) {
        # ── Numbered duplicate ────────────────────────────────────────────
        $baseName  = $Matches[1]
        $number    = [int]$Matches[2]
        $extension = $file.Extension
        $key       = "$baseName|$extension"

        if (-not $numbered.ContainsKey($key)) { $numbered[$key] = @() }
        $numbered[$key] += [PSCustomObject]@{
            Number   = $number
            FullPath = $file.FullName
        }
    } else {
        # ── Potential original (unnumbered) ───────────────────────────────
        $key = "$($file.BaseName)|$($file.Extension)"

        if (-not $originals.ContainsKey($key)) { $originals[$key] = @() }
        $originals[$key] += $file.FullName
    }
}

# ── Pass 2: Resolve and delete ───────────────────────────────────────────────
foreach ($key in $numbered.Keys) {
    $parts     = $key -split '\|'
    $baseName  = $parts[0]
    $extension = $parts[1]
    $entries   = $numbered[$key] | Sort-Object Number

    if ($originals.ContainsKey($key)) {
        # ── Case 1: An unnumbered original exists somewhere in the tree ───
        $originalLocations = $originals[$key] -join ", "
        Write-Host "Original found for '$($baseName + $extension)':" -ForegroundColor Cyan
        Write-Host "  Location(s): $originalLocations"
        Write-Host "  Deleting all $($entries.Count) numbered duplicate(s)..."

        foreach ($entry in $entries) {
            if ($WhatIf) {
                Write-Host "  [WHATIF] Would delete: $($entry.FullPath)" -ForegroundColor DarkYellow
            } else {
                try {
                    Remove-Item -LiteralPath $entry.FullPath -Force
                    Write-Host "  Deleted : $($entry.FullPath)" -ForegroundColor Green
                    $deletedCount++
                } catch {
                    Write-Warning "  Could not delete: $($entry.FullPath) — $_"
                }
            }
            $wouldDeleteCount++
        }

    } else {
        # ── Case 2: No original anywhere — keep lowest number, delete rest
        $keep     = $entries[0]
        $toDelete = $entries | Select-Object -Skip 1

        if ($toDelete.Count -eq 0) {
            Write-Host "Only copy : $($keep.FullPath) — nothing to delete" -ForegroundColor DarkGray
            $skippedCount++
            continue
        }

        Write-Host "No original found for '$($baseName + $extension)' anywhere in tree" -ForegroundColor Cyan
        Write-Host "  Keeping lowest copy : $($keep.FullPath)"
        Write-Host "  Deleting $($toDelete.Count) higher-numbered duplicate(s)..."

        foreach ($entry in $toDelete) {
            if ($WhatIf) {
                Write-Host "  [WHATIF] Would delete: $($entry.FullPath)" -ForegroundColor DarkYellow
            } else {
                try {
                    Remove-Item -LiteralPath $entry.FullPath -Force
                    Write-Host "  Deleted : $($entry.FullPath)" -ForegroundColor Green
                    $deletedCount++
                } catch {
                    Write-Warning "  Could not delete: $($entry.FullPath) — $_"
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
