#Requires -Version 5.1
<#
.SYNOPSIS
    Generate enhanced portfolio reports
.DESCRIPTION
    Generates comprehensive strategic portfolio intelligence reports
#>

param(
    [Parameter(Mandatory=$true)]
    [array]$AllMetrics,

    [Parameter(Mandatory=$true)]
    [string]$ReportsDir
)

$RateMid = 750

# ============================================================================
# PORTFOLIO SUMMARY REPORT
# ============================================================================

Write-Host "Generating: portfolio-summary.md" -ForegroundColor Cyan

$summaryLines = @()
$summaryLines += "# Portfolio Strategic Summary"
$summaryLines += ""
$summaryLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summaryLines += ""
$summaryLines += "## Executive Overview"
$summaryLines += ""

# Classification breakdown
$prodCount = ($AllMetrics | Where-Object { $_.Classification -eq 'Production' }).Count
$toolCount = ($AllMetrics | Where-Object { $_.Classification -eq 'Tooling' }).Count
$rdCount = ($AllMetrics | Where-Object { $_.Classification -eq 'R&D' }).Count

$summaryLines += "### Portfolio Composition"
$summaryLines += ""
$summaryLines += "| Classification | Count | Percentage |"
$summaryLines += "|---------------|-------|------------|"
$summaryLines += "| Production/Mature Tools | $prodCount | $([Math]::Round($prodCount / $AllMetrics.Count * 100, 1))% |"
$summaryLines += "| Internal Tooling/Helpers | $toolCount | $([Math]::Round($toolCount / $AllMetrics.Count * 100, 1))% |"
$summaryLines += "| R&D/Idea Seeds | $rdCount | $([Math]::Round($rdCount / $AllMetrics.Count * 100, 1))% |"
$summaryLines += "| **Total** | $($AllMetrics.Count) | 100% |"
$summaryLines += ""

# Value breakdown
$totalRC = ($AllMetrics | Measure-Object -Property ReplacementCostMid -Sum).Sum
$totalOV = ($AllMetrics | Measure-Object -Property OptionValueMid -Sum).Sum
$totalTSV = ($AllMetrics | Measure-Object -Property TsvValue -Sum).Sum
$totalValue = ($AllMetrics | Measure-Object -Property TotalValueMid -Sum).Sum

$summaryLines += "### Portfolio Value (ZAR)"
$summaryLines += ""
$summaryLines += "| Component | Value | Percentage |"
$summaryLines += "|-----------|-------|------------|"
$summaryLines += "| Replacement Cost (RC) | R $($totalRC.ToString('N0')) | $([Math]::Round($totalRC / $totalValue * 100, 1))% |"
$summaryLines += "| Option Value (OV) | R $($totalOV.ToString('N0')) | $([Math]::Round($totalOV / $totalValue * 100, 1))% |"
$summaryLines += "| Time-Saved Value (TSV) | R $($totalTSV.ToString('N0')) | $([Math]::Round($totalTSV / $totalValue * 100, 1))% |"
$summaryLines += "| **Total Portfolio Value** | **R $($totalValue.ToString('N0'))** | 100% |"
$summaryLines += ""

# Theme analysis
$themeCount = @{}
foreach ($repo in $AllMetrics) {
    foreach ($theme in $repo.Themes) {
        if (-not $themeCount.ContainsKey($theme)) {
            $themeCount[$theme] = 0
        }
        $themeCount[$theme]++
    }
}

$summaryLines += "### Theme Distribution"
$summaryLines += ""
$summaryLines += "| Theme | Repositories |"
$summaryLines += "|-------|--------------|"
foreach ($theme in ($themeCount.Keys | Sort-Object { $themeCount[$_] } -Descending)) {
    $summaryLines += "| $theme | $($themeCount[$theme]) |"
}
$summaryLines += ""

# Top performers by 7D score
$summaryLines += "### Top 10 by Strategic Score"
$summaryLines += ""
$summaryLines += "| Rank | Repo | Classification | 7D Score | Total Value |"
$summaryLines += "|------|------|----------------|----------|-------------|"
$topByScore = $AllMetrics | Sort-Object SevenDimTotal -Descending | Select-Object -First 10
$rank = 1
foreach ($repo in $topByScore) {
    $summaryLines += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.Classification) | $($repo.SevenDimTotal) | R $($repo.TotalValueMid.ToString('N0')) |"
    $rank++
}
$summaryLines += ""

