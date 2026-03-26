# ============================================================================
# install-windows.ps1 — Windows Workstation Setup Script
# ============================================================================
# Idempotent install script for provisioning a new Windows workstation with all
# development tools, CLI utilities, GUI apps, shell customizations, and
# Windows Terminal preferences used by Allen Sudbring for Azure documentation work.
#
# Usage (run as Administrator):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\install-windows.ps1
#
# Safe to re-run — checks each component before installing.
# On re-run, upgrades all packages and updates modules.
# ============================================================================

#Requires -RunAsAdministrator

# ── Color helpers ──────────────────────────────────────────────────────────
$Script:INSTALLED = 0
$Script:SKIPPED   = 0
$Script:FAILED    = 0
$Script:UPDATED   = 0

function Write-Info    { param([string]$msg) Write-Host "[INFO]    $msg" -ForegroundColor Blue }
function Write-Ok      { param([string]$msg) Write-Host "[OK]      $msg" -ForegroundColor Green }
function Write-Skip    { param([string]$msg) Write-Host "[SKIP]    $msg" -ForegroundColor Yellow }
function Write-Warn    { param([string]$msg) Write-Host "[WARN]    $msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$msg) Write-Host "[FAIL]    $msg" -ForegroundColor Red }
function Write-Section {
    param([string]$msg)
    Write-Host ""
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host ""
}

function Mark-Installed { $Script:INSTALLED++ }
function Mark-Skipped   { $Script:SKIPPED++ }
function Mark-Failed    { $Script:FAILED++ }
function Mark-Updated   { $Script:UPDATED++ }

# Helper: test if a command exists
function Test-CommandExists {
    param([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# Helper: refresh PATH mid-session (picks up new installs)
function Update-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# ── Pre-flight checks ─────────────────────────────────────────────────────
Write-Section "Pre-flight Checks"

# Verify Windows
if ($env:OS -ne "Windows_NT") {
    Write-Fail "This script is for Windows only."
    exit 1
}

$winVer = [System.Environment]::OSVersion.Version
Write-Ok "Running on Windows $($winVer.Major).$($winVer.Minor) (Build $($winVer.Build))"

if ($winVer.Build -lt 22000) {
    Write-Warn "Windows 11 (build 22000+) recommended. Some features may not work on older builds."
}

# ── Section 1: Package Managers ────────────────────────────────────────────
Write-Section "Package Managers"

# --- winget ---
if (Test-CommandExists "winget") {
    Write-Skip "winget already installed"
    Mark-Skipped

    Write-Info "Upgrading all winget packages..."
    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent 2>$null
    Write-Ok "winget upgrade complete"
    Mark-Updated
} else {
    Write-Fail "winget not found — it should be pre-installed on Windows 11."
    Write-Info "Install 'App Installer' from the Microsoft Store, then re-run."
    Mark-Failed
}

# --- Chocolatey ---
if (Test-CommandExists "choco") {
    Write-Skip "Chocolatey already installed ($(choco --version))"
    Mark-Skipped

    Write-Info "Upgrading all Chocolatey packages..."
    choco upgrade all -y --no-progress 2>$null
    Write-Ok "Chocolatey upgrade complete"
    Mark-Updated
} else {
    Write-Info "Installing Chocolatey..."
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Update-Path
        if (Test-CommandExists "choco") {
            Write-Ok "Chocolatey installed"
            Mark-Installed
        } else {
            Write-Fail "Chocolatey installation failed"
            Mark-Failed
        }
    } catch {
        Write-Fail "Chocolatey installation failed: $_"
        Mark-Failed
    }
}

# ── Section 2: Winget Packages (GUI Apps + CLI Tools) ──────────────────────
Write-Section "Winget Packages (GUI Apps + CLI Tools)"

$wingetPackages = @(
    @{ Id = "Microsoft.Edge";            Name = "Microsoft Edge" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" },
    @{ Id = "Docker.DockerDesktop";      Name = "Docker Desktop" },
    @{ Id = "Git.Git";                   Name = "Git" },
    @{ Id = "OpenJS.NodeJS.LTS";         Name = "Node.js LTS" },
    @{ Id = "Python.Python.3.13";        Name = "Python 3.13" },
    @{ Id = "Hashicorp.Terraform";       Name = "Terraform" },
    @{ Id = "GitHub.cli";                Name = "GitHub CLI" },
    @{ Id = "Microsoft.AzureCLI";        Name = "Azure CLI" },
    @{ Id = "Microsoft.PowerShell";      Name = "PowerShell 7" },
    @{ Id = "JanDeDobbeleer.OhMyPosh";   Name = "oh-my-posh" },
    @{ Id = "TechSmith.Snagit";          Name = "Snagit" },
    @{ Id = "Microsoft.Office";          Name = "Microsoft Office" },
    @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal" },
    @{ Id = "Microsoft.WindowsApp";      Name = "Windows App (RDP)" },
    @{ Id = "Anthropic.Claude";          Name = "Claude Desktop" }
)

foreach ($pkg in $wingetPackages) {
    $installed = winget list --id $pkg.Id --accept-source-agreements 2>$null | Select-String $pkg.Id
    if ($installed) {
        Write-Skip "$($pkg.Name) already installed"
        Mark-Skipped
    } else {
        Write-Info "Installing $($pkg.Name)..."
        $result = winget install --id $pkg.Id --accept-source-agreements --accept-package-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$($pkg.Name) installed"
            Mark-Installed
        } else {
            Write-Fail "$($pkg.Name) installation failed"
            Mark-Failed
        }
    }
}

# Refresh PATH after winget installs
Update-Path

# ── Section 3: AI-Optimized Dev Tools ─────────────────────────────────────
Write-Section "AI-Optimized Dev Tools (winget)"

$aiTools = @(
    @{ Id = "BurntSushi.ripgrep.MSVC"; Name = "ripgrep (rg)";    Cmd = "rg" },
    @{ Id = "sharkdp.fd";              Name = "fd";               Cmd = "fd" },
    @{ Id = "junegunn.fzf";            Name = "fzf";              Cmd = "fzf" },
    @{ Id = "DuckDB.cli";              Name = "DuckDB";           Cmd = "duckdb" },
    @{ Id = "dandavison.delta";        Name = "git-delta";        Cmd = "delta" },
    @{ Id = "ducaale.xh";              Name = "xh";               Cmd = "xh" },
    @{ Id = "Casey.Just";              Name = "just";             Cmd = "just" },
    @{ Id = "FiloSottile.age";         Name = "age (encryption)"; Cmd = "age" }
)

foreach ($tool in $aiTools) {
    $installed = winget list --id $tool.Id --accept-source-agreements 2>$null | Select-String $tool.Id
    if ($installed) {
        Write-Skip "$($tool.Name) already installed"
        Mark-Skipped
    } else {
        Write-Info "Installing $($tool.Name)..."
        $result = winget install --id $tool.Id --accept-source-agreements --accept-package-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$($tool.Name) installed"
            Mark-Installed
        } else {
            Write-Fail "$($tool.Name) installation failed"
            Mark-Failed
        }
    }
}

Update-Path

# ── Section 4: Special Installs ───────────────────────────────────────────
Write-Section "Special Installs"

# --- watchexec (GitHub release — not in winget) ---
if (Test-CommandExists "watchexec") {
    Write-Skip "watchexec already installed"
    Mark-Skipped
} else {
    Write-Info "Installing watchexec from GitHub..."
    try {
        $watchexecRelease = Invoke-RestMethod "https://api.github.com/repos/watchexec/watchexec/releases/latest"
        $asset = $watchexecRelease.assets | Where-Object { $_.name -match "watchexec-.*-x86_64-pc-windows-msvc\.zip$" } | Select-Object -First 1
        if ($asset) {
            $tmpZip = "$env:TEMP\watchexec.zip"
            $tmpDir = "$env:TEMP\watchexec"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip
            Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
            $exe = Get-ChildItem -Path $tmpDir -Recurse -Filter "watchexec.exe" | Select-Object -First 1
            if ($exe) {
                $destDir = "$env:LOCALAPPDATA\Programs\watchexec"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                Copy-Item $exe.FullName "$destDir\watchexec.exe" -Force
                # Add to user PATH
                $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
                if ($userPath -notlike "*$destDir*") {
                    [Environment]::SetEnvironmentVariable("Path", "$userPath;$destDir", "User")
                }
                Update-Path
                Write-Ok "watchexec installed to $destDir"
                Mark-Installed
            } else {
                Write-Fail "watchexec.exe not found in archive"
                Mark-Failed
            }
            Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Fail "Could not find watchexec Windows release asset"
            Mark-Failed
        }
    } catch {
        Write-Fail "watchexec installation failed: $_"
        Mark-Failed
    }
}

# --- semgrep (pip) ---
if (Test-CommandExists "semgrep") {
    Write-Skip "semgrep already installed"
    Mark-Skipped

    Write-Info "Updating semgrep..."
    pip install --upgrade semgrep --quiet 2>$null
    Mark-Updated
} else {
    Write-Info "Installing semgrep via pip..."
    if (Test-CommandExists "pip") {
        pip install semgrep --quiet 2>$null
        Update-Path
        if (Test-CommandExists "semgrep") {
            Write-Ok "semgrep installed"
            Mark-Installed
        } else {
            Write-Fail "semgrep installation failed"
            Mark-Failed
        }
    } else {
        Write-Fail "pip not found — install Python first"
        Mark-Failed
    }
}

# --- Bun ---
if (Test-CommandExists "bun") {
    Write-Skip "Bun already installed ($(bun --version))"
    Mark-Skipped

    Write-Info "Updating Bun..."
    bun upgrade 2>$null
    Mark-Updated
} else {
    Write-Info "Installing Bun..."
    try {
        Invoke-Expression (Invoke-RestMethod "https://bun.sh/install.ps1")
        Update-Path
        if (Test-CommandExists "bun") {
            Write-Ok "Bun installed"
            Mark-Installed
        } else {
            Write-Fail "Bun installation failed"
            Mark-Failed
        }
    } catch {
        Write-Fail "Bun installation failed: $_"
        Mark-Failed
    }
}

# --- WSL + Ubuntu ---
$wslInstalled = $false
try {
    $wslOutput = wsl --list --quiet 2>$null
    if ($wslOutput -match "Ubuntu") {
        $wslInstalled = $true
    }
} catch {}

if ($wslInstalled) {
    Write-Skip "WSL Ubuntu already installed"
    Mark-Skipped
} else {
    Write-Info "Installing WSL with Ubuntu (may require reboot)..."
    wsl --install -d Ubuntu --no-launch 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "WSL Ubuntu installed (reboot required to complete setup)"
        Write-Warn "After reboot, run 'wsl' to complete Ubuntu first-time setup."
        Mark-Installed
    } else {
        Write-Fail "WSL installation failed"
        Mark-Failed
    }
}

# --- Delugia Nerd Font ---
$fontInstalled = $false
$fontRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
if (Test-Path $fontRegPath) {
    $fonts = Get-ItemProperty -Path $fontRegPath
    if ($fonts.PSObject.Properties.Name -match "Delugia") {
        $fontInstalled = $true
    }
}

if ($fontInstalled) {
    Write-Skip "Delugia Nerd Font already installed"
    Mark-Skipped
} else {
    Write-Info "Installing Delugia Nerd Font from GitHub..."
    try {
        $fontUrl = "https://github.com/adam7/delugia-code/releases/latest/download/Delugia.zip"
        $tmpZip = "$env:TEMP\Delugia.zip"
        $tmpDir = "$env:TEMP\Delugia"
        Invoke-WebRequest -Uri $fontUrl -OutFile $tmpZip
        Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

        $ttfFiles = Get-ChildItem -Path $tmpDir -Recurse -Filter "*.ttf"
        $installedCount = 0
        foreach ($ttf in $ttfFiles) {
            $destPath = "C:\Windows\Fonts\$($ttf.Name)"
            Copy-Item $ttf.FullName $destPath -Force
            # Register in registry
            $fontName = [System.IO.Path]::GetFileNameWithoutExtension($ttf.Name) + " (TrueType)"
            New-ItemProperty -Path $fontRegPath -Name $fontName -Value $ttf.Name -PropertyType String -Force | Out-Null
            $installedCount++
        }

        if ($installedCount -gt 0) {
            Write-Ok "Delugia Nerd Font installed ($installedCount files)"
            Mark-Installed
        } else {
            Write-Fail "No .ttf files found in Delugia archive"
            Mark-Failed
        }

        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Fail "Delugia font installation failed: $_"
        Mark-Failed
    }
}

# --- OpenCode ---
if (Test-CommandExists "opencode") {
    Write-Skip "OpenCode already installed"
    Mark-Skipped

    Write-Info "Updating OpenCode..."
    npm update -g opencode-ai 2>$null
    Mark-Updated
} else {
    Write-Info "Installing OpenCode via npm..."
    if (Test-CommandExists "npm") {
        npm install -g opencode-ai 2>$null
        Update-Path
        if (Test-CommandExists "opencode") {
            Write-Ok "OpenCode installed"
            Mark-Installed
        } else {
            Write-Fail "OpenCode installation failed"
            Mark-Failed
        }
    } else {
        Write-Fail "npm not found — install Node.js first"
        Mark-Failed
    }
}

# ── Section 5: PowerShell Profile & Modules (BOTH versions) ───────────────
Write-Section "PowerShell Profiles & Modules (5.1 + 7)"

$marker = "# Managed by install-windows.ps1"

$profileContent = @"
$marker
Import-Module posh-git
oh-my-posh init pwsh --config "`$env:POSH_THEMES_PATH\agnoster.omp.json" | Invoke-Expression
"@

# --- PowerShell 7+ (pwsh.exe) profile ---
Write-Info "Configuring PowerShell 7+ profile..."
$pwsh7ProfileDir  = "$HOME\Documents\PowerShell"
$pwsh7ProfilePath = "$pwsh7ProfileDir\Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $pwsh7ProfileDir)) {
    New-Item -ItemType Directory -Path $pwsh7ProfileDir -Force | Out-Null
}

