#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced repository analysis with strategic portfolio intelligence
.DESCRIPTION
    Generates comprehensive portfolio reports with:
    - 3-bucket classification (Production/Tooling/R&D)
    - 7-dimensional scoring system
    - Theme clustering
    - Option Value (OV) calculation
    - Time-Saved Value (TSV) modeling
#>

param()

$ErrorActionPreference = 'Stop'

$VaultRoot = "F:\VaultRepo\vault"
$ReposRoot = "F:\VaultRepo\_repos"
$ScriptsDir = Join-Path $VaultRoot "scripts"
$ReportsDir = Join-Path $VaultRoot "reports"
$LogsDir = Join-Path $VaultRoot "logs"
$AnalysisLogFile = Join-Path $LogsDir "analysis-enhanced-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

Write-Host "=== Enhanced Portfolio Analysis ===" -ForegroundColor Cyan
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

function Get-RepoThemes {
    param([string]$RepoPath, [string]$RepoName, [hashtable]$LocByLanguage)

    $themes = @()
    $repoLower = $RepoName.ToLower()

    # Simulation theme
    $simKeywords = @('sim', 'simulation', 'pilot', 'virtual', 'digital-twin', 'twin', 'process')
    foreach ($keyword in $simKeywords) {
        if ($repoLower -match $keyword) {
            $themes += 'Simulation'
            break
        }
    }

    # Virtual Commissioning theme
    $vcKeywords = @('commission', 'factoryscope', 'autofactory', 'virtual-commission')
    foreach ($keyword in $vcKeywords) {
        if ($repoLower -match $keyword) {
            $themes += 'Virtual-Commissioning'
            break
        }
    }

    # PLC/Control theme
    $plcKeywords = @('plc', 'logix', 'siemens', 'fanuc', 'kawasaki', 'abb', 'control', 'ladder', 'structured-text')
    foreach ($keyword in $plcKeywords) {
        if ($repoLower -match $keyword) {
            $themes += 'PLC-Controls'
            break
        }
    }

    # Robotics theme
    $robotKeywords = @('robot', 'fanuc', 'kawasaki', 'abb', 'kuka', 'motoman', 'oilp', 'olp')
    foreach ($keyword in $robotKeywords) {
        if ($repoLower -match $keyword) {
            $themes += 'Robotics'
            break
        }
    }

    # Database/Oracle theme
    $dbKeywords = @('database', 'oracle', 'sql', 'db', 'data')
    foreach ($keyword in $dbKeywords) {
        if ($repoLower -match $keyword) {
            $themes += 'Database-Oracle'
            break
        }
    }

    # Web tooling theme
    if ($LocByLanguage.ContainsKey('TypeScript') -or
        $LocByLanguage.ContainsKey('JavaScript') -or
        $LocByLanguage.ContainsKey('JSX') -or
        $LocByLanguage.ContainsKey('TSX')) {
        $themes += 'Web-Tooling'
    }

    # DevOps theme
    $devopsKeywords = @('ci', 'cd', 'deploy', 'docker', 'kubernetes', 'github-actions')
    foreach ($keyword in $devopsKeywords) {
        if ($repoLower -match $keyword) {
            $themes += 'DevOps'
            break
        }
    }

    return $themes
}

function Get-RepoClassification {
    param(
        [int]$CommitCount,
        [int]$YearsActive,
        [bool]$HasTests,
        [bool]$HasCI,
        [int]$ProofScore,
        [string[]]$Themes
    )

    # Production/Mature Tools: high proof score, multi-year, tests, CI
    if ($ProofScore -ge 65 -and $YearsActive -ge 2 -and $HasTests -and $HasCI) {
        return 'Production'
    }

    # Internal Tooling: moderate proof, some activity, utility-focused
    if ($ProofScore -ge 40 -and $CommitCount -ge 10) {
        return 'Tooling'
    }

    # R&D/Idea Seeds: lower proof, newer, exploratory
    return 'R&D'
}

