#Requires -Version 5.1
<#
.SYNOPSIS
    Analyze all repositories and generate reports
.DESCRIPTION
    Generates inventory, proof-of-work, and value estimate reports
#>

param()

$ErrorActionPreference = 'Stop'

$VaultRoot = "F:\VaultRepo\vault"
$ReposRoot = "F:\VaultRepo\_repos"
$ScriptsDir = Join-Path $VaultRoot "scripts"
$ReportsDir = Join-Path $VaultRoot "reports"
$LogsDir = Join-Path $VaultRoot "logs"
$AnalysisLogFile = Join-Path $LogsDir "analysis-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$RedactionsFile = Join-Path $ReportsDir "redactions.log"
$TokeiPath = Join-Path $ScriptsDir "tokei.exe"

# ZAR hourly rates
$RateLow = 450
$RateMid = 750
$RateHigh = 1200

# Ensure directories exist
foreach ($dir in @($ReportsDir, $LogsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Start-Transcript -Path $AnalysisLogFile -Append

Write-Host "=== Repository Analysis ===" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Redaction tracking
$script:redactions = @()

function Test-SecretPattern {
    param([string]$Text)

    $patterns = @(
        'sk_live_',
        'sk_test_',
        'ghp_',
        'github_pat_',
        'AKIA',
        '-----BEGIN',
        'Bearer '
    )

    foreach ($pattern in $patterns) {
        if ($Text -like "*$pattern*") {
            return $true
        }
    }

    return $false
}

function Invoke-Redaction {
    param([string]$Text, [string]$Context)

    if (Test-SecretPattern -Text $Text) {
        $script:redactions += [PSCustomObject]@{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Context = $Context
            OriginalLength = $Text.Length
        }
        return "[REDACTED]"
    }

    return $Text
}

function Get-RepoMetrics {
    param([string]$RepoPath, [string]$AccountType)

    $repoName = Split-Path $RepoPath -Leaf
    $parts = $repoName -split '__'
    if ($parts.Count -eq 2) {
        $owner = $parts[0]
        $repo = $parts[1]
    } else {
        $owner = "Unknown"
        $repo = $repoName
    }

    Write-Host "  Analyzing: $owner/$repo" -NoNewline

    $metrics = [PSCustomObject]@{
        AccountType = $AccountType
        Owner = $owner
        Repo = $repo
        Visibility = "unknown"
        FirstCommit = $null
        LastCommit = $null
        CommitCount = 0
        CommitsByYear = @{}
        LocTotal = 0
        LocByLanguage = @{}
        HasTests = $false
        HasCI = $false
        HasDocs = $false
        ReleaseCount = 0
        SizeOnDisk = 0
        FileCount = 0
        ProofScore = 0
        EstimatedHoursLow = 0
        EstimatedHoursMid = 0
        EstimatedHoursHigh = 0
        ValueLow = 0
        ValueMid = 0
        ValueHigh = 0
    }

    # Git metrics
    try {
        # Check if it's a valid git repo
        $isGitRepo = Test-Path (Join-Path $RepoPath ".git")
        if (-not $isGitRepo) {
            Write-Host " [NOT_GIT_REPO]" -ForegroundColor Yellow
            return $metrics
        }

        # Commit count
        $commitCountStr = git -C $RepoPath rev-list --count HEAD 2>&1
        if ($LASTEXITCODE -eq 0) {
            $metrics.CommitCount = [int]$commitCountStr
        }

        # First commit date
        $firstCommitStr = git -C $RepoPath log --reverse --format=%ci --date=iso 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and $firstCommitStr) {
            try {
                $metrics.FirstCommit = [DateTime]::Parse($firstCommitStr)
            } catch {}
        }

        # Last commit date
        $lastCommitStr = git -C $RepoPath log -1 --format=%ci --date=iso 2>&1
        if ($LASTEXITCODE -eq 0 -and $lastCommitStr) {
            try {
                $metrics.LastCommit = [DateTime]::Parse($lastCommitStr)
            } catch {}
        }

        # Commits by year
        $commitYears = git -C $RepoPath log --format=%ad --date=format:%Y 2>&1
        if ($LASTEXITCODE -eq 0) {
            $yearGroups = $commitYears | Group-Object
            foreach ($group in $yearGroups) {
                $metrics.CommitsByYear[$group.Name] = $group.Count
            }
        }

        # Tag/release count
        $tagCount = git -C $RepoPath tag 2>&1 | Measure-Object | Select-Object -ExpandProperty Count
        if ($LASTEXITCODE -eq 0) {
            $metrics.ReleaseCount = $tagCount
        }

    } catch {
        Write-Host " [GIT_ERROR]" -ForegroundColor Red
    }

    # LOC metrics using tokei
    try {
        $ErrorActionPreference = 'Continue'
        $tokeiJson = & $TokeiPath $RepoPath --output json 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0) {
            $tokeiData = $tokeiJson | ConvertFrom-Json

            # Tokei output structure varies, handle both old and new formats
            $totalLoc = 0
            $locByLang = @{}

            foreach ($prop in $tokeiData.PSObject.Properties) {
                $langName = $prop.Name
                if ($langName -eq 'Total') { continue }

                $langData = $prop.Value
                if ($langData.code) {
                    $code = $langData.code
                    $totalLoc += $code
                    $locByLang[$langName] = $code
                }
            }

            $metrics.LocTotal = $totalLoc
            $metrics.LocByLanguage = $locByLang
        }
    } catch {
        Write-Host " [TOKEI_ERROR]" -ForegroundColor Yellow
    }

    # Detect tests
    $testPatterns = @(
        "test", "tests", "__tests__", "spec", "specs",
        "*test*.js", "*test*.ts", "*test*.py", "*test*.cs",
        "*spec*.js", "*spec*.ts"
    )

    foreach ($pattern in $testPatterns) {
        $testPath = Join-Path $RepoPath $pattern
        if (Test-Path $testPath) {
            $metrics.HasTests = $true
            break
        }
    }

    # Detect CI
    $ciPaths = @(
        ".github\workflows",
        ".gitlab-ci.yml",
        ".travis.yml",
        "azure-pipelines.yml",
        ".circleci",
        "Jenkinsfile"
    )

    foreach ($ciPath in $ciPaths) {
        $fullCiPath = Join-Path $RepoPath $ciPath
        if (Test-Path $fullCiPath) {
            $metrics.HasCI = $true
            break
        }
    }

    # Detect docs
    $docPaths = @(
        "README.md", "README.rst", "README.txt", "README",
        "docs", "doc", "documentation",
        "CONTRIBUTING.md", "ARCHITECTURE.md"
    )

    foreach ($docPath in $docPaths) {
        $fullDocPath = Join-Path $RepoPath $docPath
        if (Test-Path $fullDocPath) {
            $metrics.HasDocs = $true
            break
        }
    }

    # Size on disk
    try {
        $size = (Get-ChildItem -Path $RepoPath -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.PSIsContainer } |
                 Measure-Object -Property Length -Sum).Sum
        $metrics.SizeOnDisk = [math]::Round($size / 1MB, 2)
    } catch {}

    # File count
    try {
        $fileCount = (Get-ChildItem -Path $RepoPath -Recurse -File -Force -ErrorAction SilentlyContinue |
                      Measure-Object).Count
        $metrics.FileCount = $fileCount
    } catch {}

    # Calculate proof score (0-100)
    $score = 0

    # LOC component (0-30): logarithmic scale
    if ($metrics.LocTotal -gt 0) {
        $locScore = [Math]::Min(30, [Math]::Log10($metrics.LocTotal + 1) * 6)
        $score += $locScore
    }

    # Tests (0-15)
    if ($metrics.HasTests) {
        $score += 15
    }

    # CI (0-10)
    if ($metrics.HasCI) {
        $score += 10
    }

    # Docs (0-10)
    if ($metrics.HasDocs) {
        $score += 10
    }

    # Multi-year activity (0-15)
    $yearsActive = $metrics.CommitsByYear.Count
    if ($yearsActive -gt 0) {
        $yearScore = [Math]::Min(15, $yearsActive * 3)
        $score += $yearScore
    }

    # Complexity (0-10): based on file count
    if ($metrics.FileCount -gt 0) {
        $complexityScore = [Math]::Min(10, [Math]::Log10($metrics.FileCount + 1) * 3)
        $score += $complexityScore
    }

    # Releases (0-10)
    if ($metrics.ReleaseCount -gt 0) {
        $releaseScore = [Math]::Min(10, $metrics.ReleaseCount * 2)
        $score += $releaseScore
    }

    $metrics.ProofScore = [Math]::Round($score, 1)

    # Calculate estimated hours
    $baseHours = [Math]::Min(1200, $metrics.LocTotal / 50)

    # Quality factor based on proof score (0.70 to 1.40)
    $qualityFactor = 0.70 + ($metrics.ProofScore / 100) * 0.70

    $estimatedHours = $baseHours * $qualityFactor

    $metrics.EstimatedHoursLow = [Math]::Round($estimatedHours, 1)
    $metrics.EstimatedHoursMid = [Math]::Round($estimatedHours, 1)
    $metrics.EstimatedHoursHigh = [Math]::Round($estimatedHours, 1)

    # Calculate values in ZAR
    $metrics.ValueLow = [Math]::Round($metrics.EstimatedHoursLow * $RateLow, 0)
    $metrics.ValueMid = [Math]::Round($metrics.EstimatedHoursMid * $RateMid, 0)
    $metrics.ValueHigh = [Math]::Round($metrics.EstimatedHoursHigh * $RateHigh, 0)

    Write-Host " [OK]" -ForegroundColor Green

    return $metrics
}

