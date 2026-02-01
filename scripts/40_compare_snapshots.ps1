#Requires -Version 5.1
<#
.SYNOPSIS
    Compare repository snapshots and generate trend reports
.DESCRIPTION
    Analyzes historical snapshots to track portfolio changes over time
#>

param(
    [string]$BaselineDate = "",
    [string]$CurrentDate = ""
)

$ErrorActionPreference = 'Stop'
$VaultRoot = Split-Path $PSScriptRoot -Parent
$SnapshotsDir = Join-Path $VaultRoot "history\snapshots"
$TrendsDir = Join-Path $VaultRoot "history\trends"

Write-Host "=== Snapshot Comparison & Trend Analysis ===" -ForegroundColor Cyan
Write-Host ""

# Ensure trends directory exists
if (-not (Test-Path $TrendsDir)) {
    New-Item -ItemType Directory -Path $TrendsDir -Force | Out-Null
}

# Get available snapshots
$snapshots = Get-ChildItem -Path $SnapshotsDir -Directory | Sort-Object Name

if ($snapshots.Count -eq 0) {
    Write-Host "No snapshots found. Run the vault at least once to create snapshots." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($snapshots.Count) snapshot(s)" -ForegroundColor Gray

# Determine which snapshots to compare
if ($snapshots.Count -eq 1) {
    Write-Host "Only one snapshot available. Need at least 2 for comparison." -ForegroundColor Yellow
    Write-Host "Current baseline: $($snapshots[0].Name)" -ForegroundColor Gray
    exit 0
}

# Select snapshots to compare
if ($BaselineDate -and $CurrentDate) {
    $baselineSnapshot = $snapshots | Where-Object { $_.Name -eq $BaselineDate } | Select-Object -First 1
    $currentSnapshot = $snapshots | Where-Object { $_.Name -eq $CurrentDate } | Select-Object -First 1
} else {
    # Compare most recent two
    $currentSnapshot = $snapshots | Select-Object -Last 1
    $baselineSnapshot = $snapshots | Select-Object -Skip ($snapshots.Count - 2) | Select-Object -First 1
}

if (-not $baselineSnapshot -or -not $currentSnapshot) {
    Write-Error "Could not find specified snapshots"
}

Write-Host "Comparing:" -ForegroundColor Cyan
Write-Host "  Baseline: $($baselineSnapshot.Name)" -ForegroundColor Gray
Write-Host "  Current:  $($currentSnapshot.Name)" -ForegroundColor Gray
Write-Host ""

# Helper function to parse inventory CSV
function Get-InventoryData {
    param([string]$SnapshotPath)

    $csvPath = Join-Path $SnapshotPath "inventory.csv"
    if (-not (Test-Path $csvPath)) {
        return $null
    }

    try {
        $data = Import-Csv -Path $csvPath
        return $data
    } catch {
        Write-Warning "Could not parse CSV: $csvPath"
        return $null
    }
}

# Helper function to parse value estimate
function Get-ValueData {
    param([string]$SnapshotPath)

    $mdPath = Join-Path $SnapshotPath "value-estimate.md"
    if (-not (Test-Path $mdPath)) {
        return $null
    }

    $content = Get-Content -Path $mdPath -Raw

    $values = @{
        Low = 0
        Mid = 0
        High = 0
    }

    # Parse values from markdown table
    if ($content -match '\|\s*Low\s*\|\s*R\s*([\d\s]+)\s*\|') {
        $values.Low = [int]($matches[1] -replace '\s', '')
    }
    if ($content -match '\|\s*Mid\s*\|\s*R\s*([\d\s]+)\s*\|') {
        $values.Mid = [int]($matches[1] -replace '\s', '')
    }
    if ($content -match '\|\s*High\s*\|\s*R\s*([\d\s]+)\s*\|') {
        $values.High = [int]($matches[1] -replace '\s', '')
    }

    return $values
}

# Load data from both snapshots
$baselineData = Get-InventoryData -SnapshotPath $baselineSnapshot.FullName
$currentData = Get-InventoryData -SnapshotPath $currentSnapshot.FullName
$baselineValues = Get-ValueData -SnapshotPath $baselineSnapshot.FullName
$currentValues = Get-ValueData -SnapshotPath $currentSnapshot.FullName

if (-not $baselineData -or -not $currentData) {
    Write-Error "Could not load inventory data from snapshots"
}

# Calculate changes
$baselineCount = $baselineData.Count
$currentCount = $currentData.Count
$repoChange = $currentCount - $baselineCount

$baselineLOC = ($baselineData | Measure-Object -Property LocTotal -Sum).Sum
$currentLOC = ($currentData | Measure-Object -Property LocTotal -Sum).Sum
$locChange = $currentLOC - $baselineLOC

$baselineCommits = ($baselineData | Measure-Object -Property CommitCount -Sum).Sum
$currentCommits = ($currentData | Measure-Object -Property CommitCount -Sum).Sum
$commitChange = $currentCommits - $baselineCommits

$valueMidChange = $currentValues.Mid - $baselineValues.Mid
$valueMidChangePercent = if ($baselineValues.Mid -gt 0) { ($valueMidChange / $baselineValues.Mid) * 100 } else { 0 }

# Generate trend report
$trendReport = @()
$trendReport += "# Portfolio Trend Report"
$trendReport += ""
$trendReport += "**Period:** $($baselineSnapshot.Name) → $($currentSnapshot.Name)"
$trendReport += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$trendReport += ""

$trendReport += "## Summary of Changes"
$trendReport += ""

# Repository count
$repoChangeText = if ($repoChange -gt 0) { "+$repoChange" } elseif ($repoChange -lt 0) { "$repoChange" } else { "0" }
$trendReport += "### Repositories"
$trendReport += "- **Baseline:** $baselineCount"
$trendReport += "- **Current:** $currentCount"
$trendReport += "- **Change:** $repoChangeText"
$trendReport += ""

# LOC
$locChangeText = if ($locChange -gt 0) { "+$locChange" } elseif ($locChange -lt 0) { "$locChange" } else { "0" }
$trendReport += "### Lines of Code"
$trendReport += "- **Baseline:** $($baselineLOC.ToString('N0'))"
$trendReport += "- **Current:** $($currentLOC.ToString('N0'))"
$trendReport += "- **Change:** $locChangeText"
$trendReport += ""

# Commits
$commitChangeText = if ($commitChange -gt 0) { "+$commitChange" } elseif ($commitChange -lt 0) { "$commitChange" } else { "0" }
$trendReport += "### Total Commits"
$trendReport += "- **Baseline:** $($baselineCommits.ToString('N0'))"
$trendReport += "- **Current:** $($currentCommits.ToString('N0'))"
$trendReport += "- **Change:** $commitChangeText"
$trendReport += ""

# Portfolio value
$valueChangeText = if ($valueMidChange -gt 0) { "+R $($valueMidChange.ToString('N0'))" } elseif ($valueMidChange -lt 0) { "-R $([Math]::Abs($valueMidChange).ToString('N0'))" } else { "R 0" }
$trendReport += "### Portfolio Value (Mid-tier)"
$trendReport += "- **Baseline:** R $($baselineValues.Mid.ToString('N0'))"
$trendReport += "- **Current:** R $($currentValues.Mid.ToString('N0'))"
$trendReport += "- **Change:** $valueChangeText ($([Math]::Round($valueMidChangePercent, 2))%)"
$trendReport += ""

# New repositories
$baselineRepos = $baselineData | Select-Object -ExpandProperty Repo
$currentRepos = $currentData | Select-Object -ExpandProperty Repo
$newRepos = $currentRepos | Where-Object { $_ -notin $baselineRepos }

if ($newRepos.Count -gt 0) {
    $trendReport += "### New Repositories ($($newRepos.Count))"
    $trendReport += ""
    foreach ($repo in $newRepos) {
        $repoData = $currentData | Where-Object { $_.Repo -eq $repo } | Select-Object -First 1
        $trendReport += "- **$($repoData.Owner)/$($repoData.Repo)** - $($repoData.LocTotal) LOC, $($repoData.CommitCount) commits"
    }
    $trendReport += ""
}

# Top gainers (by LOC)
$trendReport += "### Top Repositories by Activity Change"
$trendReport += ""
$trendReport += "Repositories with most new lines of code:"
$trendReport += ""

$locGains = @()
foreach ($repo in $currentData) {
    $baselineRepo = $baselineData | Where-Object { $_.Repo -eq $repo.Repo -and $_.Owner -eq $repo.Owner } | Select-Object -First 1
    if ($baselineRepo) {
        $locDiff = [int]$repo.LocTotal - [int]$baselineRepo.LocTotal
        if ($locDiff -gt 0) {
            $locGains += [PSCustomObject]@{
                Owner = $repo.Owner
                Repo = $repo.Repo
                LOCChange = $locDiff
            }
        }
    }
}

$topGainers = $locGains | Sort-Object LOCChange -Descending | Select-Object -First 10
foreach ($gainer in $topGainers) {
    $trendReport += "- **$($gainer.Owner)/$($gainer.Repo)** - +$($gainer.LOCChange.ToString('N0')) LOC"
}
$trendReport += ""

# Overall assessment
$trendReport += "## Overall Assessment"
$trendReport += ""

if ($repoChange -gt 0 -or $locChange -gt 0 -or $commitChange -gt 0) {
    $trendReport += "**Status:** Portfolio Growing"
    $trendReport += ""
    $trendReport += "The portfolio shows positive growth with:"
    if ($repoChange -gt 0) {
        $trendReport += "- $repoChange new repository(ies)"
    }
    if ($locChange -gt 0) {
        $trendReport += "- $($locChange.ToString('N0')) new lines of code"
    }
    if ($commitChange -gt 0) {
        $trendReport += "- $commitChange new commits"
    }
} else {
    $trendReport += "**Status:** Portfolio Stable"
    $trendReport += ""
    $trendReport += "No significant changes detected in this period."
}
$trendReport += ""

# Save report
$reportDate = Get-Date -Format "yyyy-MM-dd"
$reportPath = Join-Path $TrendsDir "trend-$reportDate.md"
$trendReport | Set-Content -Path $reportPath -Encoding UTF8

Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Changes Detected:" -ForegroundColor Cyan
Write-Host "  Repositories: $repoChangeText" -ForegroundColor $(if ($repoChange -gt 0) { 'Green' } elseif ($repoChange -lt 0) { 'Yellow' } else { 'Gray' })
Write-Host "  LOC: $locChangeText" -ForegroundColor $(if ($locChange -gt 0) { 'Green' } elseif ($locChange -lt 0) { 'Yellow' } else { 'Gray' })
Write-Host "  Commits: $commitChangeText" -ForegroundColor $(if ($commitChange -gt 0) { 'Green' } elseif ($commitChange -lt 0) { 'Yellow' } else { 'Gray' })
Write-Host "  Value: $valueChangeText" -ForegroundColor $(if ($valueMidChange -gt 0) { 'Green' } elseif ($valueMidChange -lt 0) { 'Yellow' } else { 'Gray' })
Write-Host ""
Write-Host "Trend report saved: $reportPath" -ForegroundColor Green
Write-Host ""

exit 0
