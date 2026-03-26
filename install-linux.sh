#!/usr/bin/env bash
# ============================================================================
# install-linux.sh — Linux Workstation Setup Script (Ubuntu / Arch)
# ============================================================================
# Idempotent install script for provisioning a new Linux workstation with all
# development tools, CLI utilities, GUI apps, shell customizations, and
# terminal preferences used by Allen Sudbring for Azure documentation work.
#
# Supports:
#   - Ubuntu (22.04+) — uses apt + Microsoft/HashiCorp/GitHub repos
#   - Arch Linux — uses pacman + yay (AUR helper)
#
# Usage:
#   chmod +x install-linux.sh
#   ./install-linux.sh
#
# Safe to re-run — checks for each component before installing.
# On re-run, upgrades existing packages and updates configurations.
# ============================================================================

set -euo pipefail

# ── Color helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

MARKER="# Managed by install-linux.sh"

# ── Distro Detection ──────────────────────────────────────────────────────
section "Distro Detection"

DISTRO=""
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "$ID" in
        ubuntu|debian|linuxmint|pop)
            DISTRO="ubuntu"
            info "Detected: $PRETTY_NAME (apt-based)"
            ;;
        arch|endeavouros|manjaro)
            DISTRO="arch"
            info "Detected: $PRETTY_NAME (pacman-based)"
            ;;
        *)
            fail "Unsupported distribution: $ID ($PRETTY_NAME)"
            fail "This script supports Ubuntu/Debian and Arch-based distros."
            exit 1
            ;;
    esac
else
    fail "Cannot detect distribution — /etc/os-release not found"
    exit 1
fi

# ── Helper functions ──────────────────────────────────────────────────────

# Install packages via the appropriate package manager
pkg_install() {
    local pkg="$1"
    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo apt-get install -y -qq "$pkg" 2>/dev/null
    else
        sudo pacman -S --noconfirm --needed "$pkg" 2>/dev/null
    fi
}

# Install multiple packages at once
pkg_install_multi() {
    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo apt-get install -y -qq "$@" 2>/dev/null
    else
        sudo pacman -S --noconfirm --needed "$@" 2>/dev/null
    fi
}

# Install from AUR via yay (Arch only)
aur_install() {
    local pkg="$1"
    if [[ "$DISTRO" == "arch" ]]; then
        yay -S --noconfirm --needed "$pkg" 2>/dev/null
    fi
}

# Check if a package is installed
pkg_installed() {
    local pkg="$1"
    if [[ "$DISTRO" == "ubuntu" ]]; then
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
    else
        pacman -Qi "$pkg" &>/dev/null
    fi
}

# Check if an AUR package is installed (Arch only)
aur_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Refresh PATH
refresh_path() {
    export PATH="$HOME/.local/bin:$HOME/.dotnet/tools:/usr/local/bin:$PATH"
    hash -r
}

# ── Section 1: System Update & Build Tools ────────────────────────────────
section "System Update & Build Tools"

if [[ "$DISTRO" == "ubuntu" ]]; then
    info "Updating apt package lists..."
    sudo apt-get update -qq
    info "Upgrading installed packages..."
    sudo apt-get upgrade -y -qq
    mark_updated

    info "Installing build essentials..."
    pkg_install_multi build-essential curl wget unzip software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    success "Build essentials installed"
    mark_installed
else
    info "Updating pacman package database..."
    sudo pacman -Syu --noconfirm
    mark_updated

    info "Installing base-devel..."
    pkg_install_multi base-devel curl wget unzip
    success "Base development tools installed"
    mark_installed
fi

