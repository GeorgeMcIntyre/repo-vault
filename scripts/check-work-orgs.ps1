$ErrorActionPreference = 'Continue'

Write-Host "Checking work account organizations..." -ForegroundColor Cyan
Write-Host ""

# Try to detect work account
$authStatus = gh auth status 2>&1 | Out-String
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

Write-Host "Available accounts:" -ForegroundColor Gray
foreach ($acc in $accounts) {
    Write-Host "  - $acc"
}
Write-Host ""

# Try each account to find work orgs
$workOrgs = @("DES-Group-Systems", "Design-Int-Group", "Design-Int-Group-ERP")

foreach ($account in $accounts) {
    Write-Host "=== Testing with account: $account ===" -ForegroundColor Magenta
    gh auth switch -u $account 2>&1 | Out-Null
    
    foreach ($org in $workOrgs) {
        try {
            $repos = gh repo list $org --limit 1000 --json nameWithOwner 2>&1
            if ($repos -match "Could not resolve") {
                Write-Host "  $org : No access or doesn't exist" -ForegroundColor Yellow
            } else {
                $repoList = $repos | ConvertFrom-Json
                $count = $repoList.Count
                if ($count -eq $null) { $count = 0 }
                Write-Host "  $org : $count repos" -ForegroundColor Green
            }
        } catch {
            Write-Host "  $org : ERROR - $_" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Also check if user has access to list their orgs
Write-Host "=== Checking organization memberships ===" -ForegroundColor Cyan
foreach ($account in $accounts) {
    Write-Host "Account: $account" -ForegroundColor Yellow
    gh auth switch -u $account 2>&1 | Out-Null
    
    $orgs = gh api user/orgs --jq '.[].login' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Organizations:"
        $orgs | ForEach-Object { Write-Host "    - $_" -ForegroundColor Green }
    } else {
        Write-Host "  Could not list organizations" -ForegroundColor Red
    }
    Write-Host ""
}
