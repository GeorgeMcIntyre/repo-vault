#Requires -Version 5.1
<#
.SYNOPSIS
    Sync all repositories from both GitHub accounts
.DESCRIPTION
    Clones or pulls all repos from:
    - Personal account (GeorgeMcIntyre) and personal orgs
    - Work account and work orgs
#>

param()

$ErrorActionPreference = 'Stop'

$VaultRoot = "F:\VaultRepo\vault"
$ReposRoot = "F:\VaultRepo\_repos"
$PersonalRoot = Join-Path $ReposRoot "personal"
$WorkRoot = Join-Path $ReposRoot "work"
$ReportsDir = Join-Path $VaultRoot "reports"
$LogsDir = Join-Path $VaultRoot "logs"
$SyncStatusFile = Join-Path $ReportsDir "sync-status.md"
$SyncLogFile = Join-Path $LogsDir "sync-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure directories exist
foreach ($dir in @($PersonalRoot, $WorkRoot, $ReportsDir, $LogsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Start transcript
Start-Transcript -Path $SyncLogFile -Append

Write-Host "=== Repository Sync ===" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Initialize sync status tracking
$syncResults = @()

# Personal account configuration
$personalConfig = @{
    Username = "GeorgeMcIntyre"
    Email = "gjdomcintyre@outlook.com"
    OutputRoot = $PersonalRoot
    Orgs = @(
        "GeorgeMcIntyre-Web",
        "Allen-Bradley",
        "SiemensPlc",
        "Process-Simulation",
        "DesignEngineeringTool"
    )
}

# Work account configuration
$workConfig = @{
    Username = "GeorgeMcIntyre"  # Same account has access to work orgs
    Email = "george.mcintyre@des-igngroup.com"
    OutputRoot = $WorkRoot
    Orgs = @(
        "DES-Group-Systems",
        "Design-Int-Group",
        "Design-Int-Group-ERP"
    )
}

function Get-AuthenticatedUsername {
    param([string]$Email)

    $status = gh auth status 2>&1 | Out-String
    $lines = $status -split "`n"

    foreach ($line in $lines) {
        if ($line -match "Logged in to github\.com account ([^\s]+)") {
            return $matches[1]
        }
    }

    return $null
}

function Sync-RepoList {
    param(
        [string]$Owner,
        [string]$OutputRoot,
        [string]$AccountType,
        [ref]$Results
    )

    Write-Host "Syncing repos for: $Owner ($AccountType)" -ForegroundColor Cyan

    # Get repository list
    $repoListJson = gh repo list $Owner --limit 2000 --json nameWithOwner,name,isPrivate 2>&1

    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "Failed to list repos for $Owner"
        Write-Host "  ERROR: $errorMsg" -ForegroundColor Red
        Write-Host "  $repoListJson" -ForegroundColor Red
        $Results.Value += [PSCustomObject]@{
            Account = $AccountType
            Owner = $Owner
            Repo = "N/A"
            Status = "LIST_FAILED"
            Message = $errorMsg
        }
        return
    }

    try {
        $repos = $repoListJson | ConvertFrom-Json
    } catch {
        $errorMsg = "Failed to parse repo list for $Owner"
        Write-Host "  ERROR: $errorMsg" -ForegroundColor Red
        $Results.Value += [PSCustomObject]@{
            Account = $AccountType
            Owner = $Owner
            Repo = "N/A"
            Status = "PARSE_FAILED"
            Message = $errorMsg
        }
        return
    }

    if ($repos.Count -eq 0) {
        Write-Host "  No repos found for $Owner" -ForegroundColor Yellow
        $Results.Value += [PSCustomObject]@{
            Account = $AccountType
            Owner = $Owner
            Repo = "N/A"
            Status = "NO_REPOS"
            Message = "No repositories found"
        }
        return
    }

    Write-Host "  Found $($repos.Count) repos" -ForegroundColor Green

    foreach ($repo in $repos) {
        $repoName = $repo.name
        $fullName = $repo.nameWithOwner
        $folderName = $fullName -replace '/', '__'
        $repoPath = Join-Path $OutputRoot $folderName

        Write-Host "  Processing: $fullName" -NoNewline

        if (Test-Path $repoPath) {
            # Repo exists, pull updates
            try {
                $ErrorActionPreference = 'Continue'
                $pullOutput = git -C $repoPath pull --ff-only 2>&1
                $ErrorActionPreference = 'Stop'
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " [PULLED]" -ForegroundColor Green
                    $Results.Value += [PSCustomObject]@{
                        Account = $AccountType
                        Owner = $Owner
                        Repo = $repoName
                        Status = "PULLED"
                        Message = "Updated successfully"
                    }
                } else {
                    Write-Host " [PULL_FAILED]" -ForegroundColor Yellow
                    $Results.Value += [PSCustomObject]@{
                        Account = $AccountType
                        Owner = $Owner
                        Repo = $repoName
                        Status = "PULL_FAILED"
                        Message = $pullOutput
                    }
                }
            } catch {
                Write-Host " [PULL_ERROR]" -ForegroundColor Red
                $Results.Value += [PSCustomObject]@{
                    Account = $AccountType
                    Owner = $Owner
                    Repo = $repoName
                    Status = "PULL_ERROR"
                    Message = $_.Exception.Message
                }
            }
        } else {
            # Repo doesn't exist, clone it
            try {
                $ErrorActionPreference = 'Continue'
                $cloneOutput = gh repo clone $fullName $repoPath 2>&1
                $ErrorActionPreference = 'Stop'
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " [CLONED]" -ForegroundColor Cyan
                    $Results.Value += [PSCustomObject]@{
                        Account = $AccountType
                        Owner = $Owner
                        Repo = $repoName
                        Status = "CLONED"
                        Message = "Cloned successfully"
                    }
                } else {
                    Write-Host " [CLONE_FAILED]" -ForegroundColor Red
                    $Results.Value += [PSCustomObject]@{
                        Account = $AccountType
                        Owner = $Owner
                        Repo = $repoName
                        Status = "CLONE_FAILED"
                        Message = $cloneOutput
                    }
                }
            } catch {
                Write-Host " [CLONE_ERROR]" -ForegroundColor Red
                $Results.Value += [PSCustomObject]@{
                    Account = $AccountType
                    Owner = $Owner
                    Repo = $repoName
                    Status = "CLONE_ERROR"
                    Message = $_.Exception.Message
                }
            }
        }
    }

    Write-Host ""
}