# Key insights
$summaryLines += "## Key Insights"
$summaryLines += ""

$avgProdValue = if ($prodCount -gt 0) {
    [Math]::Round((($AllMetrics | Where-Object { $_.Classification -eq 'Production' } | Measure-Object -Property TotalValueMid -Average).Average), 0)
} else { 0 }

$avgToolValue = if ($toolCount -gt 0) {
    [Math]::Round((($AllMetrics | Where-Object { $_.Classification -eq 'Tooling' } | Measure-Object -Property TotalValueMid -Average).Average), 0)
} else { 0 }

$avgRdValue = if ($rdCount -gt 0) {
    [Math]::Round((($AllMetrics | Where-Object { $_.Classification -eq 'R&D' } | Measure-Object -Property TotalValueMid -Average).Average), 0)
} else { 0 }

$summaryLines += "1. **Production Assets**: $prodCount repositories with average value of R $($avgProdValue.ToString('N0')) each"
$summaryLines += "2. **Tooling Ecosystem**: $toolCount internal tools streamlining workflows"
$summaryLines += "3. **Innovation Pipeline**: $rdCount R&D projects with average value of R $($avgRdValue.ToString('N0')) each"

$topTheme = ($themeCount.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Name
$summaryLines += "4. **Primary Domain**: $topTheme theme dominates with $($themeCount[$topTheme]) repositories"

$totalHoursSaved = ($AllMetrics | Measure-Object -Property HoursSaved -Sum).Sum
$summaryLines += "5. **Time Saved**: Estimated $([Math]::Round($totalHoursSaved, 0).ToString('N0')) hours of automation value"
$summaryLines += ""

$summaryFile = Join-Path $ReportsDir "portfolio-summary.md"
$summaryLines | Set-Content -Path $summaryFile -Encoding UTF8
Write-Host "  [OK] portfolio-summary.md" -ForegroundColor Green


# ============================================================================
# TOP 20 DETAILED REPORT
# ============================================================================

Write-Host "Generating: top-20.md" -ForegroundColor Cyan

$top20Lines = @()
$top20Lines += "# Top 20 Repositories - Detailed Analysis"
$top20Lines += ""
$top20Lines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$top20Lines += ""
$top20Lines += "Ranked by Total Value (RC + OV + TSV)"
$top20Lines += ""

$topRepos = $AllMetrics | Sort-Object TotalValueMid -Descending | Select-Object -First 20
$rank = 1

foreach ($repo in $topRepos) {
    $top20Lines += "## #$rank - $($repo.Owner)/$($repo.Repo)"
    $top20Lines += ""

    # Classification and themes
    $top20Lines += "**Classification:** $($repo.Classification)"
    if ($repo.Themes.Count -gt 0) {
        $top20Lines += "**Themes:** $($repo.Themes -join ', ')"
    }
    $top20Lines += ""

    # Value breakdown
    $top20Lines += "### Value Breakdown"
    $top20Lines += ""
    $top20Lines += "| Component | Amount (ZAR) |"
    $top20Lines += "|-----------|--------------|"
    $top20Lines += "| Replacement Cost | R $($repo.ReplacementCostMid.ToString('N0')) |"
    $top20Lines += "| Option Value | R $($repo.OptionValueMid.ToString('N0')) |"
    $top20Lines += "| Time-Saved Value | R $($repo.TsvValue.ToString('N0')) |"
    $top20Lines += "| **Total Value** | **R $($repo.TotalValueMid.ToString('N0'))** |"
    $top20Lines += ""

    # Metrics
    $top20Lines += "### Engineering Metrics"
    $top20Lines += ""
    $top20Lines += "- **Lines of Code:** $($repo.LocTotal.ToString('N0'))"
    $top20Lines += "- **Commits:** $($repo.CommitCount)"
    $top20Lines += "- **Active Years:** $($repo.CommitsByYear.Count)"
    $top20Lines += "- **Estimated Hours:** $($repo.EstimatedHoursMid)"
    $top20Lines += "- **Hours Saved:** $($repo.HoursSaved)"
    $top20Lines += "- **Proof Score:** $($repo.ProofScore)/100"
    $top20Lines += ""

    # 7-dimensional scores
    $top20Lines += "### 7-Dimensional Strategic Score: $($repo.SevenDimTotal)/120"
    $top20Lines += ""
    $top20Lines += "| Dimension | Score | Max |"
    $top20Lines += "|-----------|-------|-----|"
    $top20Lines += "| Originality | $($repo.SevenDimScores.Originality) | 20 |"
    $top20Lines += "| Domain Rarity | $($repo.SevenDimScores.DomainRarity) | 15 |"
    $top20Lines += "| Engineering Depth | $($repo.SevenDimScores.EngineeringDepth) | 25 |"
    $top20Lines += "| Maturity | $($repo.SevenDimScores.Maturity) | 20 |"
    $top20Lines += "| Utility | $($repo.SevenDimScores.Utility) | 15 |"
    $top20Lines += "| Traction | $($repo.SevenDimScores.Traction) | 10 |"
    $top20Lines += "| Idea Strength | $($repo.SevenDimScores.IdeaStrength) | 15 |"
    $top20Lines += "| Risk (penalty) | -$($repo.SevenDimScores.Risk) | -20 |"
    $top20Lines += ""

    # Evidence block
    $top20Lines += "### Evidence of Value"
    $top20Lines += ""
    $evidence = @()

    if ($repo.HasTests) {
        $evidence += "**Testing:** Comprehensive test suite present"
    }
    if ($repo.HasCI) {
        $evidence += "**CI/CD:** Automated pipeline configured"
    }
    if ($repo.HasDocs) {
        $evidence += "**Documentation:** Professional documentation maintained"
    }
    if ($repo.CommitCount -gt 100) {
        $evidence += "**Activity:** High commit frequency ($($repo.CommitCount) commits)"
    }
    if ($repo.CommitsByYear.Count -ge 2) {
        $evidence += "**Longevity:** Multi-year development ($($repo.CommitsByYear.Count) years)"
    }
    if ($repo.LocTotal -gt 50000) {
        $evidence += "**Scale:** Large codebase ($($repo.LocTotal.ToString('N0')) LOC)"
    }
    if ($repo.Themes.Count -ge 2) {
        $evidence += "**Complexity:** Multi-domain integration ($($repo.Themes.Count) themes)"
    }

    foreach ($ev in $evidence) {
        $top20Lines += "- $ev"
    }

    if ($evidence.Count -eq 0) {
        $top20Lines += "- Early-stage project with high strategic potential"
    }

    $top20Lines += ""
    $top20Lines += "---"
    $top20Lines += ""

    $rank++
}

$top20File = Join-Path $ReportsDir "top-20.md"
$top20Lines | Set-Content -Path $top20File -Encoding UTF8
Write-Host "  [OK]top-20.md" -ForegroundColor Green


# ============================================================================
# IDEA SEEDS REPORT
# ============================================================================

Write-Host "Generating: idea-seeds.md" -ForegroundColor Cyan

$ideaLines = @()
$ideaLines += '# R&D Portfolio - Idea Seeds'
$ideaLines += ""
$ideaLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$ideaLines += ""
$ideaLines += "## Overview"
$ideaLines += ""
$ideaLines += 'This report highlights R&D and exploratory projects with high strategic potential.'
$ideaLines += ""

$rdRepos = $AllMetrics | Where-Object { $_.Classification -eq 'R&D' } | Sort-Object SevenDimTotal -Descending

$ideaLines += "**Total R&D Projects:** $($rdRepos.Count)"
$ideaLines += "**Combined Value:** R $(($rdRepos | Measure-Object -Property TotalValueMid -Sum).Sum.ToString('N0'))"
if ($rdRepos.Count -gt 0) {
    $totalIdeaStrength = 0
    foreach ($r in $rdRepos) {
        $totalIdeaStrength += $r.SevenDimScores.IdeaStrength
    }
    $avgIdeaStrength = [Math]::Round($totalIdeaStrength / $rdRepos.Count, 1)
    $ideaLines += "**Average Idea Strength Score:** $avgIdeaStrength/15"
} else {
    $ideaLines += "**Average Idea Strength Score:** 0/15"
}
$ideaLines += ""

$ideaLines += "## High-Potential Ideas"
$ideaLines += ""
$ideaLines += "Projects ranked by Idea Strength and strategic potential:"
$ideaLines += ""

$topIdeas = $rdRepos | Sort-Object { $_.SevenDimScores.IdeaStrength } -Descending | Select-Object -First 20
$rank = 1

foreach ($repo in $topIdeas) {
    $ideaLines += "### #$rank - $($repo.Owner)/$($repo.Repo)"
    $ideaLines += ""
    $ideaLines += "**Idea Strength:** $($repo.SevenDimScores.IdeaStrength)/15"
    $ideaLines += "**Strategic Score:** $($repo.SevenDimTotal)/120"
    $ideaLines += "**Estimated Value:** R $($repo.TotalValueMid.ToString('N0'))"
    $ideaLines += ""

    if ($repo.Themes.Count -gt 0) {
        $ideaLines += "**Themes:** $($repo.Themes -join ', ')"
        $ideaLines += ""
    }

    $ideaLines += "**Key Metrics:**"
    $ideaLines += "- LOC: $($repo.LocTotal.ToString('N0'))"
    $ideaLines += "- Commits: $($repo.CommitCount)"
    $ideaLines += "- Originality Score: $($repo.SevenDimScores.Originality)/20"
    $ideaLines += "- Domain Rarity: $($repo.SevenDimScores.DomainRarity)/15"
    $ideaLines += ""

    # Potential pathways
    $ideaLines += "**Development Pathway:**"
    if ($repo.ProofScore -lt 40) {
        $ideaLines += "- Add comprehensive testing suite"
        $ideaLines += "- Implement CI/CD pipeline"
        $ideaLines += "- Expand documentation"
    } elseif ($repo.ProofScore -lt 65) {
        $ideaLines += "- Increase commit frequency and user testing"
        $ideaLines += "- Enhance documentation with use cases"
        $ideaLines += "- Consider pilot deployment"
    } else {
        $ideaLines += "- Ready for promotion to Tooling or Production classification"
        $ideaLines += "- Consider broader organizational rollout"
    }
    $ideaLines += ""

    $rank++
}

$ideaFile = Join-Path $ReportsDir "idea-seeds.md"
$ideaLines | Set-Content -Path $ideaFile -Encoding UTF8
Write-Host "  [OK]idea-seeds.md" -ForegroundColor Green


# ============================================================================
# TIME-SAVED VALUE MODEL
# ============================================================================

Write-Host "Generating: time-saved-model.md" -ForegroundColor Cyan

$tsvLines = @()
$tsvLines += "# Time-Saved Value (TSV) Model"
$tsvLines += ""
$tsvLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$tsvLines += ""
$tsvLines += "## Methodology"
$tsvLines += ""
$tsvLines += "The Time-Saved Value model estimates the economic value of time saved through automation, tooling, and process improvements."
$tsvLines += ""
$tsvLines += "### Calculation Formula"
$tsvLines += ""
$tsvLines += '```'
$tsvLines += "Base Hours Saved = f(Classification, LOC)"
$tsvLines += "  - Production: min(2000, LOC / 20)"
$tsvLines += "  - Tooling: min(1000, LOC / 30)"
$tsvLines += "  - R&D: min(500, LOC / 50)"
$tsvLines += ""
$tsvLines += "Automation Multiplier = f(Themes)"
$tsvLines += "  - Virtual Commissioning: 3.0x"
$tsvLines += "  - Simulation: 2.5x"
$tsvLines += "  - DevOps: 2.0x"
$tsvLines += "  - Robotics/PLC: 1.8x"
$tsvLines += "  - Other: 1.0x"
$tsvLines += ""
$tsvLines += "Quality Factor = 1.0 + bonuses"
$tsvLines += "  - Has Tests: +0.3"
$tsvLines += "  - High Activity (>100 commits): +0.2"
$tsvLines += ""
$tsvLines += "Total Hours Saved = Base Hours × Automation Multiplier × Quality Factor"
$tsvLines += "TSV (ZAR) = Total Hours Saved × R750/hour"
$tsvLines += '```'
$tsvLines += ""

$tsvLines += "## Portfolio TSV Summary"
$tsvLines += ""

$totalHours = ($AllMetrics | Measure-Object -Property HoursSaved -Sum).Sum
$totalTSV = ($AllMetrics | Measure-Object -Property TsvValue -Sum).Sum

$tsvLines += "- **Total Hours Saved:** $([Math]::Round($totalHours, 0).ToString('N0')) hours"
$tsvLines += "- **Total TSV Value:** R $($totalTSV.ToString('N0'))"
$tsvLines += "- **Average per Repository:** $([Math]::Round($totalHours / $AllMetrics.Count, 1)) hours (R $([Math]::Round($totalTSV / $AllMetrics.Count, 0).ToString('N0')))"
$tsvLines += ""

# By classification
$tsvLines += "### TSV by Classification"
$tsvLines += ""
$tsvLines += "| Classification | Repos | Hours Saved | TSV Value (ZAR) | Avg per Repo |"
$tsvLines += "|---------------|-------|-------------|-----------------|--------------|"

foreach ($class in @('Production', 'Tooling', 'R&D')) {
    $classRepos = $AllMetrics | Where-Object { $_.Classification -eq $class }
    if ($classRepos.Count -gt 0) {
        $classHours = ($classRepos | Measure-Object -Property HoursSaved -Sum).Sum
        $classTSV = ($classRepos | Measure-Object -Property TsvValue -Sum).Sum
        $avgHours = [Math]::Round($classHours / $classRepos.Count, 1)
        $tsvLines += "| $class | $($classRepos.Count) | $([Math]::Round($classHours, 0).ToString('N0')) | R $($classTSV.ToString('N0')) | $avgHours hrs |"
    }
}
$tsvLines += ""

# Top 20 by TSV
$tsvLines += "## Top 20 Repositories by Time-Saved Value"
$tsvLines += ""
$tsvLines += "| Rank | Repo | Classification | Themes | Hours Saved | TSV Value |"
$tsvLines += "|------|------|----------------|--------|-------------|-----------|"

$topTSV = $AllMetrics | Sort-Object TsvValue -Descending | Select-Object -First 20
$rank = 1
foreach ($repo in $topTSV) {
    $themes = if ($repo.Themes.Count -gt 0) { ($repo.Themes -join ', ') } else { '-' }
    $tsvLines += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.Classification) | $themes | $($repo.HoursSaved) | R $($repo.TsvValue.ToString('N0')) |"
    $rank++
}
$tsvLines += ""