# ── Section 2: AUR Helper (Arch only) ────────────────────────────────────
if [[ "$DISTRO" == "arch" ]]; then
    section "AUR Helper (yay)"

    if command -v yay &>/dev/null; then
        skip "yay already installed"
        mark_skipped
    else
        info "Installing yay AUR helper..."
        TEMP_YAY=$(mktemp -d)
        git clone https://aur.archlinux.org/yay-bin.git "$TEMP_YAY/yay-bin"
        (cd "$TEMP_YAY/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$TEMP_YAY"
        if command -v yay &>/dev/null; then
            success "yay installed"
            mark_installed
        else
            fail "yay installation failed"
            mark_failed
        fi
    fi
fi

# ── Section 3: Ubuntu Repository Setup ────────────────────────────────────
if [[ "$DISTRO" == "ubuntu" ]]; then
    section "APT Repository Setup"

    # Microsoft GPG key + repos (Edge, VS Code, Azure CLI, PowerShell)
    MSFT_KEY="/usr/share/keyrings/microsoft-archive-keyring.gpg"
    if [[ ! -f "$MSFT_KEY" ]]; then
        info "Adding Microsoft GPG key..."
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
            sudo gpg --dearmor -o "$MSFT_KEY"
        success "Microsoft GPG key added"
    else
        skip "Microsoft GPG key already present"
    fi

    # VS Code repo
    VSCODE_REPO="/etc/apt/sources.list.d/vscode.list"
    if [[ ! -f "$VSCODE_REPO" ]]; then
        info "Adding VS Code repository..."
        echo "deb [arch=amd64 signed-by=$MSFT_KEY] https://packages.microsoft.com/repos/code stable main" | \
            sudo tee "$VSCODE_REPO" > /dev/null
        success "VS Code repo added"
        mark_installed
    else
        skip "VS Code repo already configured"
        mark_skipped
    fi

    # Edge repo
    EDGE_REPO="/etc/apt/sources.list.d/microsoft-edge.list"
    if [[ ! -f "$EDGE_REPO" ]]; then
        info "Adding Microsoft Edge repository..."
        echo "deb [arch=amd64 signed-by=$MSFT_KEY] https://packages.microsoft.com/repos/edge stable main" | \
            sudo tee "$EDGE_REPO" > /dev/null
        success "Edge repo added"
        mark_installed
    else
        skip "Edge repo already configured"
        mark_skipped
    fi

    # Azure CLI repo
    AZCLI_REPO="/etc/apt/sources.list.d/azure-cli.list"
    if [[ ! -f "$AZCLI_REPO" ]]; then
        info "Adding Azure CLI repository..."
        echo "deb [arch=amd64 signed-by=$MSFT_KEY] https://packages.microsoft.com/repos/azure-cli $(lsb_release -cs) main" | \
            sudo tee "$AZCLI_REPO" > /dev/null
        success "Azure CLI repo added"
        mark_installed
    else
        skip "Azure CLI repo already configured"
        mark_skipped
    fi

    # PowerShell repo
    PWSH_REPO="/etc/apt/sources.list.d/microsoft-prod.list"
    if [[ ! -f "$PWSH_REPO" ]]; then
        info "Adding PowerShell (Microsoft prod) repository..."
        curl -fsSL "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" -o /tmp/packages-microsoft-prod.deb
        sudo dpkg -i /tmp/packages-microsoft-prod.deb
        rm -f /tmp/packages-microsoft-prod.deb
        success "PowerShell repo added"
        mark_installed
    else
        skip "PowerShell repo already configured"
        mark_skipped
    fi

    # HashiCorp repo (Terraform)
    HASHI_REPO="/etc/apt/sources.list.d/hashicorp.list"
    if [[ ! -f "$HASHI_REPO" ]]; then
        info "Adding HashiCorp repository..."
        HASHI_KEY="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o "$HASHI_KEY"
        echo "deb [arch=amd64 signed-by=$HASHI_KEY] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
            sudo tee "$HASHI_REPO" > /dev/null
        success "HashiCorp repo added"
        mark_installed
    else
        skip "HashiCorp repo already configured"
        mark_skipped
    fi

    # GitHub CLI repo
    GH_REPO="/etc/apt/sources.list.d/github-cli.list"
    if [[ ! -f "$GH_REPO" ]]; then
        info "Adding GitHub CLI repository..."
        GH_KEY="/usr/share/keyrings/githubcli-archive-keyring.gpg"
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee "$GH_KEY" > /dev/null
        echo "deb [arch=amd64 signed-by=$GH_KEY] https://cli.github.com/packages stable main" | \
            sudo tee "$GH_REPO" > /dev/null
        success "GitHub CLI repo added"
        mark_installed
    else
        skip "GitHub CLI repo already configured"
        mark_skipped
    fi

    # Refresh after adding repos
    info "Refreshing package lists..."
    sudo apt-get update -qq
fi

# ── Section 4: Core Development Tools ─────────────────────────────────────
section "Core Development Tools"

# Git
if command -v git &>/dev/null; then
    skip "Git already installed ($(git --version | cut -d' ' -f3))"
    mark_skipped
else
    info "Installing Git..."
    if pkg_install git; then
        success "Git installed"
        mark_installed
    else
        fail "Git installation failed"
        mark_failed
    fi
fi

# Node.js + npm
if command -v node &>/dev/null; then
    skip "Node.js already installed ($(node --version))"
    mark_skipped
else
    info "Installing Node.js..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install_multi nodejs npm
    else
        pkg_install_multi nodejs npm
    fi
    if command -v node &>/dev/null; then
        success "Node.js installed ($(node --version))"
        mark_installed
    else
        fail "Node.js installation failed"
        mark_failed
    fi
fi

# Python 3
if command -v python3 &>/dev/null; then
    skip "Python already installed ($(python3 --version 2>&1))"
    mark_skipped
else
    info "Installing Python 3..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install_multi python3 python3-pip python3-venv
    else
        pkg_install_multi python python-pip
    fi
    if command -v python3 &>/dev/null; then
        success "Python 3 installed"
        mark_installed
    else
        fail "Python 3 installation failed"
        mark_failed
    fi
fi

# Terraform
if command -v terraform &>/dev/null; then
    skip "Terraform already installed ($(terraform version -json 2>/dev/null | head -1 | grep -oP '"terraform_version":"\K[^"]+' || terraform version | head -1))"
    mark_skipped
else
    info "Installing Terraform..."
    if pkg_install terraform; then
        success "Terraform installed"
        mark_installed
    else
        fail "Terraform installation failed"
        mark_failed
    fi
fi

# Docker
if command -v docker &>/dev/null; then
    skip "Docker already installed ($(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ','))"
    mark_skipped
else
    info "Installing Docker..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install_multi docker.io docker-compose-plugin
    else
        pkg_install_multi docker docker-compose
    fi
    if command -v docker &>/dev/null; then
        # Add user to docker group
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        sudo systemctl enable docker 2>/dev/null || true
        sudo systemctl start docker 2>/dev/null || true
        success "Docker installed (log out/in to use without sudo)"
        mark_installed
    else
        fail "Docker installation failed"
        mark_failed
    fi
fi

# Azure CLI
if command -v az &>/dev/null; then
    skip "Azure CLI already installed ($(az version --query '"azure-cli"' -o tsv 2>/dev/null))"
    mark_skipped
else
    info "Installing Azure CLI..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install azure-cli
    else
        aur_install azure-cli
    fi
    if command -v az &>/dev/null; then
        success "Azure CLI installed"
        mark_installed
    else
        fail "Azure CLI installation failed"
        mark_failed
    fi
fi

# PowerShell
if command -v pwsh &>/dev/null; then
    skip "PowerShell already installed ($(pwsh --version))"
    mark_skipped
else
    info "Installing PowerShell..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install powershell
    else
        aur_install powershell-bin
    fi
    if command -v pwsh &>/dev/null; then
        success "PowerShell installed"
        mark_installed
    else
        fail "PowerShell installation failed"
        mark_failed
    fi
fi

# GitHub CLI
if command -v gh &>/dev/null; then
    skip "GitHub CLI already installed ($(gh --version | head -1 | cut -d' ' -f3))"
    mark_skipped
else
    info "Installing GitHub CLI..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install gh
    else
        pkg_install github-cli
    fi
    if command -v gh &>/dev/null; then
        success "GitHub CLI installed"
        mark_installed
    else
        fail "GitHub CLI installation failed"
        mark_failed
    fi
fi

# ── Section 5: CLI Utilities ──────────────────────────────────────────────
section "CLI Utilities"

# Simple command-to-package mapping
declare -A CLI_TOOLS_CMD
declare -A CLI_TOOLS_UBUNTU
declare -A CLI_TOOLS_ARCH

CLI_TOOLS_CMD=(
    [ripgrep]="rg"
    [fzf]="fzf"
    [git-delta]="delta"
    [age]="age"
)
CLI_TOOLS_UBUNTU=(
    [ripgrep]="ripgrep"
    [fzf]="fzf"
    [git-delta]="git-delta"
    [age]="age"
)
CLI_TOOLS_ARCH=(
    [ripgrep]="ripgrep"
    [fzf]="fzf"
    [git-delta]="git-delta"
    [age]="age"
)

for tool in "${!CLI_TOOLS_CMD[@]}"; do
    cmd="${CLI_TOOLS_CMD[$tool]}"
    if command -v "$cmd" &>/dev/null; then
        skip "$tool already installed"
        mark_skipped
    else
        info "Installing $tool..."
        if [[ "$DISTRO" == "ubuntu" ]]; then
            pkg="${CLI_TOOLS_UBUNTU[$tool]}"
        else
            pkg="${CLI_TOOLS_ARCH[$tool]}"
        fi
        if pkg_install "$pkg"; then
            success "$tool installed"
            mark_installed
        else
            fail "$tool installation failed"
            mark_failed
        fi
    fi
done

# fd (different package name on Ubuntu)
if command -v fd &>/dev/null || command -v fdfind &>/dev/null; then
    skip "fd already installed"
    mark_skipped
else
    info "Installing fd..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        if pkg_install fd-find; then
            # Ubuntu names it fdfind — create symlink
            if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
                sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
            fi
            success "fd installed (as fd-find, symlinked to fd)"
            mark_installed
        else
            fail "fd installation failed"
            mark_failed
        fi
    else
        if pkg_install fd; then
            success "fd installed"
            mark_installed
        else
            fail "fd installation failed"
            mark_failed
        fi
    fi
fi

# DuckDB
if command -v duckdb &>/dev/null; then
    skip "DuckDB already installed"
    mark_skipped
else
    info "Installing DuckDB..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        # DuckDB not in Ubuntu repos — install from GitHub release
        DUCKDB_URL=$(curl -fsSL "https://api.github.com/repos/duckdb/duckdb/releases/latest" | \
            grep -oP '"browser_download_url": "\K[^"]*linux-amd64.zip' | head -1) || true
        if [[ -n "$DUCKDB_URL" ]]; then
            curl -fsSL "$DUCKDB_URL" -o /tmp/duckdb.zip
            unzip -o /tmp/duckdb.zip -d /tmp/duckdb
            sudo mv /tmp/duckdb/duckdb /usr/local/bin/duckdb
            sudo chmod +x /usr/local/bin/duckdb
            rm -rf /tmp/duckdb.zip /tmp/duckdb
            success "DuckDB installed"
            mark_installed
        else
            fail "DuckDB download URL not found"
            mark_failed
        fi
    else
        if pkg_install duckdb; then
            success "DuckDB installed"
            mark_installed
        else
            fail "DuckDB installation failed"
            mark_failed
        fi
    fi
fi

# xh
if command -v xh &>/dev/null; then
    skip "xh already installed"
    mark_skipped
else
    info "Installing xh..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        XH_URL=$(curl -fsSL "https://api.github.com/repos/ducaale/xh/releases/latest" | \
            grep -oP '"browser_download_url": "\K[^"]*x86_64-unknown-linux-musl.tar.gz' | head -1) || true
        if [[ -n "$XH_URL" ]]; then
            curl -fsSL "$XH_URL" -o /tmp/xh.tar.gz
            tar -xzf /tmp/xh.tar.gz -C /tmp
            sudo mv /tmp/xh-*/xh /usr/local/bin/xh
            sudo chmod +x /usr/local/bin/xh
            rm -rf /tmp/xh.tar.gz /tmp/xh-*
            success "xh installed"
            mark_installed
        else
            fail "xh download URL not found"
            mark_failed
        fi
    else
        if pkg_install xh; then
            success "xh installed"
            mark_installed
        else
            fail "xh installation failed"
            mark_failed
        fi
    fi
fi

# watchexec
if command -v watchexec &>/dev/null; then
    skip "watchexec already installed"
    mark_skipped
else
    info "Installing watchexec..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        WATCHEXEC_URL=$(curl -fsSL "https://api.github.com/repos/watchexec/watchexec/releases/latest" | \
            grep -oP '"browser_download_url": "\K[^"]*x86_64-unknown-linux-musl.tar.xz' | head -1) || true
        if [[ -n "$WATCHEXEC_URL" ]]; then
            curl -fsSL "$WATCHEXEC_URL" -o /tmp/watchexec.tar.xz
            tar -xJf /tmp/watchexec.tar.xz -C /tmp
            sudo mv /tmp/watchexec-*/watchexec /usr/local/bin/watchexec
            sudo chmod +x /usr/local/bin/watchexec
            rm -rf /tmp/watchexec.tar.xz /tmp/watchexec-*
            success "watchexec installed"
            mark_installed
        else
            fail "watchexec download URL not found"
            mark_failed
        fi
    else
        if pkg_install watchexec; then
            success "watchexec installed"
            mark_installed
        else
            fail "watchexec installation failed"
            mark_failed
        fi
    fi