# Collect all repos
Write-Host "Discovering repositories..." -ForegroundColor Cyan

$allRepos = @()

# Personal repos
$personalPath = Join-Path $ReposRoot "personal"
if (Test-Path $personalPath) {
    $personalRepos = Get-ChildItem -Path $personalPath -Directory
    Write-Host "  Personal: $($personalRepos.Count) repos" -ForegroundColor Gray
    foreach ($repo in $personalRepos) {
        $allRepos += @{
            Path = $repo.FullName
            AccountType = "Personal"
        }
    }
}

# Work repos
$workPath = Join-Path $ReposRoot "work"
if (Test-Path $workPath) {
    $workRepos = Get-ChildItem -Path $workPath -Directory
    Write-Host "  Work: $($workRepos.Count) repos" -ForegroundColor Gray
    foreach ($repo in $workRepos) {
        $allRepos += @{
            Path = $repo.FullName
            AccountType = "Work"
        }
    }
}

Write-Host "Total repos to analyze: $($allRepos.Count)" -ForegroundColor Cyan
Write-Host ""

# Analyze all repos
$allMetrics = @()
$current = 0

foreach ($repoInfo in $allRepos) {
    $current++
    Write-Host "[$current/$($allRepos.Count)]" -NoNewline -ForegroundColor Gray
    $metrics = Get-RepoMetrics -RepoPath $repoInfo.Path -AccountType $repoInfo.AccountType
    $allMetrics += $metrics
}