function Get-7DimensionalScore {
    param(
        [string]$Classification,
        [string[]]$Themes,
        [int]$LocTotal,
        [int]$CommitCount,
        [int]$YearsActive,
        [bool]$HasTests,
        [bool]$HasCI,
        [bool]$HasDocs,
        [int]$ProofScore,
        [hashtable]$LocByLanguage
    )

    $scores = @{
        Originality = 0
        DomainRarity = 0
        EngineeringDepth = 0
        Maturity = 0
        Utility = 0
        Traction = 0
        IdeaStrength = 0
        Risk = 0
    }

    # 1. Originality (0-20): based on uniqueness of themes and domain
    if ($Themes -contains 'Simulation' -or $Themes -contains 'Virtual-Commissioning') {
        $scores.Originality += 15
    }
    if ($Themes -contains 'PLC-Controls' -or $Themes -contains 'Robotics') {
        $scores.Originality += 10
    }
    if ($Themes.Count -ge 3) {
        $scores.Originality += 5
    }
    $scores.Originality = [Math]::Min(20, $scores.Originality)

    # 2. Domain Rarity (0-15): niche specialization
    if ($Themes -contains 'Virtual-Commissioning') {
        $scores.DomainRarity += 15
    } elseif ($Themes -contains 'Simulation' -or $Themes -contains 'Robotics') {
        $scores.DomainRarity += 10
    } elseif ($Themes -contains 'PLC-Controls') {
        $scores.DomainRarity += 8
    } else {
        $scores.DomainRarity += 3
    }
    $scores.DomainRarity = [Math]::Min(15, $scores.DomainRarity)

    # 3. Engineering Depth (0-25): LOC, complexity, language diversity
    $locScore = [Math]::Min(15, [Math]::Log10($LocTotal + 1) * 3)
    $langDiversity = [Math]::Min(5, $LocByLanguage.Count * 1.5)
    $testScore = if ($HasTests) { 5 } else { 0 }
    $scores.EngineeringDepth = [Math]::Round($locScore + $langDiversity + $testScore, 1)

    # 4. Maturity (0-20): years, commits, CI/CD, docs
    $yearScore = [Math]::Min(8, $YearsActive * 2)
    $commitScore = [Math]::Min(7, [Math]::Log10($CommitCount + 1) * 3)
    $ciScore = if ($HasCI) { 3 } else { 0 }
    $docScore = if ($HasDocs) { 2 } else { 0 }
    $scores.Maturity = [Math]::Round($yearScore + $commitScore + $ciScore + $docScore, 1)

    # 5. Utility (0-15): practical value based on classification
    if ($Classification -eq 'Production') {
        $scores.Utility = 15
    } elseif ($Classification -eq 'Tooling') {
        $scores.Utility = 10
    } else {
        $scores.Utility = 5
    }

    # 6. Traction (0-10): commit velocity and sustained activity
    if ($YearsActive -gt 0) {
        $commitVelocity = $CommitCount / $YearsActive
        $tractionScore = [Math]::Min(10, [Math]::Log10($commitVelocity + 1) * 4)
        $scores.Traction = [Math]::Round($tractionScore, 1)
    }

    # 7. Idea Strength (0-15): for R&D repos, higher originality and domain rarity
    if ($Classification -eq 'R&D') {
        $ideaScore = ($scores.Originality * 0.5) + ($scores.DomainRarity * 0.7)
        $scores.IdeaStrength = [Math]::Round([Math]::Min(15, $ideaScore), 1)
    } else {
        $scores.IdeaStrength = [Math]::Round($scores.Originality * 0.3, 1)
    }

    # Risk penalty (0-20): lack of tests, CI, docs, low commits
    $riskPenalty = 0
    if (-not $HasTests) { $riskPenalty += 6 }
    if (-not $HasCI) { $riskPenalty += 4 }
    if (-not $HasDocs) { $riskPenalty += 3 }
    if ($CommitCount -lt 10) { $riskPenalty += 5 }
    if ($YearsActive -eq 0) { $riskPenalty += 2 }
    $scores.Risk = [Math]::Min(20, $riskPenalty)

    # Total score (max 120, minus risk)
    $totalScore = $scores.Originality + $scores.DomainRarity + $scores.EngineeringDepth +
                  $scores.Maturity + $scores.Utility + $scores.Traction + $scores.IdeaStrength - $scores.Risk

    $scores.Total = [Math]::Max(0, [Math]::Round($totalScore, 1))

    return $scores
}

function Get-OptionValue {
    param(
        [string]$Classification,
        [double]$ReplacementCost,
        [string[]]$Themes,
        [double]$SevenDimScore
    )

    # Base multiplier by classification
    $baseMultiplier = switch ($Classification) {
        'Production' { 2.5 }
        'Tooling' { 1.5 }
        'R&D' { 3.0 }
        default { 1.0 }
    }

    # Theme bonus
    $themeBonus = 1.0
    if ($Themes -contains 'Virtual-Commissioning') { $themeBonus += 0.5 }
    if ($Themes -contains 'Simulation') { $themeBonus += 0.3 }
    if ($Themes -contains 'Robotics') { $themeBonus += 0.2 }
    if ($Themes -contains 'PLC-Controls') { $themeBonus += 0.2 }

    # Quality multiplier based on 7D score (normalized to 0-1 scale)
    $qualityMultiplier = 1.0 + ($SevenDimScore / 120) * 0.5

    $optionValue = $ReplacementCost * $baseMultiplier * $themeBonus * $qualityMultiplier

    return [Math]::Round($optionValue, 0)
}