fi

# just
if command -v just &>/dev/null; then
    skip "just already installed"
    mark_skipped
else
    info "Installing just..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        JUST_URL=$(curl -fsSL "https://api.github.com/repos/casey/just/releases/latest" | \
            grep -oP '"browser_download_url": "\K[^"]*x86_64-unknown-linux-musl.tar.gz' | head -1) || true
        if [[ -n "$JUST_URL" ]]; then
            curl -fsSL "$JUST_URL" -o /tmp/just.tar.gz
            tar -xzf /tmp/just.tar.gz -C /tmp just
            sudo mv /tmp/just /usr/local/bin/just
            sudo chmod +x /usr/local/bin/just
            rm -f /tmp/just.tar.gz
            success "just installed"
            mark_installed
        else
            fail "just download URL not found"
            mark_failed
        fi
    else
        if pkg_install just; then
            success "just installed"
            mark_installed
        else
            fail "just installation failed"
            mark_failed
        fi
    fi
fi

# semgrep (pip on both distros)
if command -v semgrep &>/dev/null; then
    skip "semgrep already installed"
    mark_skipped
    info "Updating semgrep..."
    pip install --upgrade --quiet semgrep 2>/dev/null || true
    mark_updated
else
    info "Installing semgrep..."
    if pip install --quiet semgrep 2>/dev/null || pip3 install --quiet semgrep 2>/dev/null; then
        refresh_path
        success "semgrep installed"
        mark_installed
    else
        fail "semgrep installation failed"
        mark_failed
    fi