# Automation champions
$tsvLines += "## Automation Champions"
$tsvLines += ""
$tsvLines += "Repositories with the highest automation multipliers (Virtual Commissioning & Simulation):"
$tsvLines += ""

$autoChamps = $AllMetrics |
    Where-Object { $_.Themes -contains 'Virtual-Commissioning' -or $_.Themes -contains 'Simulation' } |
    Sort-Object TsvValue -Descending |
    Select-Object -First 10

foreach ($repo in $autoChamps) {
    $tsvLines += "### $($repo.Owner)/$($repo.Repo)"
    $tsvLines += "- **Hours Saved:** $($repo.HoursSaved)"
    $tsvLines += "- **TSV Value:** R $($repo.TsvValue.ToString('N0'))"
    $tsvLines += "- **Automation Type:** $($repo.Themes -join ', ')"
    $tsvLines += "- **Impact:** High-value automation reducing manual commissioning/simulation work"
    $tsvLines += ""
}

$tsvFile = Join-Path $ReportsDir "time-saved-model.md"
$tsvLines | Set-Content -Path $tsvFile -Encoding UTF8
Write-Host "  [OK]time-saved-model.md" -ForegroundColor Green


# ============================================================================
# ENHANCED PROOF-OF-WORK
# ============================================================================

Write-Host "Generating: proof-of-work-enhanced.md" -ForegroundColor Cyan

