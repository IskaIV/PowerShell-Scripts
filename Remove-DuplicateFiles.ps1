# Remove-DuplicateFiles.ps1
# Deletes duplicate files named "FileName (N).ext", keeping the original "FileName.ext"
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
# Examples matched:  invoice (1).docx  |  photo (23).png  |  report (2).pdf
$duplicatePattern = '^(.+) \(\d+\)(\.[^.]+)?$'

$deletedCount  = 0
$skippedCount  = 0
$notFoundCount = 0

Write-Host ""
Write-Host "Scanning: $FolderPath" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "*** WHATIF MODE — no files will actually be deleted ***" -ForegroundColor Yellow
}
Write-Host ""

# ── Walk every file recursively ───────────────────────────────────────────────
Get-ChildItem -LiteralPath $FolderPath -Recurse -File | ForEach-Object {
    $file = $_

    if ($file.BaseName -match $duplicatePattern) {
        $originalBase = $Matches[1]               # e.g. "invoice"
        $extension    = $file.Extension           # e.g. ".docx"
        $originalName = $originalBase + $extension
        $originalPath = Join-Path $file.DirectoryName $originalName

        if (Test-Path -LiteralPath $originalPath) {
            # Original exists — safe to delete the duplicate
            if ($WhatIf) {
                Write-Host "[WHATIF] Would delete: $($file.FullName)" -ForegroundColor DarkYellow
            } else {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force
                    Write-Host "Deleted : $($file.FullName)" -ForegroundColor Green
                    $deletedCount++
                } catch {
                    Write-Warning "Could not delete: $($file.FullName) — $_"
                }
            }
            $deletedCount++
        } else {
            # No original found — leave the duplicate alone
            Write-Host "Skipped : $($file.FullName)" -ForegroundColor DarkGray
            Write-Host "          (no matching original '$originalName' found in same folder)"
            $skippedCount++
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "─────────────────────────────────────" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "Would delete : $deletedCount file(s)" -ForegroundColor Yellow
} else {
    Write-Host "Deleted  : $deletedCount file(s)" -ForegroundColor Green
}
Write-Host "Skipped  : $skippedCount file(s) (original not found)" -ForegroundColor DarkGray
Write-Host "─────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""