fi

# Bun (official install script)
if command -v bun &>/dev/null; then
    skip "Bun already installed ($(bun --version 2>/dev/null))"
    mark_skipped
    info "Updating Bun..."
    bun upgrade 2>/dev/null || true
    mark_updated
else
    info "Installing Bun..."
    if curl -fsSL https://bun.sh/install | bash 2>/dev/null; then
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        if command -v bun &>/dev/null; then
            success "Bun installed ($(bun --version))"
            mark_installed
        else
            fail "Bun installed but not found in PATH"
            mark_failed
        fi
    else
        fail "Bun installation failed"
        mark_failed
    fi
fi

# oh-my-posh
if command -v oh-my-posh &>/dev/null; then
    skip "oh-my-posh already installed"
    mark_skipped
else
    info "Installing oh-my-posh..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        # Official install script — installs to ~/.local/bin
        if curl -fsSL https://ohmyposh.dev/install.sh | bash -s 2>/dev/null; then
            refresh_path
            success "oh-my-posh installed"
            mark_installed
        else
            fail "oh-my-posh installation failed"
            mark_failed
        fi
    else
        if pkg_install oh-my-posh; then
            success "oh-my-posh installed"
            mark_installed
        else
            fail "oh-my-posh installation failed"
            mark_failed
        fi
    fi
