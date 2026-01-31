$TokeiPath = "F:\VaultRepo\vault\scripts\tokei.exe"
$RepoPath = "F:\VaultRepo\_repos\personal\GeorgeMcIntyre-Web__SimPilot"

Write-Host "Running tokei..."
$ErrorActionPreference = 'Continue'
$tokeiJson = & $TokeiPath $RepoPath --output json --exclude node_modules 2>&1
$ErrorActionPreference = 'Stop'

Write-Host "Exit code: $LASTEXITCODE"
Write-Host "Output type: $($tokeiJson.GetType().Name)"
Write-Host "Output length: $($tokeiJson.Length)"
Write-Host ""

if ($LASTEXITCODE -eq 0) {
    Write-Host "Converting from JSON..."
    try {
        $tokeiData = $tokeiJson | ConvertFrom-Json
        Write-Host "Success! Total properties: $($tokeiData.PSObject.Properties.Count)"

        $totalLoc = 0
        foreach ($prop in $tokeiData.PSObject.Properties) {
            $langName = $prop.Name
            if ($langName -eq 'Total') { continue }

            $langData = $prop.Value
            if ($langData.code) {
                $code = $langData.code
                $totalLoc += $code
                Write-Host "  $langName : $code LOC"
            }
        }
        Write-Host ""
        Write-Host "Total LOC: $totalLoc"
    } catch {
        Write-Host "JSON parsing failed: $($_.Exception.Message)"
        Write-Host "First 500 chars of output:"
        Write-Host ($tokeiJson | Out-String).Substring(0, [Math]::Min(500, ($tokeiJson | Out-String).Length))
    }
} else {
    Write-Host "Tokei failed with exit code $LASTEXITCODE"
}
