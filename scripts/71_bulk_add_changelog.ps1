#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk add CHANGELOG.md files to repositories
.DESCRIPTION
    Adds basic CHANGELOG.md files to all repositories
.PARAMETER DryRun
    If specified, only shows what would be done without making changes
#>

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ReposRoot = "F:\VaultRepo\_repos"

# CHANGELOG template
$ChangelogTemplate = @"
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial repository setup
- Core functionality implementation

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A

## [1.0.0] - $(Get-Date -Format 'yyyy-MM-dd')

### Added
- Initial release
"@

Write-Host "=== Bulk Add CHANGELOG.md Files ===" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
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

Write-Host "Found $($allRepos.Count) repositories" -ForegroundColor Gray
Write-Host ""

# Process repositories
$added = 0
$skipped = 0
$errors = 0

foreach ($repoInfo in $allRepos) {
    $changelogPath = Join-Path $repoInfo.Path "CHANGELOG.md"
    $changelogExists = Test-Path $changelogPath

    if ($changelogExists) {
        Write-Host "  SKIP: $($repoInfo.Owner)/$($repoInfo.Name) - CHANGELOG.md already exists" -ForegroundColor Gray
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would add CHANGELOG.md to: $($repoInfo.Owner)/$($repoInfo.Name)" -ForegroundColor Cyan
        $added++
    } else {
        try {
            $ChangelogTemplate | Set-Content -Path $changelogPath -Encoding UTF8
            Write-Host "  ADDED: $($repoInfo.Owner)/$($repoInfo.Name) - CHANGELOG.md" -ForegroundColor Green
            $added++
        } catch {
            Write-Host "  ERROR: $($repoInfo.Owner)/$($repoInfo.Name) - $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Added: $added" -ForegroundColor Green
Write-Host "  Skipped (already exists): $skipped" -ForegroundColor Yellow
Write-Host "  Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($DryRun) {
    Write-Host "This was a dry run. Run without -DryRun to apply changes." -ForegroundColor Yellow
} else {
    Write-Host "CHANGELOG.md files added successfully!" -ForegroundColor Green
    Write-Host "Next step: Commit these changes to each repository" -ForegroundColor Cyan
}

Write-Host ""
exit 0
