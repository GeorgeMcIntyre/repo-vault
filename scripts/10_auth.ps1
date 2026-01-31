#Requires -Version 5.1
<#
.SYNOPSIS
    Setup and verify GitHub authentication for both accounts
.DESCRIPTION
    Ensures both personal and work GitHub accounts are authenticated.
    If not authenticated, prompts for interactive login.
#>

param()

$ErrorActionPreference = 'Stop'

Write-Host "=== GitHub Authentication Setup ===" -ForegroundColor Cyan
Write-Host ""

# Expected accounts
$PersonalEmail = "gjdomcintyre@outlook.com"
$WorkEmail = "george.mcintyre@des-igngroup.com"

Write-Host "Expected accounts:" -ForegroundColor Gray
Write-Host "  Personal: $PersonalEmail" -ForegroundColor Gray
Write-Host "  Work: $WorkEmail" -ForegroundColor Gray
Write-Host ""

# Check current auth status
Write-Host "Checking authentication status..." -ForegroundColor Cyan
$authStatus = gh auth status 2>&1 | Out-String

Write-Host $authStatus

# Parse authenticated accounts
$authenticatedAccounts = @()
if ($authStatus -match "Logged in to github\.com account ([^\s]+)") {
    $authenticatedAccounts += $matches[1]
}

# Check if we have multiple accounts
$statusLines = $authStatus -split "`n"
foreach ($line in $statusLines) {
    if ($line -match "account ([^\s]+) \(") {
        $account = $matches[1]
        if ($account -notin $authenticatedAccounts) {
            $authenticatedAccounts += $account
        }
    }
}

Write-Host ""
Write-Host "Currently authenticated accounts: $($authenticatedAccounts.Count)" -ForegroundColor Cyan
foreach ($account in $authenticatedAccounts) {
    Write-Host "  - $account" -ForegroundColor Green
}
Write-Host ""

# Function to prompt for login
function Invoke-GitHubLogin {
    param([string]$AccountType, [string]$Email)

    Write-Host "Authentication needed for $AccountType account ($Email)" -ForegroundColor Yellow
    Write-Host "This will open a browser window for GitHub login." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press Enter to continue with login, or Ctrl+C to cancel..." -NoNewline
    Read-Host
    Write-Host ""

    Write-Host "Logging in to GitHub ($AccountType)..." -ForegroundColor Cyan
    gh auth login --web --git-protocol https

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to authenticate $AccountType account"
    }

    Write-Host "$AccountType account authenticated successfully!" -ForegroundColor Green
    Write-Host ""
}

# Determine if we need to authenticate
$needsAuth = $authenticatedAccounts.Count -lt 2

if ($needsAuth) {
    Write-Host "Insufficient authenticated accounts detected." -ForegroundColor Yellow
    Write-Host "You need to authenticate both personal and work accounts." -ForegroundColor Yellow
    Write-Host ""

    if ($authenticatedAccounts.Count -eq 0) {
        Write-Host "No accounts authenticated. Starting with personal account..." -ForegroundColor Yellow
        Invoke-GitHubLogin -AccountType "Personal" -Email $PersonalEmail

        Write-Host "Now authenticating work account..." -ForegroundColor Yellow
        Invoke-GitHubLogin -AccountType "Work" -Email $WorkEmail
    }

    if ($authenticatedAccounts.Count -eq 1) {
        Write-Host "One account already authenticated. Adding second account..." -ForegroundColor Yellow
        Invoke-GitHubLogin -AccountType "Additional" -Email "second account"
    }
}

# Final status check
Write-Host ""
Write-Host "Final authentication status:" -ForegroundColor Cyan
gh auth status

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Authentication check returned non-zero exit code, but may be normal for multi-account setup"
}

Write-Host ""
Write-Host "Authentication setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: During sync, the script will switch between accounts using:" -ForegroundColor Gray
Write-Host "  gh auth switch -u <username>" -ForegroundColor Gray
Write-Host ""

exit 0