# Sync Personal Account
Write-Host "=== PERSONAL ACCOUNT ===" -ForegroundColor Magenta
Write-Host "Switching to personal account..." -ForegroundColor Cyan

$currentUser = Get-AuthenticatedUsername -Email $personalConfig.Email
if (-not $currentUser) {
    Write-Error "No authenticated user found. Run 10_auth.ps1 first."
}

# Try to switch to personal account
Write-Host "Attempting to switch to user: $($personalConfig.Username)" -ForegroundColor Gray
$ErrorActionPreference = 'Continue'
gh auth switch -u $personalConfig.Username 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0) {
    Write-Host "Could not switch to $($personalConfig.Username), trying current user..." -ForegroundColor Yellow
}

# Sync personal user repos
Sync-RepoList -Owner $personalConfig.Username -OutputRoot $personalConfig.OutputRoot -AccountType "Personal" -Results ([ref]$syncResults)

# Sync personal orgs
foreach ($org in $personalConfig.Orgs) {
    Sync-RepoList -Owner $org -OutputRoot $personalConfig.OutputRoot -AccountType "Personal-Org" -Results ([ref]$syncResults)
}

# Sync Work Account
Write-Host "=== WORK ACCOUNT ===" -ForegroundColor Magenta

# Detect work username
Write-Host "Detecting work account username..." -ForegroundColor Cyan
$authStatus = gh auth status 2>&1 | Out-String
$workUsername = $null

# Try to find second account
$accounts = @()
if ($authStatus -match "Logged in to github\.com account ([^\s]+)") {
    $accounts += $matches[1]
}
$lines = $authStatus -split "`n"
foreach ($line in $lines) {
    if ($line -match "account ([^\s]+)") {
        $acc = $matches[1]
        if ($acc -notin $accounts) {
            $accounts += $acc
        }
    }
}

# Assume second account is work
if ($accounts.Count -ge 2) {
    $workUsername = $accounts | Where-Object { $_ -ne $personalConfig.Username } | Select-Object -First 1
}

