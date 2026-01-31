$TokeiPath = "F:\VaultRepo\vault\scripts\tokei.exe"
$RepoPath = "F:\VaultRepo\_repos\personal\GeorgeMcIntyre-Web__SimPilot"

$metrics = [PSCustomObject]@{
    Repo = "SimPilot"
    LocTotal = 0
    LocByLanguage = @{}
}

Write-Host "Initial LOC: $($metrics.LocTotal)"

try {
    $ErrorActionPreference = 'Continue'
    $tokeiJson = & $TokeiPath $RepoPath --output json 2>&1
    $ErrorActionPreference = 'Stop'

    Write-Host "Exit code: $LASTEXITCODE"
    Write-Host "JSON length: $($tokeiJson.Length)"

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

        Write-Host "Calculated total LOC: $totalLoc"

        $metrics.LocTotal = $totalLoc
        $metrics.LocByLanguage = $locByLang

        Write-Host "After assignment LOC: $($metrics.LocTotal)"
        Write-Host "Languages: $($metrics.LocByLanguage.Count)"
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Final metrics:"
$metrics | Format-List