Write-Host ""
Write-Host "Analysis complete. Generating reports..." -ForegroundColor Cyan
Write-Host ""

# Generate CSV report
$csvFile = Join-Path $ReportsDir "inventory.csv"
$allMetrics | Select-Object AccountType, Owner, Repo, CommitCount, LocTotal, FirstCommit, LastCommit, HasTests, HasCI, HasDocs, ProofScore, ValueMid |
    Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

Write-Host "Generated: inventory.csv" -ForegroundColor Green

# Generate inventory markdown
$mdLines = @()
$mdLines += "# Repository Inventory"
$mdLines += ""
$mdLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$mdLines += ""
$mdLines += "## Summary"
$mdLines += ""
$mdLines += "- **Total Repositories:** $($allMetrics.Count)"
$mdLines += "- **Total Commits:** $(($allMetrics | Measure-Object -Property CommitCount -Sum).Sum)"
$mdLines += "- **Total LOC:** $(($allMetrics | Measure-Object -Property LocTotal -Sum).Sum)"
$mdLines += ""

# Top repos by value
$mdLines += "## Top 10 Repositories by Value (Mid-tier)"
$mdLines += ""
$mdLines += "| Rank | Owner | Repo | LOC | Commits | Proof Score | Value (ZAR) |"
$mdLines += "|------|-------|------|-----|---------|-------------|-------------|"

$topByValue = $allMetrics | Sort-Object ValueMid -Descending | Select-Object -First 10
$rank = 1
foreach ($repo in $topByValue) {
    $mdLines += "| $rank | $($repo.Owner) | $($repo.Repo) | $($repo.LocTotal) | $($repo.CommitCount) | $($repo.ProofScore) | R $($repo.ValueMid.ToString('N0')) |"
    $rank++
}
$mdLines += ""

# Top repos by activity
$mdLines += "## Top 10 Repositories by Commit Count"
$mdLines += ""
$mdLines += "| Rank | Owner | Repo | Commits | Years Active | Proof Score |"
$mdLines += "|------|-------|------|---------|--------------|-------------|"

$topByCommits = $allMetrics | Sort-Object CommitCount -Descending | Select-Object -First 10
$rank = 1
foreach ($repo in $topByCommits) {
    $yearsActive = $repo.CommitsByYear.Count
    $mdLines += "| $rank | $($repo.Owner) | $($repo.Repo) | $($repo.CommitCount) | $yearsActive | $($repo.ProofScore) |"
    $rank++
}
$mdLines += ""