fi

# ── Section 6: GUI Applications ──────────────────────────────────────────
section "GUI Applications"

# Microsoft Edge
if command -v microsoft-edge-stable &>/dev/null || command -v microsoft-edge &>/dev/null; then
    skip "Microsoft Edge already installed"
    mark_skipped
else
    info "Installing Microsoft Edge..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install microsoft-edge-stable
    else
        aur_install microsoft-edge-stable-bin
    fi
    if command -v microsoft-edge-stable &>/dev/null || command -v microsoft-edge &>/dev/null; then
        success "Microsoft Edge installed"
        mark_installed
    else
        fail "Microsoft Edge installation failed"
        mark_failed
    fi
fi

# Visual Studio Code
if command -v code &>/dev/null; then
    skip "VS Code already installed"
    mark_skipped
else
    info "Installing Visual Studio Code..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install code
    else
        aur_install visual-studio-code-bin
    fi
    if command -v code &>/dev/null; then
        success "VS Code installed"
        mark_installed
    else
        fail "VS Code installation failed"
        mark_failed
    fi
fi

# Terminator
if command -v terminator &>/dev/null; then
    skip "Terminator already installed"
    mark_skipped
else
    info "Installing Terminator..."
    if pkg_install terminator; then
        success "Terminator installed"
        mark_installed
    else
        fail "Terminator installation failed"
        mark_failed
    fi
fi

# Flameshot
if command -v flameshot &>/dev/null; then
    skip "Flameshot already installed"
    mark_skipped
else
    info "Installing Flameshot..."
    if pkg_install flameshot; then
        success "Flameshot installed"
        mark_installed
    else
        fail "Flameshot installation failed"
        mark_failed
    fi
fi

# Remmina + FreeRDP
if command -v remmina &>/dev/null; then
    skip "Remmina already installed"
    mark_skipped
else
    info "Installing Remmina + FreeRDP..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install_multi remmina remmina-plugin-rdp
    else
        pkg_install_multi remmina freerdp
    fi
    if command -v remmina &>/dev/null; then
        success "Remmina installed"
        mark_installed
    else
        fail "Remmina installation failed"
        mark_failed
    fi
fi

# KVM/QEMU + virt-manager
if command -v virt-manager &>/dev/null; then
    skip "virt-manager already installed"
    mark_skipped
else
    info "Installing KVM/QEMU + virt-manager..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        pkg_install_multi qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
    else
        pkg_install_multi qemu-full libvirt virt-manager dnsmasq
    fi
    if command -v virt-manager &>/dev/null; then
        sudo usermod -aG libvirt "$USER" 2>/dev/null || true
        sudo systemctl enable libvirtd 2>/dev/null || true
        sudo systemctl start libvirtd 2>/dev/null || true
        success "KVM/QEMU + virt-manager installed (log out/in for group membership)"
        mark_installed
    else
        fail "virt-manager installation failed"
        mark_failed
    fi
fi

# ── Section 7: Delugia Nerd Font ──────────────────────────────────────────
section "Delugia Nerd Font"

FONT_DIR="$HOME/.local/share/fonts"
if fc-list 2>/dev/null | grep -qi "Delugia"; then
    skip "Delugia Nerd Font already installed"
    mark_skipped
else
    info "Downloading Delugia Nerd Font from GitHub..."
    FONT_URL="https://github.com/adam7/delugia-code/releases/latest/download/Delugia.zip"
    TEMP_FONT=$(mktemp -d)
    if curl -fsSL "$FONT_URL" -o "$TEMP_FONT/Delugia.zip"; then
        mkdir -p "$FONT_DIR"
        unzip -o "$TEMP_FONT/Delugia.zip" -d "$TEMP_FONT/delugia" >/dev/null
        find "$TEMP_FONT/delugia" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
        fc-cache -f 2>/dev/null
        rm -rf "$TEMP_FONT"
        if fc-list | grep -qi "Delugia"; then
            success "Delugia Nerd Font installed"
            mark_installed
        else
            warn "Delugia font files copied but fc-cache may need a restart"
            mark_installed
        fi
    else
        fail "Delugia font download failed"
        rm -rf "$TEMP_FONT"
        mark_failed
    fi
fi

# ── Section 8: Shell Customization (oh-my-bash) ──────────────────────────
section "Shell Customization (oh-my-bash + Bash)"

# oh-my-bash
if [[ -d "$HOME/.oh-my-bash" ]]; then
    skip "oh-my-bash already installed"
    mark_skipped
    info "Updating oh-my-bash..."
    (cd "$HOME/.oh-my-bash" && git pull --quiet 2>/dev/null) || true
    mark_updated
