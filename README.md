# workstation

Repo for workstation setup scripts and support files. Each script is idempotent — safe to run on a fresh machine or re-run on an existing one to update everything.

## macOS

### Quick start

On a fresh Mac, open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/asudbring/workstation/main/install-macos.sh | bash
```

Or download first, inspect, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/asudbring/workstation/main/install-macos.sh -o install-macos.sh
chmod +x install-macos.sh
./install-macos.sh
```

If you already have the repo cloned:

```bash
chmod +x install-macos.sh
./install-macos.sh
```

The script works in two modes:

- **Fresh install** — installs everything from scratch on a new machine
- **Update/maintenance** — upgrades all existing packages and tools to latest versions when re-run

### What gets installed

#### Package manager

| Component | Details |
|---|---|
| Homebrew | Installed if missing. On re-run, runs `brew update`, `brew upgrade`, and `brew upgrade --cask` to update all managed packages. |

#### CLI tools (Homebrew formulae)

| Tool | Command | Purpose |
|---|---|---|
| Git | `git` | Version control |
| Node.js | `node`, `npm`, `npx` | JavaScript runtime and package manager |
| Python | `python3`, `pip3` | Python runtime |
| Terraform | `terraform` | Infrastructure as code |
| GitHub CLI | `gh` | GitHub operations (PRs, issues, repos) |
| Azure CLI | `az` | Azure resource management |
| ripgrep | `rg` | Fast grep that respects .gitignore |
| fd | `fd` | Modern `find` replacement |
| fzf | `fzf` | Interactive fuzzy finder |
| DuckDB | `duckdb` | SQL on CSV/Parquet/JSON files |
| git-delta | `delta` | Better git diff output for AI parsing |
| xh | `xh` | Structured HTTP client output |
| watchexec | `watchexec` | Auto-rerun commands on file changes |
| just | `just` | Simple task runner |
| semgrep | `semgrep` | Static code analysis |
| oh-my-posh | `oh-my-posh` | Prompt theme engine |

#### GUI applications (Homebrew casks)

| Cask | Application |
|---|---|
| `microsoft-edge` | Microsoft Edge |
| `visual-studio-code` | VS Code |
| `docker` | Docker Desktop |
| `powershell` | PowerShell (`pwsh`) |
| `snagit` | Snagit (screen capture) |
| `microsoft-office` | Microsoft Office 365 |
| `windows-app` | Windows App (RDP) |
| `claude` | Claude Desktop |

> Apps already installed outside of Homebrew (e.g., Claude, Office) are detected and skipped.

#### Fonts

