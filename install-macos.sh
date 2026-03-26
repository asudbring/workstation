#!/usr/bin/env bash
# ============================================================================
# install-macos.sh — macOS Workstation Setup Script
# ============================================================================
# Idempotent install script for provisioning a new macOS workstation with all
# development tools, CLI utilities, GUI apps, shell customizations, and
# terminal preferences used by Allen Sudbring for Azure documentation work.
#
# Usage:
#   chmod +x install-macos.sh
#   ./install-macos.sh
#
# Safe to re-run — checks for each component before installing.
# ============================================================================

set -euo pipefail

# ── Color helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
INSTALLED=0
SKIPPED=0
FAILED=0
UPDATED=0

info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[OK]${NC}      $*"; }
skip()    { echo -e "${YELLOW}[SKIP]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}    $*"; }
section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${CYAN}  $*${NC}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"; }

mark_installed() { ((INSTALLED++)) || true; }
mark_skipped()   { ((SKIPPED++)) || true; }
mark_failed()    { ((FAILED++)) || true; }
mark_updated()   { ((UPDATED++)) || true; }

# ── Pre-flight checks ─────────────────────────────────────────────────────
section "Pre-flight Checks"

# Verify macOS
if [[ "$(uname)" != "Darwin" ]]; then
    fail "This script is for macOS only. Detected: $(uname)"
    exit 1
fi
success "Running on macOS $(sw_vers -productVersion)"

# Check for Xcode Command Line Tools
if xcode-select -p &>/dev/null; then
    skip "Xcode Command Line Tools already installed"
    mark_skipped
else
    info "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Press any key after Xcode CLT installation completes..."
    read -r -n 1
    mark_installed
fi

# ── Section 1: Homebrew ───────────────────────────────────────────────────
section "Homebrew Package Manager"

if command -v brew &>/dev/null; then
    skip "Homebrew already installed ($(brew --version | head -1))"
    mark_skipped
else
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        success "Homebrew installed"
        mark_installed
    else
        fail "Homebrew installation failed"
        mark_failed
        exit 1
    fi
fi

# Ensure Homebrew is in PATH for the rest of the script
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

info "Updating Homebrew and upgrading all packages..."
brew update --quiet

info "Upgrading Homebrew formulae..."
if brew upgrade --quiet 2>/dev/null; then
    success "Homebrew formulae upgraded"
else
    info "No formulae to upgrade (or already up to date)"
fi

info "Upgrading Homebrew casks..."
if brew upgrade --cask --quiet 2>/dev/null; then
    success "Homebrew casks upgraded"
else
    info "No casks to upgrade (or already up to date)"
fi

# ── Section 2: Homebrew Formulae (CLI tools) ──────────────────────────────
section "Homebrew Formulae (CLI Tools)"

FORMULAE=(
    "git"
    "node"
    "python"
    "terraform"
    "gh"
    "azure-cli"
    "ripgrep"
    "fd"
    "fzf"
    "duckdb"
    "git-delta"
    "xh"
    "watchexec"
    "just"
    "semgrep"
    "oh-my-posh"
)

for formula in "${FORMULAE[@]}"; do
    if brew list --formula "$formula" &>/dev/null; then
        skip "$formula already installed"
        mark_skipped
    else
        info "Installing $formula..."
        if brew install "$formula" --quiet; then
            success "$formula installed"
            mark_installed
        else
            fail "$formula installation failed"
            mark_failed
        fi
    fi
done

# ── Section 3: Homebrew Casks (GUI apps) ──────────────────────────────────
section "Homebrew Casks (GUI Applications)"

CASKS=(
    "microsoft-edge"
    "visual-studio-code"
    "docker"
    "powershell"
    "snagit"
    "microsoft-office"
    "windows-app"
    "claude"
)

