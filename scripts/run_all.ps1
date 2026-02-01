#Requires -Version 5.1
<#
.SYNOPSIS
    Run complete Repo Vault workflow
.DESCRIPTION
    Executes all steps: setup, auth, sync, and analysis
#>

param()

$ErrorActionPreference = 'Stop'
$ScriptsDir = $PSScriptRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GitHub Repository Vault - Full Run  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Step 1: Setup
Write-Host "[1/6] Running setup..." -ForegroundColor Yellow
& (Join-Path $ScriptsDir "00_setup.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Setup failed with exit code $LASTEXITCODE"
}
Write-Host ""

# Step 2: Auth
Write-Host "[2/6] Verifying authentication..." -ForegroundColor Yellow
& (Join-Path $ScriptsDir "10_auth.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Auth check returned non-zero exit code, but continuing..."
}
Write-Host ""

# Step 3: Sync
Write-Host "[3/6] Syncing repositories..." -ForegroundColor Yellow
& (Join-Path $ScriptsDir "20_sync.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Sync failed with exit code $LASTEXITCODE"
}
Write-Host ""

# Step 4: Analyze
Write-Host "[4/6] Analyzing repositories..." -ForegroundColor Yellow
& (Join-Path $ScriptsDir "30_analyze.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Analysis failed with exit code $LASTEXITCODE"
}
Write-Host ""

# Step 5: Archive Snapshot
Write-Host "[5/6] Archiving snapshot..." -ForegroundColor Yellow
& (Join-Path $ScriptsDir "archive_snapshot.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Snapshot archiving failed, but continuing..."
}
Write-Host ""

# Step 6: Compare & Generate Trends
Write-Host "[6/6] Generating trend analysis..." -ForegroundColor Yellow
& (Join-Path $ScriptsDir "40_compare_snapshots.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Trend comparison skipped (need 2+ snapshots)"
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "          All Tasks Complete!          " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "Reports generated:" -ForegroundColor Cyan
Write-Host "  Current Reports: F:\VaultRepo\vault\reports\" -ForegroundColor Gray
Write-Host "  Trend Analysis:  F:\VaultRepo\vault\history\trends\" -ForegroundColor Gray
Write-Host "  Snapshots:       F:\VaultRepo\vault\history\snapshots\" -ForegroundColor Gray
Write-Host ""

exit 0