if ((Test-Path $pwsh7ProfilePath) -and (Get-Content $pwsh7ProfilePath -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($marker)) {
    Write-Skip "PowerShell 7 profile already configured"
    Mark-Skipped
} else {
    if (Test-Path $pwsh7ProfilePath) {
        Copy-Item $pwsh7ProfilePath "$pwsh7ProfilePath.bak" -Force
        Write-Info "Backed up existing pwsh 7 profile to .bak"
        Add-Content -Path $pwsh7ProfilePath -Value "`n$profileContent"
    } else {
        Set-Content -Path $pwsh7ProfilePath -Value $profileContent
    }
    Write-Ok "PowerShell 7 profile configured"
    Mark-Installed
}

# --- Windows PowerShell 5.1 (powershell.exe) profile ---
Write-Info "Configuring Windows PowerShell 5.1 profile..."
$ps51ProfileDir  = "$HOME\Documents\WindowsPowerShell"
$ps51ProfilePath = "$ps51ProfileDir\Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $ps51ProfileDir)) {
    New-Item -ItemType Directory -Path $ps51ProfileDir -Force | Out-Null
}

if ((Test-Path $ps51ProfilePath) -and (Get-Content $ps51ProfilePath -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($marker)) {
    Write-Skip "Windows PowerShell 5.1 profile already configured"
    Mark-Skipped
} else {
    if (Test-Path $ps51ProfilePath) {
        Copy-Item $ps51ProfilePath "$ps51ProfilePath.bak" -Force
        Write-Info "Backed up existing PS 5.1 profile to .bak"
        Add-Content -Path $ps51ProfilePath -Value "`n$profileContent"
    } else {
        Set-Content -Path $ps51ProfilePath -Value $profileContent
    }
    Write-Ok "Windows PowerShell 5.1 profile configured"
    Mark-Installed
}

# --- Install modules in BOTH PowerShell versions ---
$modules = @("Az", "PSReadLine", "posh-git")

# PowerShell 7+
if (Test-CommandExists "pwsh") {
    foreach ($mod in $modules) {
        Write-Info "Checking module '$mod' in PowerShell 7..."
        $modCheck = pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name '$mod') { 'installed' } else { 'missing' }" 2>$null
        if ($modCheck -eq "installed") {
            Write-Skip "$mod already installed in PowerShell 7"
            Mark-Skipped

            Write-Info "Updating $mod in PowerShell 7..."
            pwsh -NoProfile -Command "Update-Module -Name '$mod' -Force -ErrorAction SilentlyContinue" 2>$null
            Mark-Updated
        } else {
            Write-Info "Installing $mod in PowerShell 7..."
            $extraArgs = ""
            if ($mod -eq "Az") { $extraArgs = " -AcceptLicense" }
            if ($mod -eq "PSReadLine") { $extraArgs = " -SkipPublisherCheck" }
            pwsh -NoProfile -Command "& { Install-Module -Name '$mod' -Scope CurrentUser -Force -AllowClobber$extraArgs }" 2>$null
            $verifyCheck = pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name '$mod') { 'ok' } else { 'fail' }" 2>$null
            if ($verifyCheck -eq "ok") {
                Write-Ok "$mod installed in PowerShell 7"
                Mark-Installed
            } else {
                Write-Fail "$mod installation failed in PowerShell 7"
                Mark-Failed
            }
        }
    }
} else {
    Write-Warn "pwsh.exe not found — skipping PowerShell 7 module installs"
}