for cask in "${CASKS[@]}"; do
    # Check brew first, then check if the app exists outside of brew
    if brew list --cask "$cask" &>/dev/null; then
        skip "$cask already installed (via brew)"
        mark_skipped
    elif [[ "$cask" == "claude" ]] && [[ -d "/Applications/Claude.app" ]]; then
        skip "$cask already installed (not managed by brew)"
        mark_skipped
    elif [[ "$cask" == "microsoft-office" ]] && [[ -d "/Applications/Microsoft Word.app" ]]; then
        skip "$cask already installed (not managed by brew)"
        mark_skipped
    else
        info "Installing $cask..."
        if brew install --cask "$cask" --quiet; then
            success "$cask installed"
            mark_installed
        else
            fail "$cask installation failed"
            mark_failed
        fi
    fi
done

# ── Section 4: Font Installation ──────────────────────────────────────────
section "Font Installation"

# Delugia Nerd Font (required for Agnoster theme glyphs)
# Not available via Homebrew — download directly from GitHub
if find "$HOME/Library/Fonts" /Library/Fonts -iname "*Delugia*" -print -quit 2>/dev/null | grep -q .; then
    skip "Delugia Nerd Font already installed"
    mark_skipped
else
    info "Downloading Delugia Nerd Font from GitHub..."
    FONT_URL="https://github.com/adam7/delugia-code/releases/latest/download/Delugia.zip"
    FONT_DIR="$HOME/Library/Fonts"
    TMPDIR_FONT=$(mktemp -d)
    mkdir -p "$FONT_DIR"
    if curl -fsSL "$FONT_URL" -o "$TMPDIR_FONT/Delugia.zip" && \
       unzip -qo "$TMPDIR_FONT/Delugia.zip" -d "$TMPDIR_FONT/fonts" && \
       find "$TMPDIR_FONT/fonts" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;; then
        success "Delugia Nerd Font installed from GitHub"
        mark_installed
    else
        fail "Delugia Nerd Font installation failed — install manually from https://github.com/adam7/delugia-code/releases"
        mark_failed
    fi
    rm -rf "$TMPDIR_FONT" 2>/dev/null || true
fi

# ── Section 5: Special Installs ───────────────────────────────────────────
section "Special Installs (Bun, oh-my-zsh)"

# Bun — fast JavaScript runtime
if command -v bun &>/dev/null; then
    info "Bun found ($(bun --version)) — checking for updates..."
    if bun upgrade 2>/dev/null; then
        success "Bun updated to latest"
        mark_updated
    else
        skip "Bun already at latest version"
        mark_skipped
    fi
else
    info "Installing Bun..."
    if curl -fsSL https://bun.sh/install | bash; then
        # Add Bun to PATH for current session
        export PATH="$HOME/.bun/bin:$PATH"
        success "Bun installed"
        mark_installed
    else
        fail "Bun installation failed"
        mark_failed
    fi
fi

# oh-my-zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    info "oh-my-zsh found — checking for updates..."
    if env ZSH="$HOME/.oh-my-zsh" DISABLE_AUTO_UPDATE=true zsh -c 'source $ZSH/oh-my-zsh.sh && omz update --unattended' 2>/dev/null; then
        success "oh-my-zsh updated"
        mark_updated
    else
        skip "oh-my-zsh already up to date"
        mark_skipped
    fi
else
    info "Installing oh-my-zsh..."
    if RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
        success "oh-my-zsh installed"
        mark_installed
    else
        fail "oh-my-zsh installation failed"
        mark_failed
    fi
fi

# ── Section 6: Shell Configuration ────────────────────────────────────────
section "Shell Configuration"

ZSHRC="$HOME/.zshrc"

# oh-my-zsh Agnoster theme
if [[ -f "$ZSHRC" ]]; then
    if grep -q 'ZSH_THEME="agnoster"' "$ZSHRC"; then
        skip "oh-my-zsh Agnoster theme already configured"
        mark_skipped
    else
        info "Setting oh-my-zsh theme to Agnoster..."
        sed -i '' 's/^[[:space:]]*ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$ZSHRC"
        success "oh-my-zsh theme set to Agnoster"
        mark_installed
    fi
else
    warn "~/.zshrc not found — oh-my-zsh may not be installed correctly"
fi

