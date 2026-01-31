# GitHub Repo Vault

Automated system for syncing, analyzing, and valuing all GitHub repositories across multiple accounts and organizations.

## Setup

This vault manages repositories from two GitHub accounts:
- Personal: gjdomcintyre@outlook.com
- Work: george.mcintyre@des-igngroup.com

## Quick Start

Run everything with one command:

```powershell
.\scripts\run_all.ps1
```

This will:
1. Check and install required tools
2. Verify GitHub authentication
3. Sync all repositories from both accounts
4. Generate analysis reports

## Manual Steps

If you need to run individual steps:

```powershell
# Setup tools
.\scripts\00_setup.ps1

# Configure GitHub authentication
.\scripts\10_auth.ps1

# Sync repositories
.\scripts\20_sync.ps1

# Generate reports
.\scripts\30_analyze.ps1
```

## Folder Structure

- `F:\VaultRepo\vault\` - This git repo (scripts and reports only)
- `F:\VaultRepo\_repos\personal\` - Cloned repos from personal account
- `F:\VaultRepo\_repos\work\` - Cloned repos from work account
- `scripts\` - PowerShell automation scripts
- `reports\` - Generated analysis and value reports
- `logs\` - Execution logs

## Required Tools

- git
- gh (GitHub CLI)
- tokei (for LOC metrics)

The setup script will install missing tools automatically using winget.

## Organizations Included

Personal account orgs:
- GeorgeMcIntyre-Web
- Allen-Bradley
- SiemensPlc
- Process-Simulation
- DesignEngineeringTool

Work account orgs:
- DES-Group-Systems
- Design-Int-Group
- Design-Int-Group-ERP

## Reports Generated

- `reports/inventory.csv` - Full repository inventory
- `reports/inventory.md` - Human-readable summary with totals
- `reports/proof-of-work.md` - Multi-year activity analysis
- `reports/value-estimate.md` - Portfolio value in ZAR
- `reports/sync-status.md` - Sync success/failure log
- `reports/tool-versions.txt` - Installed tool versions

## First-Time Auth

On first run, you'll be prompted to authenticate both GitHub accounts in your browser:
1. Personal account (gjdomcintyre@outlook.com)
2. Work account (george.mcintyre@des-igngroup.com)

Follow the browser prompts and grant the necessary permissions.

## Security

- No secrets are committed to this repo
- All sensitive patterns are redacted from reports
- Cloned repos are excluded via .gitignore
