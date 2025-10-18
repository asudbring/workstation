# List of software to install #
# PowerShell, Office, Visual Studio Code, Azure CLI, Terraform, Bicep, Notepad ++, Git, Git Credential Manager, 7-zip, Snagit, Visio #

# Set Execution Policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install PowerShell
winget install -e --id Microsoft.PowerShell

# Install Office
winget install -e --id Microsoft.Office

# Install Visual Studio Code
winget install -e --id Microsoft.VisualStudioCode

# Install Azure CLI
winget install -e --id Microsoft.AzureCLI

# Install Terraform
winget install -e --id HashiCorp.Terraform

# Install Bicep
winget install -e --id Microsoft.Bicep

# Install Notepad ++
winget install -e --id Notepad++.Notepad++

# Install Git
winget install -e --id Git.Git

# Install 7-zip
winget install -e --id 7zip.7zip

# Install Snagit
winget install -e --id TechSmith.Snagit.2025

# Install oh-my-posh
winget install JanDeDobbeleer.OhMyPosh

# Install PSReadline
Install-Module -Name PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck

# Install Posh-git
Install-Module posh-git -Scope CurrentUser -Force

# Install profile customizations
if (!(Test-Path -Path $PROFILE.AllUsersAllHosts)) {
    New-Item -ItemType File -Path $PROFILE.AllUsersAllHosts -Force
  }
$psgit = 'Import-Module posh-git'
$pstheme = 'oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\paradox.omp.json" | Invoke-Expression'
Add-Content -Path $profile.AllUsersAllHosts -Value $psgit
Add-Content -Path $profile.AllUsersAllHosts -Value $pstheme

# Install Windows Subsystem for Linux
wsl --install 