if (-not $workUsername) {
    Write-Host "Could not detect work username. Using first available account." -ForegroundColor Yellow
    $workUsername = $accounts | Select-Object -First 1
}

Write-Host "Work username: $workUsername" -ForegroundColor Green
$workConfig.Username = $workUsername

# Switch to work account
Write-Host "Switching to work account..." -ForegroundColor Cyan
$ErrorActionPreference = 'Continue'
gh auth switch -u $workUsername 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not switch to $workUsername. Continuing anyway..."
}

# Sync work user repos (if any)
if ($workUsername) {
    Sync-RepoList -Owner $workUsername -OutputRoot $workConfig.OutputRoot -AccountType "Work" -Results ([ref]$syncResults)
}

# Sync work orgs
foreach ($org in $workConfig.Orgs) {
    Sync-RepoList -Owner $org -OutputRoot $workConfig.OutputRoot -AccountType "Work-Org" -Results ([ref]$syncResults)
}

# Generate sync status report
Write-Host "=== Generating Sync Status Report ===" -ForegroundColor Cyan

$statusMarkdown = @()
$statusMarkdown += "# Sync Status Report"
$statusMarkdown += ""
$statusMarkdown += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$statusMarkdown += ""
$statusMarkdown += "## Summary"
$statusMarkdown += ""

$totalRepos = $syncResults.Count
$successful = ($syncResults | Where-Object { $_.Status -in @('CLONED', 'PULLED') }).Count
$failed = ($syncResults | Where-Object { $_.Status -notin @('CLONED', 'PULLED') }).Count

$statusMarkdown += "- **Total operations:** $totalRepos"
$statusMarkdown += "- **Successful:** $successful"
$statusMarkdown += "- **Failed:** $failed"
$statusMarkdown += ""

# Group by account
$statusMarkdown += "## Personal Account"
$statusMarkdown += ""
$personalResults = $syncResults | Where-Object { $_.Account -like 'Personal*' }
$statusMarkdown += "- Total: $($personalResults.Count)"
$statusMarkdown += "- Successful: $(($personalResults | Where-Object { $_.Status -in @('CLONED', 'PULLED') }).Count)"
$statusMarkdown += "- Failed: $(($personalResults | Where-Object { $_.Status -notin @('CLONED', 'PULLED') }).Count)"
$statusMarkdown += ""

$statusMarkdown += "## Work Account"
$statusMarkdown += ""
$workResults = $syncResults | Where-Object { $_.Account -like 'Work*' }
$statusMarkdown += "- Total: $($workResults.Count)"
$statusMarkdown += "- Successful: $(($workResults | Where-Object { $_.Status -in @('CLONED', 'PULLED') }).Count)"
$statusMarkdown += "- Failed: $(($workResults | Where-Object { $_.Status -notin @('CLONED', 'PULLED') }).Count)"
$statusMarkdown += ""

# Failures detail
$failures = $syncResults | Where-Object { $_.Status -notin @('CLONED', 'PULLED') }
if ($failures.Count -gt 0) {
    $statusMarkdown += "## Failures and Warnings"
    $statusMarkdown += ""
    $statusMarkdown += "| Account | Owner | Repo | Status | Message |"
    $statusMarkdown += "|---------|-------|------|--------|---------|"
    foreach ($failure in $failures) {
        $msg = $failure.Message -replace '\|', '\|' -replace "`n", " " -replace "`r", ""
        $msg = $msg.Substring(0, [Math]::Min(100, $msg.Length))
        $statusMarkdown += "| $($failure.Account) | $($failure.Owner) | $($failure.Repo) | $($failure.Status) | $msg |"
    }
    $statusMarkdown += ""
}

$statusMarkdown += "## Log File"
$statusMarkdown += ""
$statusMarkdown += "Full sync log: ``$SyncLogFile``"
$statusMarkdown += ""

$statusMarkdown | Set-Content -Path $SyncStatusFile -Encoding UTF8

Write-Host "Sync status saved to: $SyncStatusFile" -ForegroundColor Green
Write-Host ""
Write-Host "Sync Complete!" -ForegroundColor Green
Write-Host "  Successful: $successful" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Yellow' } else { 'Green' })
Write-Host ""

Stop-Transcript

exit 0