# Top repos by engineering maturity
$mdLines += "## Top 10 Repositories by Engineering Maturity"
$mdLines += ""
$mdLines += "| Rank | Owner | Repo | Tests | CI | Docs | Proof Score |"
$mdLines += "|------|-------|------|-------|----|----- |-------------|"

$topByMaturity = $allMetrics | Sort-Object ProofScore -Descending | Select-Object -First 10
$rank = 1
foreach ($repo in $topByMaturity) {
    $tests = if ($repo.HasTests) { "Yes" } else { "" }
    $ci = if ($repo.HasCI) { "Yes" } else { "" }
    $docs = if ($repo.HasDocs) { "Yes" } else { "" }
    $mdLines += "| $rank | $($repo.Owner) | $($repo.Repo) | $tests | $ci | $docs | $($repo.ProofScore) |"
    $rank++
}
$mdLines += ""

$mdFile = Join-Path $ReportsDir "inventory.md"
$mdLines | Set-Content -Path $mdFile -Encoding UTF8

Write-Host "Generated: inventory.md" -ForegroundColor Green

# Generate proof-of-work report
$powLines = @()
$powLines += "# Proof of Work Report"
$powLines += ""
$powLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$powLines += ""
$powLines += "## Overview"
$powLines += ""
$powLines += "This report demonstrates sustained software engineering work across multiple repositories and organizations."
$powLines += ""

# Activity timeline
$allYears = @{}
foreach ($repo in $allMetrics) {
    foreach ($year in $repo.CommitsByYear.Keys) {
        if (-not $allYears.ContainsKey($year)) {
            $allYears[$year] = 0
        }
        $allYears[$year] += $repo.CommitsByYear[$year]
    }
}

$powLines += "## Activity Timeline"
$powLines += ""
$powLines += "| Year | Commits |"
$powLines += "|------|---------|"
foreach ($year in ($allYears.Keys | Sort-Object)) {
    $powLines += "| $year | $($allYears[$year]) |"
}
$powLines += ""

# Signature work
$powLines += "## Signature Work (High-Value Repositories)"
$powLines += ""
$powLines += "Repositories demonstrating substantial engineering effort, automation, or tooling development."
$powLines += ""

$signatureRepos = $allMetrics |
    Where-Object { $_.ProofScore -ge 50 -or $_.LocTotal -ge 5000 -or $_.CommitCount -ge 100 } |
    Sort-Object ProofScore -Descending |
    Select-Object -First 20

foreach ($repo in $signatureRepos) {
    $powLines += "### $($repo.Owner)/$($repo.Repo)"
    $powLines += ""
    $powLines += "- **LOC:** $($repo.LocTotal)"
    $powLines += "- **Commits:** $($repo.CommitCount)"
    $powLines += "- **Active Years:** $($repo.CommitsByYear.Count)"
    $powLines += "- **First Commit:** $($repo.FirstCommit)"
    $powLines += "- **Last Commit:** $($repo.LastCommit)"
    $powLines += "- **Tests:** $(if ($repo.HasTests) { 'Yes' } else { 'No' })"
    $powLines += "- **CI/CD:** $(if ($repo.HasCI) { 'Yes' } else { 'No' })"
    $powLines += "- **Documentation:** $(if ($repo.HasDocs) { 'Yes' } else { 'No' })"
    $powLines += "- **Proof Score:** $($repo.ProofScore)/100"
    $powLines += ""
}

$powFile = Join-Path $ReportsDir "proof-of-work.md"
$powLines | Set-Content -Path $powFile -Encoding UTF8

Write-Host "Generated: proof-of-work.md" -ForegroundColor Green

