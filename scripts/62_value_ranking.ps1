#Requires -Version 5.1
<#
.SYNOPSIS
    Advanced repository value ranking system
.DESCRIPTION
    Scores repositories on multiple value dimensions to identify improvement priorities
#>

param()

$ErrorActionPreference = 'Stop'

$VaultRoot = Split-Path $PSScriptRoot -Parent
$ReportsDir = Join-Path $VaultRoot "reports"
$InventoryCSV = Join-Path $ReportsDir "inventory.csv"
$QualityCSV = Join-Path $ReportsDir "quality-audit.csv"
$ValueRankingFile = Join-Path $ReportsDir "value-ranking.md"

Write-Host "=== Repository Value Ranking ===" -ForegroundColor Cyan
Write-Host ""

# Load data
if (-not (Test-Path $InventoryCSV) -or -not (Test-Path $QualityCSV)) {
    Write-Error "Required data files not found. Run full analysis first."
}

$inventory = Import-Csv -Path $InventoryCSV
$quality = Import-Csv -Path $QualityCSV

# Merge data
$repos = @()
foreach ($inv in $inventory) {
    $qual = $quality | Where-Object { $_.Owner -eq $inv.Owner -and $_.Repo -eq $inv.Repo } | Select-Object -First 1

    if ($qual) {
        $repos += [PSCustomObject]@{
            Owner = $inv.Owner
            Repo = $inv.Repo
            AccountType = $inv.AccountType
            LOC = [int]$inv.LocTotal
            Commits = [int]$inv.CommitCount
            FirstCommit = $inv.FirstCommit
            LastCommit = $inv.LastCommit
            HasTests = $inv.HasTests
            HasCI = $inv.HasCI
            HasDocs = $inv.HasDocs
            ProofScore = [double]$inv.ProofScore
            ValueMid = [int]$inv.ValueMid
            QualityScore = [int]$qual.Score
            DaysSinceLastCommit = [int]$qual.DaysSinceLastCommit
        }
    }
}

Write-Host "Analyzing $($repos.Count) repositories..." -ForegroundColor Gray
Write-Host ""

# Value Scoring Function
function Get-ValueScore {
    param($Repo)

    $scores = @{}
    $maxScore = 100

    # 1. Technical Size/Complexity (0-20 points)
    # Larger, more complex repos have more value
    if ($Repo.LOC -gt 100000) { $scores.Size = 20 }
    elseif ($Repo.LOC -gt 50000) { $scores.Size = 17 }
    elseif ($Repo.LOC -gt 20000) { $scores.Size = 14 }
    elseif ($Repo.LOC -gt 10000) { $scores.Size = 11 }
    elseif ($Repo.LOC -gt 5000) { $scores.Size = 8 }
    elseif ($Repo.LOC -gt 1000) { $scores.Size = 5 }
    else { $scores.Size = 2 }

    # 2. Activity/Recency (0-25 points)
    # More recent = more relevant
    $daysSince = $Repo.DaysSinceLastCommit
    if ($daysSince -lt 30) { $scores.Recency = 25 }        # < 1 month
    elseif ($daysSince -lt 90) { $scores.Recency = 20 }    # < 3 months
    elseif ($daysSince -lt 180) { $scores.Recency = 15 }   # < 6 months
    elseif ($daysSince -lt 365) { $scores.Recency = 10 }   # < 1 year
    elseif ($daysSince -lt 730) { $scores.Recency = 5 }    # < 2 years
    else { $scores.Recency = 0 }

    # 3. Engineering Maturity (0-20 points)
    # Higher quality = more valuable
    $scores.Maturity = [math]::Round($Repo.QualityScore / 5, 0)  # 0-100 quality → 0-20 points

    # 4. Portfolio Showcase Potential (0-15 points)
    # Repos that demonstrate skills well
    $scores.Showcase = 0

    # Personal/Web repos are better for showcasing
    if ($Repo.Owner -like '*-Web' -or $Repo.Owner -eq 'GeorgeMcIntyre') {
        $scores.Showcase += 5
    }

    # High proof score indicates well-documented, mature project
    if ($Repo.ProofScore -gt 70) {
        $scores.Showcase += 5
    }

    # Good commit history shows sustained effort
    if ($Repo.Commits -gt 100) {
        $scores.Showcase += 5
    }

    # 5. Commercial Value (0-15 points)
    # Estimated revenue/client value
    $scores.Commercial = 0

    # Work repos likely have commercial value
    if ($Repo.AccountType -eq 'Work' -or $Repo.AccountType -eq 'Work-Org') {
        $scores.Commercial += 10
    }

    # Large repos with high estimated value
    if ($Repo.ValueMid -gt 1000000) {  # > R1M
        $scores.Commercial += 5
    }

    # 6. Improvement ROI (0-5 points)
    # Low quality but high potential = high ROI
    if ($Repo.QualityScore -lt 60 -and $Repo.LOC -gt 5000) {
        $scores.ROI = 5
    } elseif ($Repo.QualityScore -lt 60 -and $Repo.LOC -gt 1000) {
        $scores.ROI = 3
    } elseif ($Repo.QualityScore -lt 60) {
        $scores.ROI = 1
    } else {
        $scores.ROI = 0
    }

    $totalScore = ($scores.Values | Measure-Object -Sum).Sum

    return @{
        TotalScore = $totalScore
        Breakdown = $scores
        Category = Get-ValueCategory -Score $totalScore
    }
}

