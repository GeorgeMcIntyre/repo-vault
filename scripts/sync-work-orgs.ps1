$ErrorActionPreference = 'Continue'

$ReposRoot = "F:\VaultRepo\_repos"
$WorkRoot = Join-Path $ReposRoot "work"

Write-Host "=== Syncing Work Organizations ===" -ForegroundColor Cyan
Write-Host ""

# Switch to GeorgeMcIntyre account (has access to work orgs)
gh auth switch -u GeorgeMcIntyre 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'

$workOrgs = @("DES-Group-Systems", "Design-Int-Group", "Design-Int-Group-ERP")

foreach ($org in $workOrgs) {
    Write-Host "Syncing: $org" -ForegroundColor Yellow
    
    $repos = gh repo list $org --limit 1000 --json nameWithOwner,name 2>&1 | ConvertFrom-Json
    
    if ($repos.Count -eq 0) {
        Write-Host "  No repos found" -ForegroundColor Gray
        continue
    }
    
    Write-Host "  Found $($repos.Count) repos" -ForegroundColor Green
    
    foreach ($repo in $repos) {
        $fullName = $repo.nameWithOwner
        $repoName = $repo.name
        $folderName = $fullName -replace '/', '__'
        $repoPath = Join-Path $WorkRoot $folderName
        
        Write-Host "  Processing: $fullName" -NoNewline
        
        if (Test-Path $repoPath) {
            $ErrorActionPreference = 'Continue'
            git -C $repoPath pull --ff-only 2>&1 | Out-Null
            $pullSuccess = $LASTEXITCODE -eq 0
            $ErrorActionPreference = 'Stop'
            if ($pullSuccess) {
                Write-Host " [PULLED]" -ForegroundColor Green
            } else {
                Write-Host " [PULL_FAILED]" -ForegroundColor Yellow
            }
        } else {
            $ErrorActionPreference = 'Continue'
            gh repo clone $fullName $repoPath 2>&1 | Out-Null
            $cloneSuccess = $LASTEXITCODE -eq 0
            $ErrorActionPreference = 'Stop'
            if ($cloneSuccess) {
                Write-Host " [CLONED]" -ForegroundColor Cyan
            } else {
                Write-Host " [CLONE_FAILED]" -ForegroundColor Red
            }
        }
    }
    Write-Host ""
}

Write-Host "Work org sync complete!" -ForegroundColor Green
