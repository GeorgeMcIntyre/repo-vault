#Requires -Version 5.1
<#
.SYNOPSIS
    Check and install required tools for Repo Vault
.DESCRIPTION
    Verifies git, gh, and tokei are installed. Installs missing tools via winget.
    Records tool versions to reports/tool-versions.txt
#>

param()

$ErrorActionPreference = 'Stop'
$VaultRoot = "F:\VaultRepo\vault"
$ReportsDir = Join-Path $VaultRoot "reports"
$VersionsFile = Join-Path $ReportsDir "tool-versions.txt"

Write-Host "=== Repo Vault Setup ===" -ForegroundColor Cyan
Write-Host ""

# Ensure reports directory exists
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

# Check for git
Write-Host "Checking git..." -NoNewline
$gitInstalled = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if (-not $gitInstalled) {
    Write-Host " MISSING" -ForegroundColor Yellow
    Write-Host "Installing git via winget..."
    winget install --id Git.Git -e --source winget --silent
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install git"
    }
    Write-Host "git installed successfully" -ForegroundColor Green
}
if (-not $gitInstalled) {
    Write-Host " OK" -ForegroundColor Green
}

# Check for gh (GitHub CLI)
Write-Host "Checking gh..." -NoNewline
$ghInstalled = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if (-not $ghInstalled) {
    Write-Host " MISSING" -ForegroundColor Yellow
    Write-Host "Installing GitHub CLI via winget..."
    winget install --id GitHub.cli -e --source winget --silent
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install GitHub CLI"
    }
    Write-Host "GitHub CLI installed successfully" -ForegroundColor Green
}
if (-not $ghInstalled) {
    Write-Host " OK" -ForegroundColor Green
}

# Check for tokei
Write-Host "Checking tokei..." -NoNewline
$localTokei = Join-Path $PSScriptRoot "tokei.exe"
$tokeiInstalled = (Test-Path $localTokei) -or ($null -ne (Get-Command tokei -ErrorAction SilentlyContinue))

if (-not $tokeiInstalled) {
    Write-Host " MISSING" -ForegroundColor Yellow
    Write-Host "Downloading tokei to scripts folder..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://github.com/XAMPPRocky/tokei/releases/download/v12.1.2/tokei-x86_64-pc-windows-msvc.exe' -OutFile $localTokei
        Write-Host "tokei installed successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download tokei. Install manually from https://github.com/XAMPPRocky/tokei"
    }
} else {
    Write-Host " OK" -ForegroundColor Green
}

# Record tool versions
Write-Host ""
Write-Host "Recording tool versions to $VersionsFile" -ForegroundColor Cyan

$versions = @()
$versions += "Tool versions recorded at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$versions += ""

try {
    $gitVersion = git --version 2>&1
    $versions += "git: $gitVersion"
} catch {
    $versions += "git: ERROR - $($_.Exception.Message)"
}

try {
    $ghVersion = gh --version 2>&1 | Select-Object -First 1
    $versions += "gh: $ghVersion"
} catch {
    $versions += "gh: ERROR - $($_.Exception.Message)"
}

try {
    if (Test-Path $localTokei) {
        $tokeiVersion = & $localTokei --version 2>&1
    } else {
        $tokeiVersion = tokei --version 2>&1
    }
    $versions += "tokei: $tokeiVersion"
} catch {
    $versions += "tokei: ERROR - $($_.Exception.Message)"
}

try {
    $psVersion = $PSVersionTable.PSVersion.ToString()
    $versions += "PowerShell: $psVersion"
} catch {
    $versions += "PowerShell: ERROR - $($_.Exception.Message)"
}

$versions | Set-Content -Path $VersionsFile -Encoding UTF8

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Tool versions saved to: $VersionsFile" -ForegroundColor Gray
Write-Host ""

exit 0