# Windows PowerShell 5.1
foreach ($mod in $modules) {
    Write-Info "Checking module '$mod' in Windows PowerShell 5.1..."
    $modCheck = powershell.exe -NoProfile -Command "if (Get-Module -ListAvailable -Name '$mod') { 'installed' } else { 'missing' }" 2>$null
    if ($modCheck -eq "installed") {
        Write-Skip "$mod already installed in Windows PowerShell 5.1"
        Mark-Skipped

        Write-Info "Updating $mod in Windows PowerShell 5.1..."
        powershell.exe -NoProfile -Command "Update-Module -Name '$mod' -Force -ErrorAction SilentlyContinue" 2>$null
        Mark-Updated
    } else {
        Write-Info "Installing $mod in Windows PowerShell 5.1..."
        $extraArgs = ""
        if ($mod -eq "Az") { $extraArgs = " -AcceptLicense" }
        if ($mod -eq "PSReadLine") { $extraArgs = " -SkipPublisherCheck" }
        powershell.exe -NoProfile -Command "& { Install-Module -Name '$mod' -Scope CurrentUser -Force -AllowClobber$extraArgs }" 2>$null
        $verifyCheck = powershell.exe -NoProfile -Command "if (Get-Module -ListAvailable -Name '$mod') { 'ok' } else { 'fail' }" 2>$null
        if ($verifyCheck -eq "ok") {
            Write-Ok "$mod installed in Windows PowerShell 5.1"
            Mark-Installed
        } else {
            Write-Fail "$mod installation failed in Windows PowerShell 5.1"
            Mark-Failed
        }
    }
}

