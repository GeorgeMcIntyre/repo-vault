#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk add LICENSE files to repositories
.DESCRIPTION
    Adds appropriate LICENSE files to all repositories
    - MIT for personal/showcase repos
    - Proprietary for client/commercial work
.PARAMETER DryRun
    If specified, only shows what would be done without making changes
#>

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ReposRoot = "F:\VaultRepo\_repos"
$VaultRoot = "F:\VaultRepo\vault"
$TemplatesDir = Join-Path $VaultRoot "templates"

# Ensure templates directory exists
if (-not (Test-Path $TemplatesDir)) {
    New-Item -ItemType Directory -Path $TemplatesDir -Force | Out-Null
}

# MIT License template
$MITLicense = @"
MIT License

Copyright (c) $(Get-Date -Format 'yyyy') George McIntyre

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@

# Proprietary License template
$ProprietaryLicense = @"
Proprietary License

Copyright (c) $(Get-Date -Format 'yyyy') George McIntyre / Design Int Group

All rights reserved.

This software and associated documentation files (the "Software") are
proprietary and confidential. Unauthorized copying, distribution, modification,
public display, or public performance of this Software, via any medium, is
strictly prohibited.

The Software is provided for specific client use only under separate agreement.
No license, express or implied, by estoppel or otherwise, to any intellectual
property rights is granted by this document.

For licensing inquiries, contact:
George McIntyre
george.mcintyre@des-igngroup.com
"@

Write-Host "=== Bulk Add LICENSE Files ===" -ForegroundColor Cyan
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
                Type = "MIT"  # Personal repos get MIT license
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
                Type = "Proprietary"  # Work repos get proprietary license
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
    $licensePath = Join-Path $repoInfo.Path "LICENSE"
    $licenseExists = Test-Path $licensePath

    if ($licenseExists) {
        Write-Host "  SKIP: $($repoInfo.Owner)/$($repoInfo.Name) - LICENSE already exists" -ForegroundColor Gray
        $skipped++
        continue
    }

    $licenseContent = if ($repoInfo.Type -eq "MIT") { $MITLicense } else { $ProprietaryLicense }

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would add $($repoInfo.Type) LICENSE to: $($repoInfo.Owner)/$($repoInfo.Name)" -ForegroundColor Cyan
        $added++
    } else {
        try {
            $licenseContent | Set-Content -Path $licensePath -Encoding UTF8 -NoNewline
            Write-Host "  ADDED: $($repoInfo.Owner)/$($repoInfo.Name) - $($repoInfo.Type) LICENSE" -ForegroundColor Green
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
    Write-Host "LICENSE files added successfully!" -ForegroundColor Green
    Write-Host "Next step: Commit these changes to each repository" -ForegroundColor Cyan
}

Write-Host ""
exit 0