# Generate value estimate report
$valueLines = @()
$valueLines += "# Portfolio Value Estimate"
$valueLines += ""
$valueLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$valueLines += ""
$valueLines += "## Methodology"
$valueLines += ""
$valueLines += "This estimate calculates the replacement cost of the entire repository portfolio using South African Rand (ZAR) hourly rates."
$valueLines += ""
$valueLines += "### Hourly Rates"
$valueLines += ""
$valueLines += "- **Low tier:** R$($RateLow)/hour"
$valueLines += "- **Mid tier:** R$($RateMid)/hour"
$valueLines += "- **High tier:** R$($RateHigh)/hour"
$valueLines += ""
$valueLines += "### Calculation Method"
$valueLines += ""
$valueLines += "1. **Base Hours** = min(LOC / 50, 1200)"
$valueLines += "2. **Quality Factor** = 0.70 + (ProofScore / 100) × 0.70"
$valueLines += "3. **Estimated Hours** = BaseHours × QualityFactor"
$valueLines += "4. **Value** = EstimatedHours × HourlyRate"
$valueLines += ""
$valueLines += "### Proof Score Components (0-100)"
$valueLines += ""
$valueLines += "- LOC (logarithmic): 0-30 points"
$valueLines += "- Tests present: 0-15 points"
$valueLines += "- CI/CD present: 0-10 points"
$valueLines += "- Documentation: 0-10 points"
$valueLines += "- Multi-year activity: 0-15 points"
$valueLines += "- Complexity (files): 0-10 points"
$valueLines += "- Releases/tags: 0-10 points"
$valueLines += ""

# Portfolio totals
$totalValueLow = ($allMetrics | Measure-Object -Property ValueLow -Sum).Sum
$totalValueMid = ($allMetrics | Measure-Object -Property ValueMid -Sum).Sum
$totalValueHigh = ($allMetrics | Measure-Object -Property ValueHigh -Sum).Sum

$valueLines += "## Portfolio Value Summary"
$valueLines += ""
$valueLines += "| Tier | Total Value (ZAR) |"
$valueLines += "|------|-------------------|"
$valueLines += "| Low | R $($totalValueLow.ToString('N0')) |"
$valueLines += "| Mid | R $($totalValueMid.ToString('N0')) |"
$valueLines += "| High | R $($totalValueHigh.ToString('N0')) |"
$valueLines += ""

$valueLines += "## Breakdown by Repository"
$valueLines += ""
$valueLines += "Top 20 repositories by mid-tier value:"
$valueLines += ""
$valueLines += "| Rank | Owner | Repo | LOC | Commits | Proof | Hours | Value (Mid) |"
$valueLines += "|------|-------|------|-----|---------|-------|-------|-------------|"

$topValueRepos = $allMetrics | Sort-Object ValueMid -Descending | Select-Object -First 20
$rank = 1
foreach ($repo in $topValueRepos) {
    $valueLines += "| $rank | $($repo.Owner) | $($repo.Repo) | $($repo.LocTotal) | $($repo.CommitCount) | $($repo.ProofScore) | $($repo.EstimatedHoursMid) | R $($repo.ValueMid.ToString('N0')) |"
    $rank++
}
$valueLines += ""

$valueFile = Join-Path $ReportsDir "value-estimate.md"
$valueLines | Set-Content -Path $valueFile -Encoding UTF8

Write-Host "Generated: value-estimate.md" -ForegroundColor Green

# Save redactions log
if ($script:redactions.Count -gt 0) {
    $redactLines = @()
    $redactLines += "# Redactions Log"
    $redactLines += ""
    $redactLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $redactLines += ""
    $redactLines += "Total redactions: $($script:redactions.Count)"
    $redactLines += ""
    $redactLines += "| Timestamp | Context | Original Length |"
    $redactLines += "|-----------|---------|-----------------|"
    foreach ($redaction in $script:redactions) {
        $redactLines += "| $($redaction.Timestamp) | $($redaction.Context) | $($redaction.OriginalLength) |"
    }
    $redactLines += ""

    $redactLines | Set-Content -Path $RedactionsFile -Encoding UTF8
    Write-Host "Generated: redactions.log ($($script:redactions.Count) redactions)" -ForegroundColor Yellow
} else {
    "No secrets detected." | Set-Content -Path $RedactionsFile -Encoding UTF8
    Write-Host "Generated: redactions.log (no secrets detected)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Reports generated in: $ReportsDir" -ForegroundColor Cyan
Write-Host "  - inventory.csv" -ForegroundColor Gray
Write-Host "  - inventory.md" -ForegroundColor Gray
Write-Host "  - proof-of-work.md" -ForegroundColor Gray
Write-Host "  - value-estimate.md" -ForegroundColor Gray
Write-Host "  - redactions.log" -ForegroundColor Gray
Write-Host ""
Write-Host "Portfolio Value (ZAR):" -ForegroundColor Cyan
Write-Host "  Low:  R $($totalValueLow.ToString('N0'))" -ForegroundColor Gray
Write-Host "  Mid:  R $($totalValueMid.ToString('N0'))" -ForegroundColor Gray
Write-Host "  High: R $($totalValueHigh.ToString('N0'))" -ForegroundColor Gray
Write-Host ""

Stop-Transcript

exit 0
