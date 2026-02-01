#Requires -Version 5.1
<#
.SYNOPSIS
    Manage historical snapshots
.DESCRIPTION
    List, clean up, and manage snapshot archives
.PARAMETER Action
    Action to perform: list, cleanup, stats
.PARAMETER KeepDays
    Number of days of snapshots to keep (default: 90)
#>

param(
    [ValidateSet('list', 'cleanup', 'stats')]
    [string]$Action = 'list',

    [int]$KeepDays = 90
)

$ErrorActionPreference = 'Stop'
$VaultRoot = Split-Path $PSScriptRoot -Parent
$SnapshotsDir = Join-Path $VaultRoot "history\snapshots"

if (-not (Test-Path $SnapshotsDir)) {
    Write-Host "No snapshots directory found." -ForegroundColor Yellow
    exit 0
}

$snapshots = Get-ChildItem -Path $SnapshotsDir -Directory | Sort-Object Name

if ($snapshots.Count -eq 0) {
    Write-Host "No snapshots found." -ForegroundColor Yellow
    exit 0
}

switch ($Action) {
    'list' {
        Write-Host "=== Snapshot Archive ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Total snapshots: $($snapshots.Count)" -ForegroundColor Gray
        Write-Host ""

        foreach ($snapshot in $snapshots) {
            $files = Get-ChildItem -Path $snapshot.FullName -File
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1KB
            $age = (Get-Date) - [DateTime]::ParseExact($snapshot.Name, 'yyyy-MM-dd', $null)

            Write-Host "  $($snapshot.Name)" -NoNewline
            Write-Host " ($($files.Count) files, $([math]::Round($totalSize, 1)) KB, $([int]$age.TotalDays) days old)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    'cleanup' {
        Write-Host "=== Snapshot Cleanup ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Keeping last $KeepDays days of snapshots..." -ForegroundColor Gray
        Write-Host ""

        $cutoffDate = (Get-Date).AddDays(-$KeepDays)
        $toDelete = @()

        foreach ($snapshot in $snapshots) {
            $snapshotDate = [DateTime]::ParseExact($snapshot.Name, 'yyyy-MM-dd', $null)
            if ($snapshotDate -lt $cutoffDate) {
                $toDelete += $snapshot
            }
        }

        if ($toDelete.Count -eq 0) {
            Write-Host "No old snapshots to delete." -ForegroundColor Green
        } else {
            Write-Host "Found $($toDelete.Count) snapshot(s) to delete:" -ForegroundColor Yellow
            Write-Host ""

            foreach ($snapshot in $toDelete) {
                Write-Host "  - $($snapshot.Name)" -ForegroundColor Gray
            }

            Write-Host ""
            $confirm = Read-Host "Delete these snapshots? (y/N)"

            if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                foreach ($snapshot in $toDelete) {
                    Remove-Item -Path $snapshot.FullName -Recurse -Force
                    Write-Host "  Deleted: $($snapshot.Name)" -ForegroundColor Green
                }
                Write-Host ""
                Write-Host "Cleanup complete!" -ForegroundColor Green
            } else {
                Write-Host "Cleanup cancelled." -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }

    'stats' {
        Write-Host "=== Snapshot Statistics ===" -ForegroundColor Cyan
        Write-Host ""

        $totalFiles = 0
        $totalSize = 0
        $oldestSnapshot = $snapshots | Select-Object -First 1
        $newestSnapshot = $snapshots | Select-Object -Last 1

        foreach ($snapshot in $snapshots) {
            $files = Get-ChildItem -Path $snapshot.FullName -File
            $totalFiles += $files.Count
            $totalSize += ($files | Measure-Object -Property Length -Sum).Sum
        }

        $avgSizePerSnapshot = if ($snapshots.Count -gt 0) { $totalSize / $snapshots.Count / 1KB } else { 0 }

        Write-Host "Total snapshots: $($snapshots.Count)" -ForegroundColor Gray
        Write-Host "Oldest snapshot: $($oldestSnapshot.Name)" -ForegroundColor Gray
        Write-Host "Newest snapshot: $($newestSnapshot.Name)" -ForegroundColor Gray
        Write-Host "Total files: $totalFiles" -ForegroundColor Gray
        Write-Host "Total size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Gray
        Write-Host "Average size per snapshot: $([math]::Round($avgSizePerSnapshot, 2)) KB" -ForegroundColor Gray
        Write-Host ""

        if ($snapshots.Count -ge 2) {
            $oldestDate = [DateTime]::ParseExact($oldestSnapshot.Name, 'yyyy-MM-dd', $null)
            $newestDate = [DateTime]::ParseExact($newestSnapshot.Name, 'yyyy-MM-dd', $null)
            $span = $newestDate - $oldestDate

            Write-Host "Tracking period: $([int]$span.TotalDays) days" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

exit 0
