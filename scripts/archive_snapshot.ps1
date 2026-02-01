#Requires -Version 5.1
<#
.SYNOPSIS
    Archive current reports as a snapshot
.DESCRIPTION
    Creates a timestamped snapshot of all current reports
#>

param()

$ErrorActionPreference = 'Stop'
$VaultRoot = Split-Path $PSScriptRoot -Parent
$ReportsDir = Join-Path $VaultRoot "reports"
$HistoryDir = Join-Path $VaultRoot "history\snapshots"

$date = Get-Date -Format "yyyy-MM-dd"
$snapshotDir = Join-Path $HistoryDir $date

Write-Host "Creating snapshot for $date..." -ForegroundColor Cyan

# Create snapshot directory
if (-not (Test-Path $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
}

# Copy all reports
$reportFiles = Get-ChildItem -Path $ReportsDir -File | Where-Object { $_.Extension -in @('.md', '.csv', '.log', '.txt') }

Write-Host "Archiving $($reportFiles.Count) files..." -ForegroundColor Gray

foreach ($file in $reportFiles) {
    Copy-Item $file.FullName -Destination $snapshotDir -Force
    Write-Host "  + $($file.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Snapshot created: $snapshotDir" -ForegroundColor Green
Write-Host "Files archived: $($reportFiles.Count)" -ForegroundColor Gray
Write-Host ""

# Show snapshot summary
$totalSize = ($reportFiles | Measure-Object -Property Length -Sum).Sum / 1KB
$roundedSize = [math]::Round($totalSize, 2)
Write-Host "Total size: $roundedSize KB" -ForegroundColor Gray

exit 0