# ── Section 6: Windows Terminal Customization ─────────────────────────────
Write-Section "Windows Terminal Customization"

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (-not (Test-Path $settingsPath)) {
    Write-Warn "Windows Terminal settings.json not found — launch Windows Terminal once first, then re-run."
    Write-Info "Expected path: $settingsPath"
    Mark-Failed
} else {
    # Backup settings.json
    $backupPath = "$settingsPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $settingsPath $backupPath -Force
    Write-Info "Backed up settings.json to $backupPath"

    # Copy background images to user directory
    $bgDestDir = "$HOME\.terminal-backgrounds"
    if (-not (Test-Path $bgDestDir)) {
        New-Item -ItemType Directory -Path $bgDestDir -Force | Out-Null
    }

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $bgSourceDir = Join-Path $scriptDir "assets\windows-terminal"

    if (Test-Path $bgSourceDir) {
        Copy-Item "$bgSourceDir\*.png" $bgDestDir -Force
        Write-Ok "Background images copied to $bgDestDir"
    } else {
        Write-Warn "Background images not found at $bgSourceDir — skipping backgrounds"
    }

    # Read and parse settings.json
    $settingsJson = Get-Content $settingsPath -Raw | ConvertFrom-Json

    # Ensure profiles.list exists
    if (-not $settingsJson.profiles.list) {
        Write-Fail "profiles.list not found in settings.json"
        Mark-Failed
    } else {
        $bgDir = $bgDestDir -replace '\\', '/'

        # --- Define profile customizations ---
        $profileConfigs = @(
            @{
                Match     = { param($p) $p.name -eq "Windows PowerShell" }
                Label     = "Windows PowerShell 5.1"
                Background = "powershell-classic.png"
            },
            @{
                Match     = { param($p) $p.source -eq "Windows.Terminal.PowershellCore" }
                Label     = "PowerShell 7"
                Background = "powershell-core.png"
            },
            @{
                Match     = { param($p) $p.name -like "*Ubuntu*" }
                Label     = "Ubuntu WSL"
                Background = "ubuntu-wsl.png"
            },
            @{
                Match     = { param($p) $p.source -eq "Windows.Terminal.Azure" }
                Label     = "Azure Cloud Shell"
                Background = "azure-cloudshell.png"
            }
        )

        foreach ($cfg in $profileConfigs) {
            $profile = $settingsJson.profiles.list | Where-Object { & $cfg.Match $_ }
            if ($profile) {
                # Set font
                $profile | Add-Member -NotePropertyName "font" -NotePropertyValue @{
                    face   = "Delugia"
                    size   = 14
                    weight = "normal"
                } -Force

                # Set background
                $bgFile = "$bgDir/$($cfg.Background)"
                $profile | Add-Member -NotePropertyName "backgroundImage"            -NotePropertyValue $bgFile         -Force
                $profile | Add-Member -NotePropertyName "backgroundImageOpacity"     -NotePropertyValue 0.15            -Force
                $profile | Add-Member -NotePropertyName "backgroundImageStretchMode" -NotePropertyValue "uniformToFill" -Force

                # Set acrylic
                $profile | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $true -Force
                $profile | Add-Member -NotePropertyName "opacity"    -NotePropertyValue 85    -Force

                Write-Ok "$($cfg.Label) profile customized"
                Mark-Installed
            } else {
                Write-Warn "$($cfg.Label) profile not found in settings.json — skipped"
                Mark-Skipped
            }
        }

        # --- Git Bash profile (add if missing) ---
        $gitBashGuid = "{6721e727-40c5-4b27-ac6b-3a0c4f3a5e17}"
        $gitBashProfile = $settingsJson.profiles.list | Where-Object { $_.name -eq "Git Bash" -or $_.guid -eq $gitBashGuid }
        $gitBashExe = "C:\Program Files\Git\bin\bash.exe"

        if ($gitBashProfile) {
            Write-Skip "Git Bash profile already exists in Windows Terminal"
            # Still apply customizations
            $gitBashProfile | Add-Member -NotePropertyName "font" -NotePropertyValue @{
                face   = "Delugia"
                size   = 14
                weight = "normal"
            } -Force
            $gitBashProfile | Add-Member -NotePropertyName "backgroundImage"            -NotePropertyValue "$bgDir/git-bash.png" -Force
            $gitBashProfile | Add-Member -NotePropertyName "backgroundImageOpacity"     -NotePropertyValue 0.15                  -Force
            $gitBashProfile | Add-Member -NotePropertyName "backgroundImageStretchMode" -NotePropertyValue "uniformToFill"       -Force
            $gitBashProfile | Add-Member -NotePropertyName "useAcrylic"                 -NotePropertyValue $true                 -Force
            $gitBashProfile | Add-Member -NotePropertyName "opacity"                    -NotePropertyValue 85                    -Force
            Write-Ok "Git Bash profile customized"
            Mark-Skipped
        } elseif (Test-Path $gitBashExe) {
            Write-Info "Adding Git Bash profile to Windows Terminal..."
            $newGitBash = [PSCustomObject]@{
                guid                       = "{6721e727-40c5-4b27-ac6b-3a0c4f3a5e17}"
                name                       = "Git Bash"
                commandline                = "$gitBashExe -i -l"
                icon                       = "C:\Program Files\Git\mingw64\share\git\git-for-windows.ico"
                startingDirectory          = "%USERPROFILE%"
                hidden                     = $false
                font                       = @{ face = "Delugia"; size = 14; weight = "normal" }
                backgroundImage            = "$bgDir/git-bash.png"
                backgroundImageOpacity     = 0.15
                backgroundImageStretchMode = "uniformToFill"
                useAcrylic                 = $true
                opacity                    = 85
            }
            $settingsJson.profiles.list += $newGitBash
            Write-Ok "Git Bash profile added and customized"
            Mark-Installed
        } else {
            Write-Warn "Git Bash not found at $gitBashExe — skipping Git Bash profile"
            Mark-Skipped
        }

        # Write back settings.json
        $settingsJson | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Encoding UTF8
        Write-Ok "Windows Terminal settings.json updated"
    }
}

