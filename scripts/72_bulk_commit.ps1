#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk commit LICENSE and CHANGELOG files
.DESCRIPTION
    Commits LICENSE and CHANGELOG files across all repositories
.PARAMETER Message
    Custom commit message (optional)
.PARAMETER DryRun
    Show what would be committed without making changes
#>

param(
    [string]$Message = "Add LICENSE and CHANGELOG for professional baseline",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ReposRoot = "F:\VaultRepo\_repos"

Write-Host "=== Bulk Commit Changes ===" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No commits will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Discover all repositories
$allRepos = @()

# Personal repos
$personalPath = Join-Path $ReposRoot "personal"
if (Test-Path $personalPath) {
    $personalRepos = Get-ChildItem -Path $personalPath -Directory
    foreach ($repo in $personalRepos) {
        $parts = $repo.Name -split '__'
        if ($parts.Count -eq 2) {
            $allRepos += @{
                Path = $repo.FullName
                Owner = $parts[0]
                Name = $parts[1]
            }
        }
    }
}

# Work repos
$workPath = Join-Path $ReposRoot "work"
if (Test-Path $workPath) {
    $workRepos = Get-ChildItem -Path $workPath -Directory
    foreach ($repo in $workRepos) {
        $parts = $repo.Name -split '__'
        if ($parts.Count -eq 2) {
            $allRepos += @{
                Path = $repo.FullName
                Owner = $parts[0]
                Name = $parts[1]
            }
        }
    }
}

Write-Host "Scanning $($allRepos.Count) repositories for changes..." -ForegroundColor Gray
Write-Host ""

# Process repositories
$committed = 0
$noChanges = 0
$errors = 0

foreach ($repoInfo in $allRepos) {
    $repoPath = $repoInfo.Path

    # Check if it's a git repo
    $gitPath = Join-Path $repoPath ".git"
    if (-not (Test-Path $gitPath)) {
        continue
    }

    # Check for changes
    try {
        $status = git -C $repoPath status --porcelain 2>&1

        if (-not $status -or $status.Length -eq 0) {
            # No changes
            $noChanges++
            continue
        }

        # Has changes
        $changedFiles = @($status -split "`n" | ForEach-Object { $_.Trim() })

        # Check if LICENSE or CHANGELOG are in the changes
        $hasLicenseChange = $changedFiles | Where-Object { $_ -match 'LICENSE' }
        $hasChangelogChange = $changedFiles | Where-Object { $_ -match 'CHANGELOG' }

        if (-not $hasLicenseChange -and -not $hasChangelogChange) {
            # Changes exist but not LICENSE/CHANGELOG
            continue
        }

        if ($DryRun) {
            Write-Host "  [DRY RUN] Would commit: $($repoInfo.Owner)/$($repoInfo.Name)" -ForegroundColor Cyan
            Write-Host "    Changes: $($changedFiles.Count) files" -ForegroundColor Gray
            $committed++
        } else {
            # Stage LICENSE and CHANGELOG only
            if ($hasLicenseChange) {
                git -C $repoPath add LICENSE 2>&1 | Out-Null
            }
            if ($hasChangelogChange) {
                git -C $repoPath add CHANGELOG.md 2>&1 | Out-Null
            }

            # Commit
            git -C $repoPath commit -m $Message 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  COMMITTED: $($repoInfo.Owner)/$($repoInfo.Name)" -ForegroundColor Green
                $committed++
            } else {
                Write-Host "  ERROR: $($repoInfo.Owner)/$($repoInfo.Name) - Commit failed" -ForegroundColor Red
                $errors++
            }
        }

    } catch {
        Write-Host "  ERROR: $($repoInfo.Owner)/$($repoInfo.Name) - $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Committed: $committed" -ForegroundColor Green
Write-Host "  No changes: $noChanges" -ForegroundColor Gray
Write-Host "  Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($DryRun) {
    Write-Host "This was a dry run. Run without -DryRun to commit changes." -ForegroundColor Yellow
} else {
    Write-Host "Commits complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Push changes to remote: Run bulk push script" -ForegroundColor Gray
    Write-Host "2. Verify changes on GitHub" -ForegroundColor Gray
}

Write-Host ""
exit 0