$powLines = @()
$powLines += "# Proof of Work Report (Enhanced)"
$powLines += ""
$powLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$powLines += ""
$powLines += "## Overview"
$powLines += ""
$powLines += "This report demonstrates sustained software engineering work across multiple repositories, organizations, and technical domains spanning multiple years."
$powLines += ""

# Activity timeline
$allYears = @{}
foreach ($repo in $AllMetrics) {
    foreach ($year in $repo.CommitsByYear.Keys) {
        if (-not $allYears.ContainsKey($year)) {
            $allYears[$year] = 0
        }
        $allYears[$year] += $repo.CommitsByYear[$year]
    }
}

$powLines += "## 26-Year Engineering Timeline (2000-2026)"
$powLines += ""
$powLines += "| Year | Commits | Active Repos |"
$powLines += "|------|---------|--------------|"

$sortedYears = $allYears.Keys | Sort-Object
$firstYear = if ($sortedYears.Count -gt 0) { [int]$sortedYears[0] } else { 2020 }
$lastYear = if ($sortedYears.Count -gt 0) { [int]$sortedYears[-1] } else { 2026 }

foreach ($year in ($allYears.Keys | Sort-Object)) {
    $activeRepos = ($AllMetrics | Where-Object { $_.CommitsByYear.ContainsKey($year) }).Count
    $powLines += "| $year | $($allYears[$year]) | $activeRepos |"
}
$powLines += ""
$powLines += "**Career Span:** $($lastYear - $firstYear + 1) years of continuous development"
$powLines += "**Total Commits:** $(($allYears.Values | Measure-Object -Sum).Sum)"
$powLines += ""