# ── Section 7: Git Global Configuration ───────────────────────────────────
Write-Section "Git Global Configuration"

if (Test-CommandExists "git") {
    $currentName = git config --global user.name 2>$null
    if ($currentName -eq "asudbring") {
        Write-Skip "Git user.name already set"
        Mark-Skipped
    } else {
        git config --global user.name "asudbring"
        Write-Ok "Git user.name set to asudbring"
        Mark-Installed
    }

    $currentEmail = git config --global user.email 2>$null
    if ($currentEmail -eq "allen@sudbring.com") {
        Write-Skip "Git user.email already set"
        Mark-Skipped
    } else {
        git config --global user.email "allen@sudbring.com"
        Write-Ok "Git user.email set to allen@sudbring.com"
        Mark-Installed
    }

    # GCM Core (bundled with Git for Windows)
    git config --global credential.helper manager
    git config --global credential.https://dev.azure.com.useHttpPath true
    Write-Ok "Git Credential Manager configured"

    # git-delta pager
    if (Test-CommandExists "delta") {
        $currentPager = git config --global core.pager 2>$null
        if ($currentPager -like "*delta*") {
            Write-Skip "git-delta already configured as pager"
            Mark-Skipped
        } else {
            git config --global core.pager "delta"
            git config --global interactive.diffFilter "delta --color-only"
            git config --global delta.navigate true
            git config --global delta.line-numbers true
            git config --global delta.side-by-side false
            git config --global merge.conflictStyle "diff3"
            git config --global diff.colorMoved "default"
            Write-Ok "git-delta configured as pager"
            Mark-Installed
        }
    } else {
        Write-Warn "delta not found — skipping git pager config"
    }
} else {
    Write-Fail "Git not found — cannot configure"
    Mark-Failed
}

