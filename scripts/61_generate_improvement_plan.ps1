#Requires -Version 5.1
<#
.SYNOPSIS
    Generate prioritized improvement action plan
.DESCRIPTION
    Creates a specific, actionable roadmap for improving repository quality
#>

param()

$ErrorActionPreference = 'Stop'

$VaultRoot = Split-Path $PSScriptRoot -Parent
$ReportsDir = Join-Path $VaultRoot "reports"
$QualityCSVFile = Join-Path $ReportsDir "quality-audit.csv"
$ActionPlanFile = Join-Path $ReportsDir "improvement-action-plan.md"
$QuickWinsFile = Join-Path $ReportsDir "quick-wins.md"

Write-Host "=== Generating Improvement Action Plan ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $QualityCSVFile)) {
    Write-Error "Quality audit not found. Run 60_quality_audit.ps1 first."
}

# Load audit data
$auditData = Import-Csv -Path $QualityCSVFile

# Categorize repositories
$showcase = $auditData | Where-Object { [int]$_.Score -ge 80 }
$good = $auditData | Where-Object { [int]$_.Score -ge 60 -and [int]$_.Score -lt 80 }
$needsWork = $auditData | Where-Object { [int]$_.Score -ge 40 -and [int]$_.Score -lt 60 }
$poor = $auditData | Where-Object { [int]$_.Score -lt 40 }

# Generate action plan
$plan = @()
$plan += "# Portfolio Improvement Action Plan"
$plan += ""
$plan += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$plan += "**Goal:** Transform 120 poor-quality repos into professional showcases"
$plan += ""

$plan += "## Strategy Overview"
$plan += ""
$plan += "### Current Portfolio Distribution"
$plan += ""
$plan += "| Category | Count | Strategy |"
$plan += "|----------|-------|----------|"
$plan += "| Showcase (80-100) | $($showcase.Count) | Maintain & promote |"
$plan += "| Good (60-79) | $($good.Count) | Push to excellence |"
$plan += "| Needs Work (40-59) | $($needsWork.Count) | Targeted improvements |"
$plan += "| Poor (<40) | $($poor.Count) | Quick wins or archive |"
$plan += ""

$plan += "## Three-Phase Approach"
$plan += ""
$plan += "### Phase 1: Quick Wins (Week 1-2)"
$plan += ""
$plan += "**Goal:** Add basic professionalism to ALL repos"
$plan += ""
$plan += "**Universal Actions (Apply to all 156 repos):**"
$plan += ""
$plan += "1. **Add LICENSE file** (142 repos need this)"
$plan += "   - Choose: MIT for open source, proprietary for client work"
$plan += "   - Tool: Create LICENSE template script"
$plan += "   - Time: 30 seconds per repo = 2 hours total"
$plan += ""
$plan += "2. **Add basic CHANGELOG.md** (142 repos need this)"
$plan += "   - Template: `## [Unreleased]` + recent changes"
$plan += "   - Time: 2 minutes per repo = 5 hours total"
$plan += ""
$plan += "3. **Add .gitignore** (if missing)"
$plan += "   - Language-specific templates"
$plan += "   - Time: 1 minute per repo = 2 hours total"
$plan += ""
$plan += "**Estimated Total: 9 hours → Portfolio baseline professionalism**"
$plan += ""

$plan += "### Phase 2: High-Value Repos (Week 3-4)"
$plan += ""
$plan += "**Goal:** Make top 20 value repos EXCELLENT"
$plan += ""
$plan += "**Focus on repos with:**"
$plan += "- High LOC (> 10K)"
$plan += "- Recent activity (< 6 months)"
$plan += "- Business value"
$plan += "- Current score < 80"
$plan += ""

# Identify high-value targets
$highValueTargets = $auditData |
    Where-Object { [int]$_.Score -lt 80 -and [int]$_.DaysSinceLastCommit -lt 180 } |
    Sort-Object Score |
    Select-Object -First 20

$plan += "**Top 20 High-Value Targets:**"
$plan += ""
$plan += "| Rank | Repository | Current Score | Priority Actions |"
$plan += "|------|------------|---------------|------------------|"

$rank = 1
foreach ($repo in $highValueTargets) {
    $actions = @()
    if ($repo.HasReadme -eq 'False') { $actions += "README" }
    if ($repo.HasTests -eq 'False') { $actions += "Tests" }
    if ($repo.HasCI -eq 'False') { $actions += "CI/CD" }
    if ($repo.HasDocs -eq 'False') { $actions += "Docs" }

    $actionsList = $actions -join ", "
    $plan += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.Score) | $actionsList |"
    $rank++
}