function Get-ValueCategory {
    param([int]$Score)

    if ($Score -ge 75) { return "Critical" }
    elseif ($Score -ge 60) { return "High" }
    elseif ($Score -ge 40) { return "Medium" }
    elseif ($Score -ge 20) { return "Low" }
    else { return "Archive" }
}

# Score all repositories
Write-Host "Calculating value scores..." -ForegroundColor Cyan

$rankedRepos = @()

foreach ($repo in $repos) {
    $valueResult = Get-ValueScore -Repo $repo

    $rankedRepos += [PSCustomObject]@{
        Owner = $repo.Owner
        Repo = $repo.Repo
        AccountType = $repo.AccountType
        ValueScore = $valueResult.TotalScore
        Category = $valueResult.Category
        LOC = $repo.LOC
        QualityScore = $repo.QualityScore
        DaysSinceLastCommit = $repo.DaysSinceLastCommit
        ValueMid = $repo.ValueMid
        # Score breakdown
        SizeScore = $valueResult.Breakdown.Size
        RecencyScore = $valueResult.Breakdown.Recency
        MaturityScore = $valueResult.Breakdown.Maturity
        ShowcaseScore = $valueResult.Breakdown.Showcase
        CommercialScore = $valueResult.Breakdown.Commercial
        ROIScore = $valueResult.Breakdown.ROI
    }
}

# Sort by value score
$rankedRepos = $rankedRepos | Sort-Object ValueScore -Descending

Write-Host "Value scoring complete!" -ForegroundColor Green
Write-Host ""

# Generate report
$report = @()
$report += "# Repository Value Ranking"
$report += ""
$report += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "**Purpose:** Identify highest-value repositories for improvement"
$report += ""

$report += "## Value Scoring Methodology"
$report += ""
$report += "Each repository is scored (0-100) across six dimensions:"
$report += ""
$report += "| Dimension | Weight | Description |"
$report += "|-----------|--------|-------------|"
$report += "| **Technical Size** | 0-20 | Larger, more complex repos score higher |"
$report += "| **Activity/Recency** | 0-25 | More recently active repos score higher |"
$report += "| **Engineering Maturity** | 0-20 | Higher quality scores contribute more |"
$report += "| **Showcase Potential** | 0-15 | Repos that demonstrate skills well |"
$report += "| **Commercial Value** | 0-15 | Revenue-generating or client work |"
$report += "| **Improvement ROI** | 0-5 | Low quality + high potential = high ROI |"
$report += ""
$report += "**Total Possible Score:** 100 points"
$report += ""

# Category distribution
$critical = ($rankedRepos | Where-Object { $_.Category -eq "Critical" }).Count
$high = ($rankedRepos | Where-Object { $_.Category -eq "High" }).Count
$medium = ($rankedRepos | Where-Object { $_.Category -eq "Medium" }).Count
$low = ($rankedRepos | Where-Object { $_.Category -eq "Low" }).Count
$archive = ($rankedRepos | Where-Object { $_.Category -eq "Archive" }).Count

$report += "## Value Distribution"
$report += ""
$report += "| Category | Count | Focus |"
$report += "|----------|-------|-------|"
$report += "| **Critical** (75-100) | $critical | Highest priority - improve immediately |"
$report += "| **High** (60-74) | $high | Strong candidates for improvement |"
$report += "| **Medium** (40-59) | $medium | Selective improvement |"
$report += "| **Low** (20-39) | $low | Maintenance mode |"
$report += "| **Archive** (<20) | $archive | Consider archiving |"
$report += ""

# Top 30 repositories
$report += "## Top 30 High-Value Repositories"
$report += ""
$report += "These repositories offer the best return on improvement investment:"
$report += ""
$report += "| Rank | Repository | Value | Quality | Category | Key Attributes |"
$report += "|------|------------|-------|---------|----------|----------------|"

$rank = 1
foreach ($repo in ($rankedRepos | Select-Object -First 30)) {
    $attributes = @()

    if ($repo.SizeScore -ge 15) { $attributes += "Large" }
    if ($repo.RecencyScore -ge 20) { $attributes += "Active" }
    if ($repo.MaturityScore -ge 15) { $attributes += "Mature" }
    if ($repo.ShowcaseScore -ge 10) { $attributes += "Showcase" }
    if ($repo.CommercialScore -ge 10) { $attributes += "Commercial" }
    if ($repo.ROIScore -ge 3) { $attributes += "High ROI" }

    $attrString = $attributes -join ", "
    if (-not $attrString) { $attrString = "Standard" }

    $report += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.ValueScore) | $($repo.QualityScore) | $($repo.Category) | $attrString |"
    $rank++
}