else
    info "Installing oh-my-bash..."
    # Use unattended install (OSH_UNATTENDED prevents shell switch prompt)
    OSH_UNATTENDED=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    if [[ -d "$HOME/.oh-my-bash" ]]; then
        success "oh-my-bash installed"
        mark_installed
    else
        fail "oh-my-bash installation failed"
        mark_failed
    fi
fi

# Configure .bashrc with agnoster theme and custom settings
BASHRC="$HOME/.bashrc"
BASH_MARKER="$MARKER — bashrc"

if [[ -f "$BASHRC" ]] && grep -qF "$BASH_MARKER" "$BASHRC" 2>/dev/null; then
    skip "Bash customizations already applied"
    mark_skipped
else
    info "Configuring .bashrc (agnoster theme, PATH, aliases)..."

    # Set oh-my-bash theme to agnoster if oh-my-bash is installed
    if [[ -f "$BASHRC" ]] && grep -q "OSH_THEME=" "$BASHRC"; then
        sed -i 's/^OSH_THEME=.*/OSH_THEME="agnoster"/' "$BASHRC"
    fi

    cat >> "$BASHRC" << 'BASHEOF'

# Managed by install-linux.sh — bashrc
# PATH additions
export PATH="$HOME/.local/bin:$HOME/.dotnet/tools:$HOME/.bun/bin:$PATH"

# Aliases
alias claude-local='ANTHROPIC_BASE_URL=http://localhost:4001 ANTHROPIC_API_KEY=sk-local-proxy claude'
BASHEOF

    success "Bash customizations applied"
    mark_installed
fi

# ── Section 9: PowerShell Profile & Modules ──────────────────────────────
section "PowerShell Profile & Modules"

PWSH_PROFILE_DIR="$HOME/.config/powershell"
PWSH_PROFILE="$PWSH_PROFILE_DIR/profile.ps1"
PWSH_MARKER="$MARKER — pwsh"

if command -v pwsh &>/dev/null; then
    # Create profile
    if [[ -f "$PWSH_PROFILE" ]] && grep -qF "$PWSH_MARKER" "$PWSH_PROFILE" 2>/dev/null; then
        skip "PowerShell profile already configured"
        mark_skipped
    else
        info "Configuring PowerShell profile..."
        mkdir -p "$PWSH_PROFILE_DIR"
        cat >> "$PWSH_PROFILE" << PWSHEOF

$PWSH_MARKER
# oh-my-posh theme
oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/agnoster.omp.json" | Invoke-Expression
PWSHEOF
        success "PowerShell profile configured"
        mark_installed
    fi

    # PowerShell modules
    for module in Az PSReadLine posh-git; do
        if pwsh -NoProfile -Command "Get-Module -ListAvailable -Name $module" 2>/dev/null | grep -q "$module"; then
            skip "PowerShell module $module already installed"
            mark_skipped
            info "Updating $module..."
            pwsh -NoProfile -Command "Update-Module -Name $module -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
            mark_updated
        else
            info "Installing PowerShell module: $module..."
            if pwsh -NoProfile -Command "Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber -AcceptLicense" 2>/dev/null; then
                success "PowerShell module $module installed"
                mark_installed
            else
                fail "PowerShell module $module installation failed"
                mark_failed
            fi
        fi
    done
else
    warn "PowerShell not installed — skipping profile and modules"
    mark_skipped
fi

# ── Section 10: NPM Global Packages ──────────────────────────────────────
section "NPM Global Packages"

if command -v npm &>/dev/null; then
    # context-mode
    if npm list -g context-mode &>/dev/null; then
        skip "context-mode already installed"
        mark_skipped
        info "Updating context-mode..."
        npm update -g context-mode 2>/dev/null || true
        mark_updated
    else
        info "Installing context-mode..."
        if npm install -g context-mode 2>/dev/null; then
            success "context-mode installed"
            mark_installed
        else
            fail "context-mode installation failed"
            mark_failed
        fi
    fi

    # @github/copilot
    if command -v copilot &>/dev/null || npm list -g @github/copilot &>/dev/null; then
        skip "GitHub Copilot CLI agent already installed"
        mark_skipped
        info "Updating @github/copilot..."
        npm update -g @github/copilot 2>/dev/null || true
        mark_updated
    else
        info "Installing GitHub Copilot CLI agent..."
        if npm install -g @github/copilot 2>/dev/null; then
            success "GitHub Copilot CLI agent installed"
            mark_installed
        else
            fail "GitHub Copilot CLI agent installation failed"
            mark_failed
        fi
    fi

    # opencode-ai
    if command -v opencode &>/dev/null || npm list -g opencode-ai &>/dev/null; then
        skip "OpenCode already installed"
        mark_skipped
        info "Updating opencode-ai..."
        npm update -g opencode-ai 2>/dev/null || true
        mark_updated
    else
        info "Installing OpenCode..."
        if npm install -g opencode-ai 2>/dev/null; then
            success "OpenCode installed"
            mark_installed
        else
            fail "OpenCode installation failed"
            mark_failed
        fi
    fi