# ── Section 8: SSH Key Setup (sudbringlab servers) ────────────────────────
Write-Section "SSH Key Setup (sudbringlab servers)"

$SshGistId   = "639363ac7797dced788c7b2706986fc6"
$SshKeyPath  = "$HOME\.ssh\sudbringlab"
$SshConfig   = "$HOME\.ssh\config"
$SshMarker   = "# Managed by install-windows.ps1 — sudbringlab"

if ($SshGistId -eq "PASTE_GIST_ID_HERE") {
    Write-Warn "SSH gist ID not configured — run setup-ssh-keys.sh first, then paste the gist ID"
    Write-Warn "Look for `$SshGistId= near the top of the SSH section in this script"
    Mark-Skipped
} elseif (Test-Path $SshKeyPath) {
    Write-Skip "SSH key already exists at $SshKeyPath"
    Mark-Skipped
} else {
    # Prompt user
    $setupSsh = Read-Host "Set up SSH keys for sudbringlab servers? (y/N)"

    if ($setupSsh -eq "y" -or $setupSsh -eq "Y") {
        if (-not (Test-CommandExists "age")) {
            Write-Fail "age not found — should have been installed via winget"
            Mark-Failed
        } elseif (-not (Test-CommandExists "gh")) {
            Write-Fail "gh CLI not found — cannot download SSH key"
            Mark-Failed
        } else {
            $sshDir = "$HOME\.ssh"
            if (-not (Test-Path $sshDir)) {
                New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
            }

            Write-Info "Downloading encrypted SSH key from GitHub Gist..."
            $encryptedB64 = gh gist view $SshGistId -f sudbringlab.age.b64 --raw 2>$null

            if (-not $encryptedB64) {
                Write-Fail "Failed to download SSH key from gist $SshGistId"
                Mark-Failed
            } else {
                Write-Info "Decrypting SSH key (enter your passphrase)..."
                $tempEncrypted = "$env:TEMP\sudbringlab_$PID.age"
                [System.Convert]::FromBase64String($encryptedB64) | Set-Content $tempEncrypted -AsByteStream

                age -d -o $SshKeyPath $tempEncrypted
                Remove-Item $tempEncrypted -Force -ErrorAction SilentlyContinue

                if (Test-Path $SshKeyPath) {
                    Write-Ok "SSH private key written to $SshKeyPath"
                    Mark-Installed

                    # Download public key
                    try {
                        $pubKey = gh gist view $SshGistId -f sudbringlab.pub --raw 2>$null
                        if ($pubKey) {
                            $pubKey | Set-Content "${SshKeyPath}.pub"
                            Write-Ok "SSH public key written to ${SshKeyPath}.pub"
                        }
                    } catch {}

                    # Configure ~/.ssh/config
                    $configExists = $false
                    if (Test-Path $SshConfig) {
                        $configContent = Get-Content $SshConfig -Raw -ErrorAction SilentlyContinue
                        if ($configContent -match [regex]::Escape($SshMarker)) {
                            $configExists = $true
                        }
                    }

                    if ($configExists) {
                        Write-Skip "SSH config entries already present"
                        Mark-Skipped
                    } else {
                        Write-Info "Adding sudbringlab hosts to $SshConfig..."
                        $sshConfigBlock = @"

$SshMarker
Host media-server.sudbringlab.com
    HostName media-server.sudbringlab.com
    User allenadmin
    IdentityFile ~/.ssh/sudbringlab

Host media.sudbringlab.com
    HostName media.sudbringlab.com
    User allenadmin
    IdentityFile ~/.ssh/sudbringlab
"@
                        Add-Content -Path $SshConfig -Value $sshConfigBlock
                        Write-Ok "SSH config updated with sudbringlab hosts"
                        Mark-Installed
                    }
                } else {
                    Write-Fail "Decryption failed — SSH key not written"
                    Mark-Failed
                }
            }
        }
    } else {
        Write-Skip "SSH key setup skipped by user"
        Mark-Skipped
    }
}