# PATH: $HOME/.dotnet/tools
if [[ ! -f "$ZSHRC" ]]; then
    warn "~/.zshrc not found — skipping .dotnet/tools PATH"
elif grep -q '\.dotnet/tools' "$ZSHRC"; then
    skip "PATH \$HOME/.dotnet/tools already in .zshrc"
    mark_skipped
else
    info "Adding \$HOME/.dotnet/tools to PATH in .zshrc..."
    echo '' >> "$ZSHRC"
    echo 'export PATH="$HOME/.dotnet/tools:$PATH"' >> "$ZSHRC"
    success "Added .dotnet/tools to PATH"
    mark_installed
fi

# PATH: $HOME/.local/bin
if [[ ! -f "$ZSHRC" ]]; then
    warn "~/.zshrc not found — skipping .local/bin PATH"
elif grep -q '\.local/bin' "$ZSHRC"; then
    skip "PATH \$HOME/.local/bin already in .zshrc"
    mark_skipped
else
    info "Adding \$HOME/.local/bin to PATH in .zshrc..."
    echo '' >> "$ZSHRC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
    success "Added .local/bin to PATH"
    mark_installed
fi

# Claude local alias
if [[ ! -f "$ZSHRC" ]]; then
    warn "~/.zshrc not found — skipping claude-local alias"
elif grep -q 'claude-local' "$ZSHRC"; then
    skip "claude-local alias already in .zshrc"
    mark_skipped
else
    info "Adding claude-local alias to .zshrc..."
    echo '' >> "$ZSHRC"
    echo '# Claude Code — local model alias (routes to Ollama via proxy at localhost:4001)' >> "$ZSHRC"
    echo "alias claude-local='ANTHROPIC_BASE_URL=http://localhost:4001 ANTHROPIC_API_KEY=sk-local-proxy claude'" >> "$ZSHRC"
    success "claude-local alias added"
    mark_installed
fi

# PowerShell profile
PWSH_PROFILE_DIR="$HOME/.config/powershell"
PWSH_PROFILE="$PWSH_PROFILE_DIR/profile.ps1"
PWSH_MARKER="# Managed by install-macos.sh"

if [[ -f "$PWSH_PROFILE" ]] && grep -q "$PWSH_MARKER" "$PWSH_PROFILE"; then
    skip "PowerShell profile already configured by this script"
    mark_skipped
else
    info "Configuring PowerShell profile..."
    mkdir -p "$PWSH_PROFILE_DIR"
    if [[ -f "$PWSH_PROFILE" ]]; then
        warn "Existing profile.ps1 found — backing up to profile.ps1.bak"
        cp "$PWSH_PROFILE" "$PWSH_PROFILE.bak"
        # Preserve existing content and append our config
        echo '' >> "$PWSH_PROFILE"
        echo "$PWSH_MARKER" >> "$PWSH_PROFILE"
    else
        echo "$PWSH_MARKER" > "$PWSH_PROFILE"
    fi
    cat >> "$PWSH_PROFILE" << 'PWSH_EOF'

# Initialize Homebrew for PowerShell
$(/opt/homebrew/bin/brew shellenv) | Invoke-Expression

# oh-my-posh theme
oh-my-posh init pwsh --config "https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/agnoster.omp.json" | Invoke-Expression
PWSH_EOF
    success "PowerShell profile configured"
    mark_installed
fi

