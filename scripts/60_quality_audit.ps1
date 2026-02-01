#Requires -Version 5.1
<#
.SYNOPSIS
    Audit repository quality and generate improvement recommendations
.DESCRIPTION
    Analyzes all repositories for quality signals and generates actionable recommendations
#>

param()

$ErrorActionPreference = 'Stop'

$VaultRoot = Split-Path $PSScriptRoot -Parent
$ReposRoot = "F:\VaultRepo\_repos"
$ReportsDir = Join-Path $VaultRoot "reports"
$LogsDir = Join-Path $VaultRoot "logs"
$QualityReportFile = Join-Path $ReportsDir "quality-audit.md"
$QualityCSVFile = Join-Path $ReportsDir "quality-audit.csv"
$ActionPlanFile = Join-Path $ReportsDir "improvement-action-plan.md"

Write-Host "=== Repository Quality Audit ===" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Quality scoring functions
function Test-HasReadme {
    param([string]$RepoPath)

    $readmeFiles = @("README.md", "README.rst", "README.txt", "README", "readme.md")
    foreach ($file in $readmeFiles) {
        if (Test-Path (Join-Path $RepoPath $file)) {
            return $true
        }
    }
    return $false
}

function Get-ReadmeQuality {
    param([string]$RepoPath)

    $score = 0
    $issues = @()

    $readmeFiles = @("README.md", "README.rst", "README.txt", "README", "readme.md")
    $readmePath = $null

    foreach ($file in $readmeFiles) {
        $path = Join-Path $RepoPath $file
        if (Test-Path $path) {
            $readmePath = $path
            break
        }
    }

    if (-not $readmePath) {
        $issues += "No README file found"
        return @{ Score = 0; Issues = $issues }
    }

    $score += 10  # Has README

    try {
        $content = Get-Content -Path $readmePath -Raw -ErrorAction SilentlyContinue

        if ($content) {
            # Check for description (first 500 chars should have content)
            if ($content.Length -gt 100) {
                $score += 5
            } else {
                $issues += "README is too short (< 100 chars)"
            }

            # Check for installation instructions
            if ($content -match '(?i)(install|setup|getting started|quick start)') {
                $score += 5
            } else {
                $issues += "No installation/setup instructions"
            }

            # Check for usage examples
            if ($content -match '(?i)(usage|example|how to|tutorial)' -or $content -match '```') {
                $score += 5
            } else {
                $issues += "No usage examples or code blocks"
            }
        }
    } catch {
        $issues += "Error reading README"
    }

    return @{ Score = $score; Issues = $issues }
}

function Test-HasTests {
    param([string]$RepoPath)

    $testPatterns = @(
        "test", "tests", "__tests__", "spec", "specs",
        "Test", "Tests", "UnitTests", "IntegrationTests"
    )

    foreach ($pattern in $testPatterns) {
        $testPath = Join-Path $RepoPath $pattern
        if (Test-Path $testPath) {
            return $true
        }
    }

    # Check for test files
    $testFiles = Get-ChildItem -Path $RepoPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)test|spec' } |
        Select-Object -First 1

    return $null -ne $testFiles
}

function Test-HasCI {
    param([string]$RepoPath)

    $ciPaths = @(
        ".github\workflows",
        ".gitlab-ci.yml",
        ".travis.yml",
        "azure-pipelines.yml",
        ".circleci",
        "Jenkinsfile",
        ".github\workflows",
        "bitbucket-pipelines.yml"
    )

    foreach ($ciPath in $ciPaths) {
        if (Test-Path (Join-Path $RepoPath $ciPath)) {
            return $true
        }
    }

    return $false
}

function Test-HasDocs {
    param([string]$RepoPath)

    $docPaths = @(
        "docs", "doc", "documentation", "wiki",
        "CONTRIBUTING.md", "ARCHITECTURE.md", "DESIGN.md"
    )

    foreach ($docPath in $docPaths) {
        if (Test-Path (Join-Path $RepoPath $docPath)) {
            return $true
        }
    }

    return $false
}

function Test-HasLicense {
    param([string]$RepoPath)

    $licenseFiles = @("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING")

    foreach ($file in $licenseFiles) {
        if (Test-Path (Join-Path $RepoPath $file)) {
            return $true
        }
    }

    return $false
}

function Test-HasChangelog {
    param([string]$RepoPath)

    $changelogFiles = @("CHANGELOG.md", "CHANGELOG.txt", "CHANGELOG", "HISTORY.md", "RELEASES.md")

    foreach ($file in $changelogFiles) {
        if (Test-Path (Join-Path $RepoPath $file)) {
            return $true
        }
    }

    return $false
}