function Get-TimeSavedValue {
    param(
        [string]$Classification,
        [int]$LocTotal,
        [int]$CommitCount,
        [bool]$HasTests,
        [string[]]$Themes
    )

    # Base time-saved estimate (hours)
    $baseSaved = 0

    if ($Classification -eq 'Production') {
        # Production tools save significant ongoing time
        $baseSaved = [Math]::Min(2000, $LocTotal / 20)
    } elseif ($Classification -eq 'Tooling') {
        # Internal tooling saves moderate time
        $baseSaved = [Math]::Min(1000, $LocTotal / 30)
    } else {
        # R&D represents learning/exploration value
        $baseSaved = [Math]::Min(500, $LocTotal / 50)
    }

    # Automation multiplier
    $autoMultiplier = 1.0
    if ($Themes -contains 'Virtual-Commissioning') { $autoMultiplier = 3.0 }
    elseif ($Themes -contains 'Simulation') { $autoMultiplier = 2.5 }
    elseif ($Themes -contains 'DevOps') { $autoMultiplier = 2.0 }
    elseif ($Themes -contains 'Robotics' -or $Themes -contains 'PLC-Controls') { $autoMultiplier = 1.8 }

    # Quality factor
    $qualityFactor = 1.0
    if ($HasTests) { $qualityFactor += 0.3 }
    if ($CommitCount -gt 100) { $qualityFactor += 0.2 }

    $totalSaved = $baseSaved * $autoMultiplier * $qualityFactor
    $tsvValue = $totalSaved * $RateMid

    return @{
        HoursSaved = [Math]::Round($totalSaved, 1)
        TsvValue = [Math]::Round($tsvValue, 0)
    }
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
        Themes = @()
        Classification = ""
        SevenDimScores = @{}
        SevenDimTotal = 0
        EstimatedHoursLow = 0
        EstimatedHoursMid = 0
        EstimatedHoursHigh = 0
        ReplacementCostLow = 0
        ReplacementCostMid = 0
        ReplacementCostHigh = 0
        OptionValueMid = 0
        HoursSaved = 0
        TsvValue = 0
        TotalValueMid = 0
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

    # Get themes
    $metrics.Themes = Get-RepoThemes -RepoPath $RepoPath -RepoName $repo -LocByLanguage $metrics.LocByLanguage

    # Get classification
    $metrics.Classification = Get-RepoClassification `
        -CommitCount $metrics.CommitCount `
        -YearsActive $yearsActive `
        -HasTests $metrics.HasTests `
        -HasCI $metrics.HasCI `
        -ProofScore $metrics.ProofScore `
        -Themes $metrics.Themes

    # Get 7-dimensional scores
    $metrics.SevenDimScores = Get-7DimensionalScore `
        -Classification $metrics.Classification `
        -Themes $metrics.Themes `
        -LocTotal $metrics.LocTotal `
        -CommitCount $metrics.CommitCount `
        -YearsActive $yearsActive `
        -HasTests $metrics.HasTests `
        -HasCI $metrics.HasCI `
        -HasDocs $metrics.HasDocs `
        -ProofScore $metrics.ProofScore `
        -LocByLanguage $metrics.LocByLanguage

    $metrics.SevenDimTotal = $metrics.SevenDimScores.Total

    # Calculate replacement cost (RC)
    $baseHours = [Math]::Min(1200, $metrics.LocTotal / 50)
    $qualityFactor = 0.70 + ($metrics.ProofScore / 100) * 0.70
    $estimatedHours = $baseHours * $qualityFactor

    $metrics.EstimatedHoursLow = [Math]::Round($estimatedHours, 1)
    $metrics.EstimatedHoursMid = [Math]::Round($estimatedHours, 1)
    $metrics.EstimatedHoursHigh = [Math]::Round($estimatedHours, 1)

    $metrics.ReplacementCostLow = [Math]::Round($metrics.EstimatedHoursLow * $RateLow, 0)
    $metrics.ReplacementCostMid = [Math]::Round($metrics.EstimatedHoursMid * $RateMid, 0)
    $metrics.ReplacementCostHigh = [Math]::Round($metrics.EstimatedHoursHigh * $RateHigh, 0)

    # Calculate option value (OV)
    $metrics.OptionValueMid = Get-OptionValue `
        -Classification $metrics.Classification `
        -ReplacementCost $metrics.ReplacementCostMid `
        -Themes $metrics.Themes `
        -SevenDimScore $metrics.SevenDimTotal

    # Calculate time-saved value (TSV)
    $tsvResult = Get-TimeSavedValue `
        -Classification $metrics.Classification `
        -LocTotal $metrics.LocTotal `
        -CommitCount $metrics.CommitCount `
        -HasTests $metrics.HasTests `
        -Themes $metrics.Themes

    $metrics.HoursSaved = $tsvResult.HoursSaved
    $metrics.TsvValue = $tsvResult.TsvValue

    # Total value
    $metrics.TotalValueMid = $metrics.ReplacementCostMid + $metrics.OptionValueMid + $metrics.TsvValue

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

# Generate enhanced reports
. (Join-Path $ScriptsDir "31_generate_reports.ps1") -AllMetrics $allMetrics -ReportsDir $ReportsDir

Write-Host ""
Write-Host "=== Enhanced Analysis Complete ===" -ForegroundColor Green
Write-Host ""

Stop-Transcript

exit 0
