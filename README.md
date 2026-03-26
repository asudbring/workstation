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

_Coming soon._