function Get-RecentActivity {
    param([string]$RepoPath)

    try {
        $lastCommit = git -C $RepoPath log -1 --format=%ci 2>&1
        if ($LASTEXITCODE -eq 0 -and $lastCommit) {
            $lastCommitDate = [DateTime]::Parse($lastCommit)
            $daysSince = ((Get-Date) - $lastCommitDate).Days
            return $daysSince
        }
    } catch {}

    return 9999  # Very old
}

function Get-QualityScore {
    param([string]$RepoPath, [string]$Owner, [string]$RepoName)

    $score = 0
    $maxScore = 100
    $recommendations = @()
    $strengths = @()

    Write-Host "  Auditing: $Owner/$RepoName" -NoNewline

    # Professional Presentation (0-25)
    $readmeResult = Get-ReadmeQuality -RepoPath $RepoPath
    $score += $readmeResult.Score

    if ($readmeResult.Score -ge 20) {
        $strengths += "Excellent README documentation"
    } elseif ($readmeResult.Score -lt 10) {
        $recommendations += "Add comprehensive README with description, installation, and usage"
    } else {
        foreach ($issue in $readmeResult.Issues) {
            $recommendations += $issue
        }
    }

    # Documentation Quality (0-20)
    $hasDocs = Test-HasDocs -RepoPath $RepoPath
    if ($hasDocs) {
        $score += 10
        $strengths += "Has additional documentation"
    } else {
        $recommendations += "Add docs/ folder with technical documentation"
    }

    $hasChangelog = Test-HasChangelog -RepoPath $RepoPath
    if ($hasChangelog) {
        $score += 5
        $strengths += "Maintains changelog"
    } else {
        $recommendations += "Add CHANGELOG.md to track changes"
    }

    $hasLicense = Test-HasLicense -RepoPath $RepoPath
    if ($hasLicense) {
        $score += 5
        $strengths += "Has license file"
    } else {
        $recommendations += "Add LICENSE file"
    }

    # Engineering Maturity (0-25)
    $hasTests = Test-HasTests -RepoPath $RepoPath
    if ($hasTests) {
        $score += 10
        $strengths += "Has test suite"
    } else {
        $recommendations += "Add unit tests (high priority)"
    }

    $hasCI = Test-HasCI -RepoPath $RepoPath
    if ($hasCI) {
        $score += 10
        $strengths += "Has CI/CD pipeline"
    } else {
        $recommendations += "Set up GitHub Actions or CI/CD"
    }

    # Check for package.json, requirements.txt, etc.
    $hasDependencyManagement = $false
    $depFiles = @("package.json", "requirements.txt", "Cargo.toml", "go.mod", "pom.xml", "build.gradle")
    foreach ($depFile in $depFiles) {
        if (Test-Path (Join-Path $RepoPath $depFile)) {
            $hasDependencyManagement = $true
            $score += 5
            $strengths += "Proper dependency management"
            break
        }
    }

    if (-not $hasDependencyManagement) {
        $recommendations += "Add dependency management file (package.json, etc.)"
    }

    # Project Health (0-15)
    $daysSinceLastCommit = Get-RecentActivity -RepoPath $RepoPath

    if ($daysSinceLastCommit -lt 180) {  # < 6 months
        $score += 10
        $strengths += "Recently active (< 6 months)"
    } elseif ($daysSinceLastCommit -lt 365) {  # < 1 year
        $score += 5
    } else {
        $recommendations += "Repository inactive for $([math]::Round($daysSinceLastCommit / 365, 1)) years - consider archiving or updating"
    }

    # Check for TODO/FIXME comments (sample)
    $hasIssues = $false
    try {
        $sampleFiles = Get-ChildItem -Path $RepoPath -File -Recurse -Include "*.cs","*.js","*.ts","*.py","*.go" -ErrorAction SilentlyContinue |
            Select-Object -First 20

        foreach ($file in $sampleFiles) {
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match '(?i)(TODO|FIXME|HACK|XXX):') {
                $hasIssues = $true
                break
            }
        }
    } catch {}

    if (-not $hasIssues) {
        $score += 5
    } else {
        $recommendations += "Clean up TODO/FIXME comments"
    }

    # Portfolio Value (0-15)
    # This is more subjective - we'll estimate based on indicators

    # Has meaningful description in README
    if ($readmeResult.Score -ge 15) {
        $score += 5
    }

    # Production indicators
    $prodIndicators = @(".env.example", "docker-compose.yml", "Dockerfile", "k8s", "terraform")
    $hasProductionConfig = $false
    foreach ($indicator in $prodIndicators) {
        if (Test-Path (Join-Path $RepoPath $indicator)) {
            $hasProductionConfig = $true
            $score += 5
            $strengths += "Production-ready configuration"
            break
        }
    }

    # Specialized/unique value (has custom modules/packages)
    $hasStructure = $false
    $structurePaths = @("src", "lib", "modules", "packages", "core")
    foreach ($path in $structurePaths) {
        if (Test-Path (Join-Path $RepoPath $path)) {
            $hasStructure = $true
            $score += 5
            break
        }
    }

    Write-Host " [$score/$maxScore]" -ForegroundColor $(
        if ($score -ge 80) { 'Green' }
        elseif ($score -ge 60) { 'Yellow' }
        elseif ($score -ge 40) { 'DarkYellow' }
        else { 'Red' }
    )

    return @{
        Score = $score
        MaxScore = $maxScore
        Recommendations = $recommendations
        Strengths = $strengths
        HasReadme = $readmeResult.Score -gt 0
        HasTests = $hasTests
        HasCI = $hasCI
        HasDocs = $hasDocs
        DaysSinceLastCommit = $daysSinceLastCommit
    }
}

