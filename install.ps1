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
winget install -e --id TechSmith.Snagit.2024

# Install Windows Subsystem for Linux
wsl --install