# Theme-based work
$powLines += "## Work by Technical Domain"
$powLines += ""

foreach ($theme in ($themeCount.Keys | Sort-Object { $themeCount[$_] } -Descending)) {
    $themeRepos = $AllMetrics | Where-Object { $_.Themes -contains $theme }
    $themeCommits = ($themeRepos | Measure-Object -Property CommitCount -Sum).Sum
    $themeLOC = ($themeRepos | Measure-Object -Property LocTotal -Sum).Sum

    $powLines += "### $theme"
    $powLines += "- **Repositories:** $($themeRepos.Count)"
    $powLines += "- **Total Commits:** $themeCommits"
    $powLines += "- **Total LOC:** $($themeLOC.ToString('N0'))"
    $powLines += "- **Combined Value:** R $(($themeRepos | Measure-Object -Property TotalValueMid -Sum).Sum.ToString('N0'))"
    $powLines += ""
}

# Signature work
$powLines += "## Signature Work (High-Value Production Assets)"
$powLines += ""
$powLines += "Repositories demonstrating substantial engineering effort, production quality, and strategic value."
$powLines += ""

$signatureRepos = $AllMetrics |
    Where-Object { $_.Classification -eq 'Production' -or ($_.ProofScore -ge 60 -and $_.TotalValueMid -ge 500000) } |
    Sort-Object TotalValueMid -Descending |
    Select-Object -First 15

