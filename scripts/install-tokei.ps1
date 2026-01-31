$ProgressPreference = 'SilentlyContinue'
$tokeiUrl = "https://github.com/XAMPPRocky/tokei/releases/download/v12.1.2/tokei-x86_64-pc-windows-msvc.exe"
$tokeiPath = "$env:USERPROFILE\tokei.exe"

Write-Host "Downloading tokei..."
Invoke-WebRequest -Uri $tokeiUrl -OutFile $tokeiPath

Write-Host "Installing tokei to C:\Windows\tokei.exe..."
Move-Item -Force $tokeiPath "C:\Windows\tokei.exe"

Write-Host "tokei installed successfully!"
tokei --version