# ── Section 9: Post-Install ───────────────────────────────────────────────
Write-Section "Post-Install"

# Refresh PATH one more time
Update-Path

# --- GitHub CLI auth ---
if (Test-CommandExists "gh") {
    $authStatus = gh auth status 2>&1
    if ($authStatus -match "Logged in") {
        Write-Skip "GitHub CLI already authenticated"
        Mark-Skipped
    } else {
        Write-Info "GitHub CLI authentication required..."
        Write-Info "Running 'gh auth login' — follow the prompts"
        gh auth login
        Mark-Installed
    }

    # gh copilot check
    $copilotCheck = gh copilot --version 2>&1
    if ($copilotCheck -match "version") {
        Write-Skip "GitHub Copilot CLI (gh extension) already available"
        Mark-Skipped
    } else {
        Write-Info "gh copilot may need first-run acceptance — run 'gh copilot' manually if needed"
    }
} else {
    Write-Warn "GitHub CLI not found — skipping auth"
}

# --- Azure Bicep ---
if (Test-CommandExists "az") {
    $bicepVer = az bicep version 2>$null
    if ($bicepVer) {
        Write-Skip "Azure Bicep already installed ($bicepVer)"
        Mark-Skipped

        Write-Info "Upgrading Azure Bicep..."
        az bicep upgrade 2>$null
        Mark-Updated
    } else {
        Write-Info "Installing Azure Bicep..."
        az bicep install 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Azure Bicep installed"
            Mark-Installed
        } else {
            Write-Fail "Azure Bicep installation failed"
            Mark-Failed
        }
    }
} else {
    Write-Warn "Azure CLI not found — skipping Bicep install"
}