foreach ($repo in $signatureRepos) {
    $powLines += "### $($repo.Owner)/$($repo.Repo)"
    $powLines += ""
    $powLines += "- **Classification:** $($repo.Classification)"
    if ($repo.Themes.Count -gt 0) {
        $powLines += "- **Domain:** $($repo.Themes -join ', ')"
    }
    $powLines += "- **LOC:** $($repo.LocTotal.ToString('N0'))"
    $powLines += "- **Commits:** $($repo.CommitCount)"
    $powLines += "- **Active Years:** $($repo.CommitsByYear.Count)"
    $powLines += "- **First Commit:** $($repo.FirstCommit)"
    $powLines += "- **Last Commit:** $($repo.LastCommit)"
    $powLines += "- **Tests:** $(if ($repo.HasTests) { 'Yes' } else { 'No' })"
    $powLines += "- **CI/CD:** $(if ($repo.HasCI) { 'Yes' } else { 'No' })"
    $powLines += "- **Documentation:** $(if ($repo.HasDocs) { 'Yes' } else { 'No' })"
    $powLines += "- **Proof Score:** $($repo.ProofScore)/100"
    $powLines += "- **Strategic Score:** $($repo.SevenDimTotal)/120"
    $powLines += "- **Total Value:** R $($repo.TotalValueMid.ToString('N0'))"
    $powLines += ""
}

$powFile = Join-Path $ReportsDir "proof-of-work-enhanced.md"
$powLines | Set-Content -Path $powFile -Encoding UTF8
Write-Host "  [OK]proof-of-work-enhanced.md" -ForegroundColor Green


# ============================================================================
# ENHANCED VALUE ESTIMATE
# ============================================================================

Write-Host "Generating: portfolio-value-enhanced.md" -ForegroundColor Cyan