else
    warn "npm not found — skipping NPM global packages"
    mark_skipped
fi

# ── Section 11: Terminator Configuration ─────────────────────────────────
section "Terminator Configuration"

TERMINATOR_CONFIG_DIR="$HOME/.config/terminator"
TERMINATOR_CONFIG="$TERMINATOR_CONFIG_DIR/config"

if [[ -f "$TERMINATOR_CONFIG" ]] && grep -qF "$MARKER" "$TERMINATOR_CONFIG" 2>/dev/null; then
    skip "Terminator config already managed by this script"
    mark_skipped
else
    info "Writing Terminator configuration..."
    mkdir -p "$TERMINATOR_CONFIG_DIR"

    # Back up existing config if present
    if [[ -f "$TERMINATOR_CONFIG" ]]; then
        cp "$TERMINATOR_CONFIG" "$TERMINATOR_CONFIG.bak.$(date +%s)"
        info "Backed up existing config to $TERMINATOR_CONFIG.bak.*"
    fi

    cat > "$TERMINATOR_CONFIG" << 'TERMEOF'
# Managed by install-linux.sh
[global_config]
  title_transmit_bg_color = "#1a1a2e"
  title_inactive_bg_color = "#16213e"
  enabled_plugins = LaunchpadBugURLHandler, LaunchpadCodeURLHandler, APTURLHandler
  suppress_multiple_term_dialog = True

[keybindings]

[profiles]
  [[default]]
    background_color = "#0a0a1a"
    background_darkness = 0.92
    background_type = transparent
    cursor_blink = True
    cursor_shape = block
    cursor_color = "#00d4ff"
    foreground_color = "#e0e0e0"
    show_titlebar = False
    scrollbar_position = hidden
    scrollback_lines = 10000
    palette = "#1a1a2e:#ff5555:#50fa7b:#f1fa8c:#6272a4:#ff79c6:#8be9fd:#bbbbbb:#44475a:#ff6e6e:#69ff94:#ffffa5:#d6acff:#ff92df:#a4ffff:#ffffff"
    use_system_font = False
    font = Delugia 14
    copy_on_selection = True