$report += ""

# Critical priority repos (need immediate attention)
$criticalRepos = $rankedRepos | Where-Object { $_.Category -eq "Critical" }

if ($criticalRepos.Count -gt 0) {
    $report += "## Critical Priority Repositories ($($criticalRepos.Count) repos)"
    $report += ""
    $report += "These repos have highest business value and should be improved first:"
    $report += ""
    $report += "| Repository | Value | Quality Gap | Why Critical? |"
    $report += "|------------|-------|-------------|---------------|"

    foreach ($repo in $criticalRepos) {
        $qualityGap = 100 - $repo.QualityScore
        $reasons = @()

        if ($repo.SizeScore -ge 15) { $reasons += "Large codebase ($($repo.LOC.ToString('N0')) LOC)" }
        if ($repo.RecencyScore -ge 20) {
            $daysAgo = [math]::Round($repo.DaysSinceLastCommit)
            $reasons += "Recently active ($daysAgo days ago)"
        }
        if ($repo.CommercialScore -ge 10) { $reasons += "Commercial/client value" }
        if ($repo.ROIScore -ge 3) { $reasons += "High improvement ROI" }

        $reasonString = $reasons -join "; "

        $report += "| $($repo.Owner)/$($repo.Repo) | $($repo.ValueScore) | -$qualityGap | $reasonString |"
    }

    $report += ""
}

# Recommended improvement order
$report += "## Recommended Improvement Priority"
$report += ""
$report += "Focus on these repos in order for maximum impact:"
$report += ""

# Critical repos with low quality (biggest quick wins)
$quickWins = $rankedRepos |
    Where-Object { $_.Category -in @("Critical", "High") -and $_.QualityScore -lt 60 } |
    Sort-Object @{Expression = {$_.ValueScore}; Descending = $true}, @{Expression = {$_.QualityScore}; Ascending = $true} |
    Select-Object -First 15

$report += "### Phase 1: Critical Quick Wins (15 repos)"
$report += ""
$report += "| Priority | Repository | Value | Current Quality | Improvement Needed |"
$report += "|----------|------------|-------|-----------------|---------------------|"

$priority = 1
foreach ($repo in $quickWins) {
    $improvements = @()
    if ($repo.QualityScore -lt 30) { $improvements += "README, Tests, CI/CD, Docs" }
    elseif ($repo.QualityScore -lt 50) { $improvements += "Tests, CI/CD, Docs" }
    elseif ($repo.QualityScore -lt 70) { $improvements += "CI/CD, Docs" }
    else { $improvements += "Polish" }

    $impString = $improvements -join ", "

    $report += "| $priority | $($repo.Owner)/$($repo.Repo) | $($repo.ValueScore) | $($repo.QualityScore) | $impString |"
    $priority++
}

$report += ""

# Archive candidates (low value, low quality)
$archiveCandidates = $rankedRepos |
    Where-Object { $_.Category -eq "Archive" -and $_.QualityScore -lt 30 } |
    Sort-Object ValueScore |
    Select-Object -First 20

if ($archiveCandidates.Count -gt 0) {
    $report += "## Archive Recommendations ($($archiveCandidates.Count) repos)"
    $report += ""
    $report += "Low value, low quality, consider archiving:"
    $report += ""
    $report += "| Repository | Value | Quality | Last Activity |"
    $report += "|------------|-------|---------|---------------|"

    foreach ($repo in ($archiveCandidates | Select-Object -First 15)) {
        $daysInactive = $repo.DaysSinceLastCommit
        $yearsInactive = [math]::Round($daysInactive / 365, 1)

        $activityString = if ($daysInactive -gt 365) {
            "$yearsInactive years ago"
        } else {
            "$daysInactive days ago"
        }

        $report += "| $($repo.Owner)/$($repo.Repo) | $($repo.ValueScore) | $($repo.QualityScore) | $activityString |"
    }

    $report += ""
}

# Save report
$report | Set-Content -Path $ValueRankingFile -Encoding UTF8

Write-Host "=== Value Ranking Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Value Distribution:" -ForegroundColor Cyan
Write-Host "  Critical: $critical repos" -ForegroundColor Red
Write-Host "  High: $high repos" -ForegroundColor Yellow
Write-Host "  Medium: $medium repos" -ForegroundColor Green
Write-Host "  Low: $low repos" -ForegroundColor Gray
Write-Host "  Archive: $archive repos" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Report saved: $ValueRankingFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Top 5 Priority Repos:" -ForegroundColor Cyan
foreach ($repo in ($quickWins | Select-Object -First 5)) {
    Write-Host "  $($repo.Owner)/$($repo.Repo) - Value: $($repo.ValueScore), Quality: $($repo.QualityScore)" -ForegroundColor Yellow
}
Write-Host ""

exit 0