# PowerShell modules (Az, PSReadLine, posh-git)
if command -v pwsh &>/dev/null; then
    info "Installing PowerShell modules (this may take a few minutes)..."

    # Az module
    if pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name Az) { exit 0 } else { exit 1 }" 2>/dev/null; then
        info "Az module found — updating..."
        if pwsh -NoProfile -Command "Update-Module -Name Az -Force -Scope CurrentUser -ErrorAction SilentlyContinue" 2>/dev/null; then
            success "Az module updated"
            mark_updated
        else
            skip "Az module already at latest version"
            mark_skipped
        fi
    else
        info "Installing Az PowerShell module..."
        if pwsh -NoProfile -Command "Install-Module -Name Az -Force -AcceptLicense -Scope CurrentUser" 2>/dev/null; then
            success "Az module installed"
            mark_installed
        else
            fail "Az module installation failed"
            mark_failed
        fi
    fi

    # PSReadLine
    if pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PSReadLine) { exit 0 } else { exit 1 }" 2>/dev/null; then
        info "PSReadLine found — updating..."
        if pwsh -NoProfile -Command "Update-Module -Name PSReadLine -Force -Scope CurrentUser -ErrorAction SilentlyContinue" 2>/dev/null; then
            success "PSReadLine updated"
            mark_updated
        else
            skip "PSReadLine already at latest version"
            mark_skipped
        fi
    else
        info "Installing PSReadLine module..."
        if pwsh -NoProfile -Command "Install-Module -Name PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck" 2>/dev/null; then
            success "PSReadLine module installed"
            mark_installed
        else
            fail "PSReadLine module installation failed"
            mark_failed
        fi
    fi

    # posh-git
    if pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name posh-git) { exit 0 } else { exit 1 }" 2>/dev/null; then
        info "posh-git found — updating..."
        if pwsh -NoProfile -Command "Update-Module -Name posh-git -Force -Scope CurrentUser -ErrorAction SilentlyContinue" 2>/dev/null; then
            success "posh-git updated"
            mark_updated
        else
            skip "posh-git already at latest version"
            mark_skipped
        fi
    else
        info "Installing posh-git module..."
        if pwsh -NoProfile -Command "Install-Module -Name posh-git -Scope CurrentUser -Force" 2>/dev/null; then
            success "posh-git module installed"
            mark_installed
        else
            fail "posh-git module installation failed"
            mark_failed
        fi
    fi
else
    warn "PowerShell (pwsh) not found — skipping module installs"
fi

# ── Section 7: Terminal.app Preferences ───────────────────────────────────
section "Terminal.app Preferences"

CURRENT_DEFAULT=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || echo "")

if [[ "$CURRENT_DEFAULT" == "Homebrew" ]]; then
    skip "Terminal.app default profile already set to Homebrew"
    mark_skipped
else
    info "Setting Terminal.app default profile to Homebrew..."
    defaults write com.apple.Terminal "Default Window Settings" -string "Homebrew"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Homebrew"
    success "Terminal.app default/startup profile set to Homebrew"
    mark_installed
fi