[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
      size = 1400, 800
    [[[child1]]]
      type = Terminal
      parent = window0

[plugins]
TERMEOF

    success "Terminator configuration written"
    mark_installed
fi

# ── Section 12: Git Global Configuration ─────────────────────────────────
section "Git Configuration"

if git config --global user.name &>/dev/null && \
   [[ "$(git config --global user.name)" == "asudbring" ]]; then
    skip "Git user already configured"
    mark_skipped
else
    info "Configuring Git identity..."
    git config --global user.name "asudbring"
    git config --global user.email "allen@sudbring.com"
    success "Git identity configured"
    mark_installed
fi

# Git Credential Manager
if command -v git-credential-manager &>/dev/null; then
    skip "Git Credential Manager already installed"
    mark_skipped
else
    info "Installing Git Credential Manager..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        # Download latest .deb from GitHub releases
        GCM_URL=$(curl -fsSL "https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest" | \
            grep -oP '"browser_download_url": "\K[^"]*gcm-linux_amd64\.[^"]*\.deb' | head -1) || true
        if [[ -n "$GCM_URL" ]]; then
            curl -fsSL "$GCM_URL" -o /tmp/gcm.deb
            sudo dpkg -i /tmp/gcm.deb 2>/dev/null
            rm -f /tmp/gcm.deb
            success "Git Credential Manager installed"
            mark_installed
        else
            warn "GCM download URL not found — using gh auth as fallback"
            mark_skipped
        fi
    else
        aur_install git-credential-manager-bin
        if command -v git-credential-manager &>/dev/null; then
            success "Git Credential Manager installed"
            mark_installed
        else
            warn "GCM not available — using gh auth as fallback"
            mark_skipped
        fi
    fi
fi

# Configure GCM if installed
if command -v git-credential-manager &>/dev/null; then
    git-credential-manager configure 2>/dev/null || true
    git config --global credential.credentialStore secretservice 2>/dev/null || \
        git config --global credential.credentialStore cache 2>/dev/null || true
    git config --global credential.https://dev.azure.com.useHttpPath true
fi

# git-delta as pager
if command -v delta &>/dev/null; then
    if [[ "$(git config --global core.pager 2>/dev/null)" == "delta" ]]; then
        skip "git-delta already configured as pager"
        mark_skipped
    else
        info "Configuring git-delta as default pager..."
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.line-numbers true
        git config --global delta.side-by-side false
        git config --global merge.conflictstyle diff3
        git config --global diff.colorMoved default
        success "git-delta configured as Git pager"
        mark_installed
    fi
fi

# ── Section 13: SSH Key Setup (sudbringlab servers) ──────────────────────
section "SSH Key Setup (sudbringlab servers)"

SSH_GIST_ID="639363ac7797dced788c7b2706986fc6"
SSH_KEY_PATH="$HOME/.ssh/sudbringlab"
SSH_CONFIG="$HOME/.ssh/config"
SSH_MARKER="$MARKER — sudbringlab"

if [[ "$SSH_GIST_ID" == "PASTE_GIST_ID_HERE" ]]; then
    warn "SSH gist ID not configured — run setup-ssh-keys.sh first"
    mark_skipped
elif [[ -f "$SSH_KEY_PATH" ]]; then
    skip "SSH key already exists at $SSH_KEY_PATH"
    mark_skipped
else
    # Prompt user (skip in non-interactive / scheduled runs)
    if [[ -t 0 ]]; then
        read -rp "Set up SSH keys for sudbringlab servers? (y/N): " setup_ssh
    else
        setup_ssh="n"
    fi

    if [[ "$setup_ssh" == "y" || "$setup_ssh" == "Y" ]]; then
        if ! command -v age &>/dev/null; then
            fail "age not found — should have been installed earlier"
            mark_failed
        elif ! command -v gh &>/dev/null; then
            fail "gh CLI not found — cannot download SSH key"
            mark_failed
        else
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"

            info "Downloading encrypted SSH key from GitHub Gist..."
            ENCRYPTED_B64=$(gh gist view "$SSH_GIST_ID" -f sudbringlab.age.b64 --raw 2>/dev/null) || true

            if [[ -z "$ENCRYPTED_B64" ]]; then
                fail "Failed to download SSH key from gist $SSH_GIST_ID"
                mark_failed
            else
                info "Decrypting SSH key (enter your passphrase)..."
                TEMP_AGE="/tmp/sudbringlab_$$.age"
                echo "$ENCRYPTED_B64" | base64 -d > "$TEMP_AGE"
                if age -d -o "$SSH_KEY_PATH" "$TEMP_AGE"; then
                    rm -f "$TEMP_AGE"
                else
                    rm -f "$TEMP_AGE"
                    rm -f "$SSH_KEY_PATH"
                    fail "age decryption failed — wrong passphrase?"
                    mark_failed
                fi

                if [[ -f "$SSH_KEY_PATH" ]]; then
                    chmod 600 "$SSH_KEY_PATH"
                    success "SSH private key written to $SSH_KEY_PATH"
                    mark_installed

                    # Download public key
                    gh gist view "$SSH_GIST_ID" -f sudbringlab.pub --raw > "${SSH_KEY_PATH}.pub" 2>/dev/null || true
                    if [[ -f "${SSH_KEY_PATH}.pub" ]]; then
                        chmod 644 "${SSH_KEY_PATH}.pub"
                        success "SSH public key written to ${SSH_KEY_PATH}.pub"
                    fi

                    # Configure ~/.ssh/config
                    if [[ -f "$SSH_CONFIG" ]] && grep -qF "$SSH_MARKER" "$SSH_CONFIG" 2>/dev/null; then
                        skip "SSH config entries already present"
                        mark_skipped
                    else
                        info "Adding sudbringlab hosts to $SSH_CONFIG..."
                        cat >> "$SSH_CONFIG" << SSHEOF

$SSH_MARKER
Host media-server.sudbringlab.com
    HostName media-server.sudbringlab.com
    User allenadmin
    IdentityFile ~/.ssh/sudbringlab

Host media.sudbringlab.com
    HostName media.sudbringlab.com
    User allenadmin
    IdentityFile ~/.ssh/sudbringlab
SSHEOF
                        chmod 600 "$SSH_CONFIG"
                        success "SSH config updated with sudbringlab hosts"
                        mark_installed
                    fi
                else
                    fail "Decryption failed — SSH key not written"
                    mark_failed
                fi
            fi
        fi
    else
        skip "SSH key setup skipped by user"
        mark_skipped
    fi
fi

# ── Section 14: Post-Install Configuration ───────────────────────────────
section "Post-Install Configuration"

# GitHub CLI authentication
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
            warn "GitHub CLI authentication skipped or failed"
            mark_failed
        fi
    fi
fi

# GitHub Copilot CLI
if gh copilot --version &>/dev/null 2>&1; then
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
    fi
fi

# Bicep Tools
if az bicep version &>/dev/null 2>&1; then
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
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────
section "Installation Summary"

echo -e "${GREEN}Installed:${NC}  $INSTALLED"
echo -e "${CYAN}Updated:${NC}    $UPDATED"
echo -e "${YELLOW}Skipped:${NC}    $SKIPPED"
echo -e "${RED}Failed:${NC}     $FAILED"
echo ""

if [[ $FAILED -gt 0 ]]; then
    warn "Some installations failed. Review the output above for details."
fi

info "Restart your terminal or run 'source ~/.bashrc' to apply shell changes."
if groups "$USER" 2>/dev/null | grep -qvE "(docker|libvirt)"; then
    info "Log out and back in for docker/libvirt group membership to take effect."
fi
echo ""