$valueLines = @()
$valueLines += "# Portfolio Value Estimate (Enhanced)"
$valueLines += ""
$valueLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$valueLines += ""
$valueLines += "## Methodology"
$valueLines += ""
$valueLines += "This enhanced valuation combines three components:"
$valueLines += ""
$valueLines += "### 1. Replacement Cost (RC)"
$valueLines += ""
$valueLines += "The cost to rebuild the repository from scratch."
$valueLines += ""
$valueLines += "**Formula:**"
$valueLines += "- Base Hours = min(LOC / 50, 1200)"
$valueLines += "- Quality Factor = 0.70 + (ProofScore / 100) × 0.70"
$valueLines += "- Estimated Hours = Base Hours × Quality Factor"
$valueLines += "- RC = Estimated Hours × R750/hour"
$valueLines += ""
$valueLines += "### 2. Option Value (OV)"
$valueLines += ""
$valueLines += "The strategic value and optionality the repository provides."
$valueLines += ""
$valueLines += "**Formula:**"
$valueLines += "- Base Multiplier: Production (2.5x), Tooling (1.5x), R&D (3.0x)"
$valueLines += "- Theme Bonus: Virtual Commissioning (+0.5), Simulation (+0.3), etc."
$valueLines += "- Quality Multiplier: 1.0 + (7D Score / 120) × 0.5"
$valueLines += "- OV = RC × Base Multiplier × Theme Bonus × Quality Multiplier"
$valueLines += ""
$valueLines += "### 3. Time-Saved Value (TSV)"
$valueLines += ""
$valueLines += "The economic value of time saved through automation and tooling."
$valueLines += ""
$valueLines += "**Formula:**"
$valueLines += "- See time-saved-model.md for detailed methodology"
$valueLines += ""

# Portfolio totals
$valueLines += "## Portfolio Value Summary"
$valueLines += ""
$valueLines += "| Component | Total Value (ZAR) | % of Total |"
$valueLines += "|-----------|-------------------|------------|"
$valueLines += "| Replacement Cost (RC) | R $($totalRC.ToString('N0')) | $([Math]::Round($totalRC / $totalValue * 100, 1))% |"
$valueLines += "| Option Value (OV) | R $($totalOV.ToString('N0')) | $([Math]::Round($totalOV / $totalValue * 100, 1))% |"
$valueLines += "| Time-Saved Value (TSV) | R $($totalTSV.ToString('N0')) | $([Math]::Round($totalTSV / $totalValue * 100, 1))% |"
$valueLines += "| **Total Portfolio Value** | **R $($totalValue.ToString('N0'))** | 100% |"
$valueLines += ""

# By classification
$valueLines += "## Value by Classification"
$valueLines += ""
$valueLines += "| Classification | Count | RC | OV | TSV | Total Value | Avg Value |"
$valueLines += "|---------------|-------|----|----|-----|-------------|-----------|"

foreach ($class in @('Production', 'Tooling', 'R&D')) {
    $classRepos = $AllMetrics | Where-Object { $_.Classification -eq $class }
    if ($classRepos.Count -gt 0) {
        $classRC = ($classRepos | Measure-Object -Property ReplacementCostMid -Sum).Sum
        $classOV = ($classRepos | Measure-Object -Property OptionValueMid -Sum).Sum
        $classTSV = ($classRepos | Measure-Object -Property TsvValue -Sum).Sum
        $classTotal = ($classRepos | Measure-Object -Property TotalValueMid -Sum).Sum
        $classAvg = [Math]::Round($classTotal / $classRepos.Count, 0)

        $valueLines += "| $class | $($classRepos.Count) | R $($classRC.ToString('N0')) | R $($classOV.ToString('N0')) | R $($classTSV.ToString('N0')) | R $($classTotal.ToString('N0')) | R $($classAvg.ToString('N0')) |"
    }
}
$valueLines += ""

# Top 30 by total value
$valueLines += "## Top 30 Repositories by Total Value"
$valueLines += ""
$valueLines += "| Rank | Repo | Class | RC | OV | TSV | Total Value |"
$valueLines += "|------|------|-------|----|----|-----|-------------|"

$topValue = $AllMetrics | Sort-Object TotalValueMid -Descending | Select-Object -First 30
$rank = 1
foreach ($repo in $topValue) {
    $valueLines += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.Classification) | R $($repo.ReplacementCostMid.ToString('N0')) | R $($repo.OptionValueMid.ToString('N0')) | R $($repo.TsvValue.ToString('N0')) | R $($repo.TotalValueMid.ToString('N0')) |"
    $rank++
}
$valueLines += ""

$valueFile = Join-Path $ReportsDir "portfolio-value-enhanced.md"
$valueLines | Set-Content -Path $valueFile -Encoding UTF8
Write-Host "  [OK]portfolio-value-enhanced.md" -ForegroundColor Green

Write-Host ""
Write-Host "All reports generated successfully!" -ForegroundColor Green