# Scan all repositories
Write-Host "Discovering repositories..." -ForegroundColor Cyan

$allRepos = @()

# Personal repos
$personalPath = Join-Path $ReposRoot "personal"
if (Test-Path $personalPath) {
    $personalRepos = Get-ChildItem -Path $personalPath -Directory
    Write-Host "  Personal: $($personalRepos.Count) repos" -ForegroundColor Gray
    foreach ($repo in $personalRepos) {
        $parts = $repo.Name -split '__'
        if ($parts.Count -eq 2) {
            $allRepos += @{
                Path = $repo.FullName
                Owner = $parts[0]
                Name = $parts[1]
                AccountType = "Personal"
            }
        }
    }
}

# Work repos
$workPath = Join-Path $ReposRoot "work"
if (Test-Path $workPath) {
    $workRepos = Get-ChildItem -Path $workPath -Directory
    Write-Host "  Work: $($workRepos.Count) repos" -ForegroundColor Gray
    foreach ($repo in $workRepos) {
        $parts = $repo.Name -split '__'
        if ($parts.Count -eq 2) {
            $allRepos += @{
                Path = $repo.FullName
                Owner = $parts[0]
                Name = $parts[1]
                AccountType = "Work"
            }
        }
    }
}

Write-Host "Total repos to audit: $($allRepos.Count)" -ForegroundColor Cyan
Write-Host ""

# Audit all repositories
$auditResults = @()
$current = 0

foreach ($repoInfo in $allRepos) {
    $current++
    Write-Host "[$current/$($allRepos.Count)]" -NoNewline -ForegroundColor Gray

    $qualityData = Get-QualityScore -RepoPath $repoInfo.Path -Owner $repoInfo.Owner -RepoName $repoInfo.Name

    $auditResults += [PSCustomObject]@{
        AccountType = $repoInfo.AccountType
        Owner = $repoInfo.Owner
        Repo = $repoInfo.Name
        Score = $qualityData.Score
        MaxScore = $qualityData.MaxScore
        Grade = if ($qualityData.Score -ge 80) { "Excellent" }
                elseif ($qualityData.Score -ge 60) { "Good" }
                elseif ($qualityData.Score -ge 40) { "Needs Work" }
                else { "Poor" }
        HasReadme = $qualityData.HasReadme
        HasTests = $qualityData.HasTests
        HasCI = $qualityData.HasCI
        HasDocs = $qualityData.HasDocs
        DaysSinceLastCommit = $qualityData.DaysSinceLastCommit
        RecommendationCount = $qualityData.Recommendations.Count
        Recommendations = $qualityData.Recommendations -join "; "
        Strengths = $qualityData.Strengths -join "; "
    }
}

Write-Host ""
Write-Host "Audit complete. Generating reports..." -ForegroundColor Cyan
Write-Host ""

# Export CSV
$auditResults | Export-Csv -Path $QualityCSVFile -NoTypeInformation -Encoding UTF8
Write-Host "Generated: quality-audit.csv" -ForegroundColor Green

# Generate quality report
$report = @()
$report += "# Repository Quality Audit Report"
$report += ""
$report += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "**Total Repositories:** $($auditResults.Count)"
$report += ""

# Summary statistics
$excellent = ($auditResults | Where-Object { $_.Grade -eq "Excellent" }).Count
$good = ($auditResults | Where-Object { $_.Grade -eq "Good" }).Count
$needsWork = ($auditResults | Where-Object { $_.Grade -eq "Needs Work" }).Count
$poor = ($auditResults | Where-Object { $_.Grade -eq "Poor" }).Count

$avgScore = [math]::Round(($auditResults | Measure-Object -Property Score -Average).Average, 1)