$plan += ""
$plan += "**Per-Repo Actions:**"
$plan += ""
$plan += "For each high-value repo:"
$plan += ""
$plan += "1. **Professional README** (2-3 hours each)"
$plan += "   - Project description & value proposition"
$plan += "   - Installation instructions"
$plan += "   - Usage examples with code blocks"
$plan += "   - Screenshots/demos if applicable"
$plan += "   - Configuration options"
$plan += "   - Troubleshooting section"
$plan += ""
$plan += "2. **Add Tests** (4-8 hours each)"
$plan += "   - Unit tests for core functionality"
$plan += "   - Integration tests if applicable"
$plan += "   - Aim for 60%+ coverage"
$plan += ""
$plan += "3. **Setup CI/CD** (1-2 hours each)"
$plan += "   - GitHub Actions workflow"
$plan += "   - Run tests on PR"
$plan += "   - Build/lint checks"
$plan += ""
$plan += "4. **Add Technical Docs** (2-4 hours each)"
$plan += "   - Architecture overview"
$plan += "   - API documentation"
$plan += "   - Development setup guide"
$plan += ""
$plan += "**Estimated: 10-17 hours per repo × 20 repos = 200-340 hours**"
$plan += "**Realistic Timeline: 8-12 weeks at 25-30 hours/week**"
$plan += ""

$plan += "### Phase 3: Archive or Improve (Week 13+)"
$plan += ""
$plan += "**Goal:** Decisively handle remaining poor-quality repos"
$plan += ""

# Identify archive candidates
$archiveCandidates = $poor |
    Where-Object { [int]$_.DaysSinceLastCommit -gt 730 } |  # 2+ years
    Sort-Object DaysSinceLastCommit -Descending

$plan += "**Archive Candidates ($($archiveCandidates.Count) repos):**"
$plan += ""
$plan += "Repos inactive for 2+ years with low value:"
$plan += ""

if ($archiveCandidates.Count -gt 0) {
    $plan += "| Repository | Score | Days Inactive |"
    $plan += "|------------|-------|---------------|"

    foreach ($repo in ($archiveCandidates | Select-Object -First 15)) {
        $daysInactive = [int]$repo.DaysSinceLastCommit
        $yearsInactive = [math]::Round($daysInactive / 365, 1)
        $plan += "| $($repo.Owner)/$($repo.Repo) | $($repo.Score) | $daysInactive ($yearsInactive years) |"
    }

    $plan += ""
    $plan += "**Action:** Archive these to clean up portfolio"
    $plan += "- Move to separate 'archived' org or mark as archived on GitHub"
    $plan += "- Reduces noise, improves overall portfolio metrics"
    $plan += ""
} else {
    $plan += "No clear archive candidates found."
    $plan += ""
}

$plan += "## Implementation Checklist"
$plan += ""
$plan += "### Week 1-2: Universal Quick Wins"
$plan += ""
$plan += "- [ ] Create LICENSE template generator script"
$plan += "- [ ] Create CHANGELOG template generator script"
$plan += "- [ ] Run bulk LICENSE addition (all 142 repos)"
$plan += "- [ ] Run bulk CHANGELOG addition (all 142 repos)"
$plan += "- [ ] Add missing .gitignore files"
$plan += "- [ ] Re-run quality audit → Expected new avg: 35-40/100"
$plan += ""

$plan += "### Week 3-6: First 5 High-Value Repos"
$plan += ""
foreach ($repo in ($highValueTargets | Select-Object -First 5)) {
    $plan += "- [ ] $($repo.Owner)/$($repo.Repo)"
    $plan += "  - [ ] Professional README"
    $plan += "  - [ ] Add tests"
    $plan += "  - [ ] Setup CI/CD"
    $plan += "  - [ ] Technical documentation"
}
$plan += ""

$plan += "### Week 7-12: Next 15 High-Value Repos"
$plan += ""
$plan += "Continue same process for remaining high-value targets"
$plan += ""

$plan += "### Week 13+: Clean Up"
$plan += ""
$plan += "- [ ] Archive inactive repos"
$plan += "- [ ] Final quality audit"
$plan += "- [ ] Document portfolio improvements"
$plan += "- [ ] Update portfolio website/resume"
$plan += ""

$plan += "## Automation Opportunities"
$plan += ""
$plan += "**Scripts to create:**"
$plan += ""
$plan += "1. **bulk_add_license.ps1** - Add LICENSE to all repos"
$plan += "2. **bulk_add_changelog.ps1** - Add CHANGELOG template"
$plan += "3. **bulk_add_gitignore.ps1** - Add language-specific .gitignore"
$plan += "4. **readme_template_generator.ps1** - Generate README skeleton"
$plan += "5. **ci_workflow_generator.ps1** - Add GitHub Actions for each language"
$plan += ""