# --- npm globals ---
if (Test-CommandExists "npm") {
    # context-mode
    if (Test-CommandExists "ctx") {
        Write-Skip "context-mode already installed"
        Mark-Skipped
        Write-Info "Updating context-mode..."
        npm update -g context-mode 2>$null
        Mark-Updated
    } else {
        Write-Info "Installing context-mode..."
        npm install -g context-mode 2>$null
        if (Test-CommandExists "ctx") {
            Write-Ok "context-mode installed"
            Mark-Installed
        } else {
            Write-Fail "context-mode installation failed"
            Mark-Failed
        }
    }

    # GitHub Copilot CLI agent (@github/copilot)
    if (Test-CommandExists "copilot") {
        Write-Skip "GitHub Copilot CLI agent already installed"
        Mark-Skipped
        Write-Info "Updating @github/copilot..."
        npm update -g @github/copilot 2>$null
        Mark-Updated
    } else {
        Write-Info "Installing @github/copilot..."
        npm install -g @github/copilot 2>$null
        Update-Path
        if (Test-CommandExists "copilot") {
            Write-Ok "GitHub Copilot CLI agent installed"
            Mark-Installed
        } else {
            Write-Fail "GitHub Copilot CLI agent installation failed"
            Mark-Failed
        }
    }
} else {
    Write-Warn "npm not found — skipping global npm installs"
}

# ── Summary ───────────────────────────────────────────────────────────────
Write-Section "Summary"

Write-Host "  Installed:  $Script:INSTALLED" -ForegroundColor Green
Write-Host "  Updated:    $Script:UPDATED"   -ForegroundColor Cyan
Write-Host "  Skipped:    $Script:SKIPPED"   -ForegroundColor Yellow
Write-Host "  Failed:     $Script:FAILED"    -ForegroundColor Red
Write-Host ""

if ($Script:FAILED -gt 0) {
    Write-Warn "Some installations failed. Review output above and re-run."
}

Write-Info "You may need to restart your terminal or computer for all changes to take effect."
Write-Info "If WSL was installed, a reboot is required."
Write-Host ""
Write-Ok "Windows workstation setup complete!"