| Font | Source | Purpose |
|---|---|---|
| Delugia Nerd Font | [GitHub releases](https://github.com/adam7/delugia-code/releases) | Patched font with glyphs for Agnoster theme |

Downloaded via `curl` from GitHub and installed to `~/Library/Fonts`.

#### Special installs (not via Homebrew)

| Tool | Install method | Update method |
|---|---|---|
| Bun | `curl -fsSL https://bun.sh/install \| bash` | `bun upgrade` |
| oh-my-zsh | Official install script | `omz update --unattended` |

#### AI coding tools

| Tool | Install method | Update method |
|---|---|---|
| GitHub Copilot CLI agent | `npm install -g @github/copilot` | `npm update -g @github/copilot` |
| OpenCode | `brew install opencode` | Updated via `brew upgrade` |
| context-mode | `npm install -g context-mode` | `npm update -g context-mode` |

### Shell configuration

#### Zsh (`~/.zshrc`)

- **Theme**: oh-my-zsh with Agnoster
- **Plugins**: `(git)`
- **PATH additions**:
  - `$HOME/.dotnet/tools`
  - `$HOME/.local/bin`
- **Aliases**:
  - `claude-local` — routes Claude Code to local Ollama proxy at `localhost:4001`

#### PowerShell (`~/.config/powershell/profile.ps1`)

- Homebrew shellenv initialization
- oh-my-posh with Agnoster theme
- Modules installed and updated on re-run:

| Module | Purpose |
|---|---|
| Az | Azure PowerShell management |
| PSReadLine | Enhanced command-line editing |
| posh-git | Git status in prompt |

> The script appends to existing PowerShell profiles rather than overwriting. A marker comment (`# Managed by install-macos.sh`) prevents duplicate entries on re-run.

### Terminal.app preferences

| Setting | Value |
|---|---|
| Default profile | Homebrew |
| Startup profile | Homebrew |
| Font | Delugia-Regular, 18pt |
| Cursor | Block, blink enabled |
| Font antialias | Off |

Applied via `defaults write` and Python `plistlib` for the NSKeyedArchiver font encoding.

### Git global configuration

| Setting | Value |
|---|---|
| `user.name` | `asudbring` |
| `user.email` | `allen@sudbring.com` |
| `credential.helper` | GCM Core (`git-credential-manager`) |
| `credential.https://dev.azure.com.usehttppath` | `true` |
| `core.pager` | `delta` |
| `delta.navigate` | `true` |
| `delta.line-numbers` | `true` |

### Post-install steps

| Component | Command | Update method |
|---|---|---|
| GitHub CLI auth | `gh auth login` (interactive) | Skipped if already authenticated |
| GitHub Copilot (built-in) | Detected automatically in newer `gh` versions | N/A |
| Bicep tools | `az bicep install` | `az bicep upgrade` |

### Running as a scheduled update

The script can be re-run at any time to update all tools. On subsequent runs it will:

1. Update Homebrew and upgrade all formulae and casks
2. Update Bun, oh-my-zsh, and npm globals to latest versions
3. Update PowerShell modules (Az, PSReadLine, posh-git)
4. Upgrade Bicep tools
5. Skip all configuration steps that are already applied
6. Report a summary of installed, updated, skipped, and failed items

```bash
# Example: run via cron or launchd
0 8 * * 1  /path/to/install-macos.sh >> /tmp/workstation-update.log 2>&1
```

### Summary output

The script prints a color-coded summary at the end:

```
Installed:  3
Updated:    12
Skipped:    28
Failed:     0
```

## Linux

_Coming soon._

## Windows

### Quick start

On a fresh Windows machine, open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/asudbring/workstation/main/install-windows.ps1 | iex
```

> **Note:** The one-liner won't have access to the terminal background images (stored in `assets/`). For the full experience with Windows Terminal backgrounds, clone the repo first:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
git clone https://github.com/asudbring/workstation.git
cd workstation
.\install-windows.ps1
```

Or download first, inspect, then run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-WebRequest -Uri https://raw.githubusercontent.com/asudbring/workstation/main/install-windows.ps1 -OutFile install-windows.ps1
.\install-windows.ps1
```

If you already have the repo cloned:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-windows.ps1
```

The script works in two modes:

- **Fresh install** — installs everything from scratch on a new machine
- **Update/maintenance** — runs `winget upgrade --all`, `choco upgrade all`, updates npm globals and PowerShell modules when re-run

> **Note:** The script requires Administrator privileges. It will refuse to run without elevation.

### What gets installed

#### Package managers

| Component | Details |
|---|---|
| winget | Verified as present (pre-installed on Windows 11). On re-run, runs `winget upgrade --all`. |
| Chocolatey | Installed as backup package manager. On re-run, runs `choco upgrade all`. |

#### GUI applications + CLI tools (winget)

| Winget ID | Application |
|---|---|
| `Microsoft.Edge` | Microsoft Edge |
| `Microsoft.VisualStudioCode` | VS Code |
| `Docker.DockerDesktop` | Docker Desktop |
| `Git.Git` | Git |
| `OpenJS.NodeJS.LTS` | Node.js LTS |
| `Python.Python.3.13` | Python 3.13 |
| `Hashicorp.Terraform` | Terraform |
| `GitHub.cli` | GitHub CLI |
| `Microsoft.AzureCLI` | Azure CLI |
| `Microsoft.PowerShell` | PowerShell 7 |
| `JanDeDobbeleer.OhMyPosh` | oh-my-posh |
| `TechSmith.Snagit` | Snagit |
| `Microsoft.Office` | Microsoft Office 365 |
| `Microsoft.WindowsTerminal` | Windows Terminal |
| `Microsoft.WindowsApp` | Windows App (RDP) |
| `Anthropic.Claude` | Claude Desktop |

#### AI-optimized dev tools (winget)

| Winget ID | Command | Purpose |
|---|---|---|
| `BurntSushi.ripgrep.MSVC` | `rg` | Fast grep that respects .gitignore |
| `sharkdp.fd` | `fd` | Modern `find` replacement |
| `junegunn.fzf` | `fzf` | Interactive fuzzy finder |
| `DuckDB.cli` | `duckdb` | SQL on CSV/Parquet/JSON files |
| `dandavison.delta` | `delta` | Better git diff output for AI parsing |
| `ducaale.xh` | `xh` | Structured HTTP client output |
| `Casey.Just` | `just` | Simple task runner |

#### Fonts

| Font | Source | Purpose |
|---|---|---|
| Delugia Nerd Font | [GitHub releases](https://github.com/adam7/delugia-code/releases) | Patched font with glyphs for Agnoster theme and Windows Terminal |

Downloaded from GitHub, installed to `C:\Windows\Fonts` with registry entries.

#### Special installs

| Tool | Install method | Update method |
|---|---|---|
| watchexec | GitHub release download (not in winget) | Re-run downloads latest |
| semgrep | `pip install semgrep` | `pip install --upgrade semgrep` |
| Bun | `irm bun.sh/install.ps1 \| iex` | `bun upgrade` |
| WSL + Ubuntu | `wsl --install -d Ubuntu` | Updated via Windows Update |

> **Note:** WSL installation requires a reboot. The script warns you and skips if Ubuntu is already installed.

#### AI coding tools

| Tool | Install method | Update method |
|---|---|---|
| GitHub Copilot CLI agent | `npm install -g @github/copilot` | `npm update -g @github/copilot` |
| OpenCode | `npm install -g opencode-ai` | `npm update -g opencode-ai` |
| context-mode | `npm install -g context-mode` | `npm update -g context-mode` |

### PowerShell configuration (both versions)

The script configures **both** PowerShell versions:

| Version | Executable | Profile path |
|---|---|---|
| Windows PowerShell 5.1 | `powershell.exe` | `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `pwsh.exe` | `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**Both profiles get:**

- `Import-Module posh-git`
- `oh-my-posh init pwsh` with Agnoster theme

**Modules installed in both versions:**

| Module | Purpose |
|---|---|
| Az | Azure PowerShell management |
| PSReadLine | Enhanced command-line editing |
| posh-git | Git status in prompt |

> The script appends to existing profiles rather than overwriting. A marker comment (`# Managed by install-windows.ps1`) prevents duplicate entries on re-run.

### Windows Terminal customization

The script customizes **5 profiles** in Windows Terminal with themed backgrounds, Delugia font, and acrylic transparency.

| Profile | Background theme | Background file |
|---|---|---|
| Windows PowerShell 5.1 | Dark blue gradient | `powershell-classic.png` |
| PowerShell 7 | Dark purple gradient | `powershell-core.png` |
| Ubuntu WSL | Dark aubergine/orange gradient | `ubuntu-wsl.png` |
| Azure Cloud Shell | Dark teal/azure gradient | `azure-cloudshell.png` |
| Git Bash | Dark red/charcoal gradient | `git-bash.png` |

**All profiles:**

| Setting | Value |
|---|---|
| Font | Delugia, size 14 |
| Background image opacity | 0.15 (subtle) |
| Background stretch | uniformToFill |
| Acrylic transparency | Enabled, opacity 85% |

- Background images are stored in the repo under `assets/windows-terminal/` and copied to `$HOME\.terminal-backgrounds\` during install
- Git Bash profile is **created automatically** if Git is installed but the profile doesn't exist
- A backup of `settings.json` is created before any modifications

### Git global configuration

| Setting | Value |
|---|---|
| `user.name` | `asudbring` |
| `user.email` | `allen@sudbring.com` |
| `credential.helper` | `manager` (Git Credential Manager, bundled with Git for Windows) |
| `credential.https://dev.azure.com.usehttppath` | `true` |
| `core.pager` | `delta` |
| `delta.navigate` | `true` |
| `delta.line-numbers` | `true` |

### Post-install steps

| Component | Command | Update method |
|---|---|---|
| GitHub CLI auth | `gh auth login` (interactive) | Skipped if already authenticated |
| GitHub Copilot (built-in) | Detected automatically in newer `gh` versions | N/A |
| Bicep tools | `az bicep install` | `az bicep upgrade` |

### Running as a scheduled update

The script can be re-run at any time to update all tools. On subsequent runs it will:

1. Run `winget upgrade --all` and `choco upgrade all`
2. Update Bun, semgrep, and npm globals to latest versions
3. Update PowerShell modules (Az, PSReadLine, posh-git) in both PS versions
4. Upgrade Bicep tools
5. Skip all configuration steps that are already applied
6. Report a summary of installed, updated, skipped, and failed items

```powershell
# Example: run via Windows Task Scheduler
# Action: pwsh.exe
# Arguments: -ExecutionPolicy Bypass -File "C:\path\to\install-windows.ps1"
# Trigger: Weekly, Monday 8:00 AM
# Run with highest privileges: Yes
```

### Summary output

The script prints a color-coded summary at the end:

```
Installed:  3
Updated:    12
Skipped:    28
Failed:     0
```