$plan += "## Success Metrics"
$plan += ""
$plan += "**Target Portfolio Quality (3 months):**"
$plan += ""
$plan += "| Metric | Current | Target | Improvement |"
$plan += "|--------|---------|--------|-------------|"
$plan += "| Average Score | 23.6 | 60+ | +154% |"
$plan += "| Excellent (80-100) | 13 (8.3%) | 40+ (25.6%) | +208% |"
$plan += "| With LICENSE | 14 (9%) | 156 (100%) | +1014% |"
$plan += "| With Tests | 76 (48.7%) | 120+ (77%) | +58% |"
$plan += "| With CI/CD | 17 (10.9%) | 60+ (38.5%) | +253% |"
$plan += ""

$plan += "## ROI Analysis"
$plan += ""
$plan += "**Time Investment:** ~250-350 hours over 3 months"
$plan += ""
$plan += "**Value Impact:**"
$plan += "- Portfolio appears 3x more professional"
$plan += "- Higher hiring/client confidence"
$plan += "- Easier to showcase specific skills"
$plan += "- Demonstrates attention to detail"
$plan += "- Justifies premium rates"
$plan += ""
$plan += "**Estimated Value Increase:**"
$plan += "- Current perceived value: ~40% of technical value"
$plan += "- Target perceived value: ~90% of technical value"
$plan += "- Effective portfolio value increase: +125%"
$plan += ""

# Save action plan
$plan | Set-Content -Path $ActionPlanFile -Encoding UTF8

Write-Host "Generated: improvement-action-plan.md" -ForegroundColor Green

# Generate Quick Wins file
$quickWins = @()
$quickWins += "# Quick Wins - Immediate Actions"
$quickWins += ""
$quickWins += "**Time Required:** 9 hours total"
$quickWins += "**Impact:** Universal professionalism baseline"
$quickWins += ""

$quickWins += "## Action 1: Bulk Add LICENSE Files"
$quickWins += ""
$quickWins += "**Repos Affected:** 142"
$quickWins += "**Time:** 2 hours"
$quickWins += ""
$quickWins += "### Steps:"
$quickWins += ""
$quickWins += "1. Choose license type:"
$quickWins += "   - **MIT**: For open source projects"
$quickWins += "   - **Proprietary**: For client/commercial work"
$quickWins += ""
$quickWins += "2. Run bulk license script (to be created)"
$quickWins += ""
$quickWins += "### Template Decision:"
$quickWins += ""

$openSourceRepos = $auditData | Where-Object { $_.Owner -like '*-Web' -or $_.Owner -eq 'GeorgeMcIntyre' }
$clientRepos = $auditData | Where-Object { $_.Owner -notlike '*-Web' -and $_.Owner -ne 'GeorgeMcIntyre' }

$quickWins += "- **MIT License:** $($openSourceRepos.Count) repos (personal/web projects)"
$quickWins += "- **Proprietary:** $($clientRepos.Count) repos (client work)"
$quickWins += ""

$quickWins += "## Action 2: Bulk Add CHANGELOG.md"
$quickWins += ""
$quickWins += "**Repos Affected:** 142"
$quickWins += "**Time:** 5 hours"
$quickWins += ""
$quickWins += "Basic template:"
$quickWins += "```markdown"
$quickWins += "# Changelog"
$quickWins += ""
$quickWins += "## [Unreleased]"
$quickWins += "- Initial repository setup"
$quickWins += "```"
$quickWins += ""

$quickWins += "## Action 3: Add .gitignore Where Missing"
$quickWins += ""
$quickWins += "**Time:** 2 hours"
$quickWins += ""
$quickWins += "Use GitHub's standard templates for each language"
$quickWins += ""

$quickWins += "## Expected Outcome"
$quickWins += ""
$quickWins += "**After Quick Wins:**"
$quickWins += "- Every repo has LICENSE → Professional legitimacy"
$quickWins += "- Every repo has CHANGELOG → Shows maintenance"
$quickWins += "- Proper .gitignore → Clean repos"
$quickWins += ""
$quickWins += "**Quality Score Impact:**"
$quickWins += "- Average score: 23.6 → ~35-40"
$quickWins += "- +10-15 points per repo from LICENSE + CHANGELOG"
$quickWins += ""

$quickWins | Set-Content -Path $QuickWinsFile -Encoding UTF8

Write-Host "Generated: quick-wins.md" -ForegroundColor Green
Write-Host ""
Write-Host "Action plan complete!" -ForegroundColor Green
Write-Host ""

exit 0
