$ErrorActionPreference = 'Continue'

Write-Host "Checking repository counts from GitHub API..." -ForegroundColor Cyan
Write-Host ""

gh auth switch -u GeorgeMcIntyre 2>&1 | Out-Null

$orgs = @(
    "GeorgeMcIntyre",
    "GeorgeMcIntyre-Web",
    "Allen-Bradley",
    "SiemensPlc",
    "Process-Simulation",
    "DesignEngineeringTool"
)

$total = 0

foreach ($org in $orgs) {
    try {
        $repos = gh repo list $org --limit 1000 --json nameWithOwner 2>&1 | ConvertFrom-Json
        $count = $repos.Count
        if ($count -eq $null) { $count = 0 }
        Write-Host "$org : $count repos" -ForegroundColor Green
        $total += $count
    } catch {
        Write-Host "$org : ERROR - $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Total repositories available: $total" -ForegroundColor Yellow