$report += "## Portfolio Health Summary"
$report += ""
$report += "| Grade | Count | Percentage |"
$report += "|-------|-------|------------|"
$report += "| Excellent (80-100) | $excellent | $([math]::Round($excellent / $auditResults.Count * 100, 1))% |"
$report += "| Good (60-79) | $good | $([math]::Round($good / $auditResults.Count * 100, 1))% |"
$report += "| Needs Work (40-59) | $needsWork | $([math]::Round($needsWork / $auditResults.Count * 100, 1))% |"
$report += "| Poor (<40) | $poor | $([math]::Round($poor / $auditResults.Count * 100, 1))% |"
$report += ""
$report += "**Average Quality Score:** $avgScore / 100"
$report += ""

# Key metrics
$withTests = ($auditResults | Where-Object { $_.HasTests }).Count
$withCI = ($auditResults | Where-Object { $_.HasCI }).Count
$withDocs = ($auditResults | Where-Object { $_.HasDocs }).Count
$withReadme = ($auditResults | Where-Object { $_.HasReadme }).Count

$report += "## Key Metrics"
$report += ""
$report += "- **With README:** $withReadme / $($auditResults.Count) ($([math]::Round($withReadme / $auditResults.Count * 100, 1))%)"
$report += "- **With Tests:** $withTests / $($auditResults.Count) ($([math]::Round($withTests / $auditResults.Count * 100, 1))%)"
$report += "- **With CI/CD:** $withCI / $($auditResults.Count) ($([math]::Round($withCI / $auditResults.Count * 100, 1))%)"
$report += "- **With Docs:** $withDocs / $($auditResults.Count) ($([math]::Round($withDocs / $auditResults.Count * 100, 1))%)"
$report += ""

# High priority improvements
$report += "## High Priority Improvements"
$report += ""
$report += "Repositories that need immediate attention (Score < 40):"
$report += ""

$highPriority = $auditResults | Where-Object { $_.Score -lt 40 } | Sort-Object Score | Select-Object -First 20

if ($highPriority.Count -gt 0) {
    $report += "| Rank | Repository | Score | Top Issues |"
    $report += "|------|------------|-------|------------|"

    $rank = 1
    foreach ($repo in $highPriority) {
        $topIssues = ($repo.Recommendations -split ';' | Select-Object -First 3) -join ', '
        if ($topIssues.Length -gt 80) {
            $topIssues = $topIssues.Substring(0, 77) + "..."
        }
        $report += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.Score) | $topIssues |"
        $rank++
    }
} else {
    $report += "No repositories with score < 40. Great job!"
}

$report += ""

# Top performers
$report += "## Top 10 Quality Repositories"
$report += ""

$topRepos = $auditResults | Sort-Object Score -Descending | Select-Object -First 10

$report += "| Rank | Repository | Score | Strengths |"
$report += "|------|------------|-------|-----------|"

$rank = 1
foreach ($repo in $topRepos) {
    $strengths = $repo.Strengths
    if ($strengths.Length -gt 60) {
        $strengths = $strengths.Substring(0, 57) + "..."
    }
    $report += "| $rank | $($repo.Owner)/$($repo.Repo) | $($repo.Score) | $strengths |"
    $rank++
}

$report += ""

# Recommendations summary
$report += "## Recommended Actions"
$report += ""
$report += "Based on the audit, here are the most impactful improvements:"
$report += ""

# Count common recommendations
$allRecs = $auditResults.Recommendations -split ';' | Where-Object { $_ -and $_.Trim() }
$recCounts = $allRecs | Group-Object | Sort-Object Count -Descending | Select-Object -First 10

$report += "| Recommendation | Repos Affected |"
$report += "|----------------|----------------|"

foreach ($rec in $recCounts) {
    $report += "| $($rec.Name.Trim()) | $($rec.Count) |"
}

$report += ""

# Save report
$report | Set-Content -Path $QualityReportFile -Encoding UTF8
Write-Host "Generated: quality-audit.md" -ForegroundColor Green

Write-Host ""
Write-Host "=== Quality Audit Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Portfolio Health:" -ForegroundColor Cyan
Write-Host "  Excellent: $excellent repos ($([math]::Round($excellent / $auditResults.Count * 100, 1))%)" -ForegroundColor Green
Write-Host "  Good: $good repos ($([math]::Round($good / $auditResults.Count * 100, 1))%)" -ForegroundColor Yellow
Write-Host "  Needs Work: $needsWork repos ($([math]::Round($needsWork / $auditResults.Count * 100, 1))%)" -ForegroundColor DarkYellow
Write-Host "  Poor: $poor repos ($([math]::Round($poor / $auditResults.Count * 100, 1))%)" -ForegroundColor Red
Write-Host ""
Write-Host "Average Quality Score: $avgScore / 100" -ForegroundColor Cyan
Write-Host ""
Write-Host "Reports saved to:" -ForegroundColor Cyan
Write-Host "  - $QualityReportFile" -ForegroundColor Gray
Write-Host "  - $QualityCSVFile" -ForegroundColor Gray
Write-Host ""

exit 0