# Set Terminal.app Homebrew profile font to Delugia-Regular 18pt
# The font is stored as an NSKeyedArchiver blob — we use Python to generate it
if command -v python3 &>/dev/null; then
    CURRENT_FONT=$(python3 -c "
import subprocess, plistlib
try:
    result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
    plist = plistlib.loads(result.stdout)
    ws = plist.get('Window Settings', {})
    hb = ws.get('Homebrew', {})
    font_data = hb.get('Font')
    if font_data:
        font_plist = plistlib.loads(font_data)
        objs = font_plist.get('\$objects', [])
        for obj in objs:
            if isinstance(obj, str) and 'Delugia' in obj:
                print('Delugia')
                break
        else:
            print('Other')
    else:
        print('NoFont')
except Exception:
    print('Error')
" 2>/dev/null)

    if [[ "$CURRENT_FONT" == "Delugia" ]]; then
        skip "Terminal.app Homebrew profile font already Delugia"
        mark_skipped
    else
        info "Setting Terminal.app Homebrew profile font to Delugia-Regular 18pt..."
        FONT_RESULT=$(python3 -c "
import subprocess, plistlib

# Read current Terminal plist
result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
plist = plistlib.loads(result.stdout)

# Create NSKeyedArchiver-encoded NSFont for Delugia-Regular 18pt
font_archive = {
    '\$version': 100000,
    '\$archiver': 'NSKeyedArchiver',
    '\$top': {'root': plistlib.UID(1)},
    '\$objects': [
        '\$null',
        {'NSSize': 18.0, 'NSfFlags': 16, 'NSName': plistlib.UID(2), '\$class': plistlib.UID(3)},
        'Delugia-Regular',
        {'\$classname': 'NSFont', '\$classes': ['NSFont', 'NSObject']}
    ]
}
font_data = plistlib.dumps(font_archive, fmt=plistlib.FMT_BINARY)

# Update Homebrew profile
ws = plist.get('Window Settings', {})
hb = ws.get('Homebrew', {})
hb['Font'] = font_data
hb['FontAntialias'] = False
hb['CursorBlink'] = True
hb['CursorType'] = 0  # Block cursor
ws['Homebrew'] = hb
plist['Window Settings'] = ws

# Write back
proc = subprocess.run(['defaults', 'import', 'com.apple.Terminal', '-'], input=plistlib.dumps(plist, fmt=plistlib.FMT_BINARY))
if proc.returncode == 0:
    print('OK')
else:
    print('FAIL')
" 2>&1)

        if [[ "$FONT_RESULT" == "OK" ]]; then
            success "Terminal.app Homebrew profile: Delugia-Regular 18pt, block cursor, blink on"
            mark_installed
        else
            fail "Terminal.app font configuration failed: $FONT_RESULT"
            mark_failed
        fi
    fi
else
    warn "python3 not found — skipping Terminal.app font configuration"
fi

# ── Section 8: Git Global Configuration ───────────────────────────────────
section "Git Global Configuration"

# User identity
CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
if [[ "$CURRENT_GIT_NAME" == "asudbring" ]]; then
    skip "Git user.name already set to asudbring"
    mark_skipped
else
    git config --global user.name "asudbring"
    success "Git user.name set to asudbring"
    mark_installed
fi

CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
if [[ "$CURRENT_GIT_EMAIL" == "allen@sudbring.com" ]]; then
    skip "Git user.email already set"
    mark_skipped
else
    git config --global user.email "allen@sudbring.com"
    success "Git user.email set to allen@sudbring.com"
    mark_installed
fi

# GCM Core credential helper
if git config --global credential.helper 2>/dev/null | grep -q "git-credential-manager"; then
    skip "Git credential helper already set to GCM Core"
    mark_skipped
else
    # GCM Core installs with Git on macOS via brew — check if it exists
    GCM_PATH="$(brew --prefix 2>/dev/null)/share/gcm-core/git-credential-manager"
    if [[ -f "$GCM_PATH" ]]; then
        git config --global credential.helper "$GCM_PATH"
        success "Git credential helper set to GCM Core"
        mark_installed
    else
        warn "GCM Core not found — credential helper not configured"
        mark_skipped
    fi
fi

# ADO HTTP path
CURRENT_ADO_HTTP=$(git config --global "credential.https://dev.azure.com.usehttppath" 2>/dev/null || echo "")
if [[ "$CURRENT_ADO_HTTP" == "true" ]]; then
    skip "Git ADO usehttppath already configured"
    mark_skipped
else
    git config --global "credential.https://dev.azure.com.usehttppath" true
    success "Git ADO usehttppath configured"
    mark_installed
fi

# git-delta as pager
CURRENT_PAGER=$(git config --global core.pager 2>/dev/null || echo "")
if [[ "$CURRENT_PAGER" == "delta" ]]; then
    skip "git-delta already configured as pager"
    mark_skipped
else
    if command -v delta &>/dev/null; then
        git config --global core.pager delta
        git config --global delta.navigate true
        git config --global delta.line-numbers true
        success "git-delta configured as global pager with navigate and line-numbers"
        mark_installed
    else
        warn "delta not found in PATH — skipping git-delta pager config"
        mark_skipped
    fi
fi

# ── Section 9: Post-Install Configuration ─────────────────────────────────
section "Post-Install Configuration"

# GitHub CLI authentication (required for extensions like gh-copilot)
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
        skip "GitHub CLI already authenticated"
        mark_skipped
    else
        info "GitHub CLI needs authentication — launching login flow..."
        gh auth login
        if gh auth status &>/dev/null; then
            success "GitHub CLI authenticated"
            mark_installed
        else
            warn "GitHub CLI authentication skipped or failed — gh extensions may not install"
            mark_failed
        fi
    fi
fi

# GitHub Copilot CLI — built-in on newer gh versions, extension on older ones
if gh copilot --version &>/dev/null; then
    skip "GitHub Copilot CLI already available (built-in or extension)"
    mark_skipped
elif gh extension list 2>/dev/null | grep -q "gh-copilot"; then
    skip "GitHub Copilot CLI extension already installed"
    mark_skipped
else
    if command -v gh &>/dev/null; then
        info "Installing GitHub Copilot CLI extension..."
        if gh extension install github/gh-copilot 2>&1 | grep -q "built-in"; then
            success "GitHub Copilot CLI is built-in (no extension needed)"
            mark_skipped
        elif gh extension install github/gh-copilot 2>/dev/null; then
            success "GitHub Copilot CLI extension installed"
            mark_installed
        else
            warn "GitHub Copilot CLI extension install failed — may already be built-in"
            mark_skipped
        fi
    else
        warn "GitHub CLI not found — skipping Copilot extension"
        mark_skipped
    fi
fi

# Bicep Tools
if az bicep version &>/dev/null; then
    info "Bicep tools found — upgrading..."
    if az bicep upgrade 2>/dev/null; then
        success "Bicep tools upgraded"
        mark_updated
    else
        skip "Bicep tools already at latest version"
        mark_skipped
    fi
else
    if command -v az &>/dev/null; then
        info "Installing Bicep tools..."
        if az bicep install 2>/dev/null; then
            success "Bicep tools installed"
            mark_installed
        else
            fail "Bicep tools installation failed"
            mark_failed
        fi
    else
        warn "Azure CLI not found — skipping Bicep install"
        mark_skipped
    fi
fi

# NPM global: context-mode
if npm list -g context-mode &>/dev/null; then
    info "context-mode found — updating..."
    if npm update -g context-mode 2>/dev/null; then
        success "context-mode updated"
        mark_updated
    else
        skip "context-mode already at latest version"
        mark_skipped
    fi
else
    if command -v npm &>/dev/null; then
        info "Installing context-mode globally..."
        if npm install -g context-mode; then
            success "context-mode installed globally"
            mark_installed
        else
            fail "context-mode installation failed"
            mark_failed
        fi
    else
        warn "npm not found — skipping context-mode install"
        mark_skipped
    fi
fi

# NPM global: GitHub Copilot CLI agent
if command -v copilot &>/dev/null || npm list -g @github/copilot &>/dev/null; then
    info "GitHub Copilot CLI agent found — updating..."
    if npm update -g @github/copilot 2>/dev/null; then
        success "GitHub Copilot CLI agent updated"
        mark_updated
    else
        skip "GitHub Copilot CLI agent already at latest version"
        mark_skipped
    fi
else
    if command -v npm &>/dev/null; then
        info "Installing GitHub Copilot CLI agent globally..."
        if npm install -g @github/copilot; then
            success "GitHub Copilot CLI agent installed globally"
            mark_installed
        else
            fail "GitHub Copilot CLI agent installation failed"
            mark_failed
        fi
    else
        warn "npm not found — skipping @github/copilot install"
        mark_skipped
    fi
fi

# OpenCode — AI coding agent for the terminal
if command -v opencode &>/dev/null; then
    skip "OpenCode already installed"
    mark_skipped
else
    if brew list --formula opencode &>/dev/null; then
        skip "OpenCode already installed (via brew)"
        mark_skipped
    else
        info "Installing OpenCode..."
        if brew install opencode --quiet; then
            success "OpenCode installed"
            mark_installed
        else
            fail "OpenCode installation failed"
            mark_failed
        fi
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
section "Installation Summary"

echo -e "${GREEN}Installed:${NC}  $INSTALLED"
echo -e "${CYAN}Updated:${NC}    $UPDATED"
echo -e "${YELLOW}Skipped:${NC}    $SKIPPED"
echo -e "${RED}Failed:${NC}     $FAILED"
echo ""

if [[ $FAILED -gt 0 ]]; then
    warn "Some installations failed. Review the output above for details."
fi

info "Restart your terminal or run 'source ~/.zshrc' to apply shell changes."
echo ""
