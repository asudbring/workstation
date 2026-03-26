#!/usr/bin/env bash
# ============================================================================
# setup-ssh-keys.sh — One-time SSH Key Setup for sudbringlab servers
# ============================================================================
# Generates an Ed25519 SSH key pair, encrypts the private key with age,
# and uploads to a secret GitHub Gist for secure retrieval on new machines.
#
# Prerequisites:
#   - age (brew install age)
#   - gh CLI (brew install gh) — must be authenticated
#
# Run once, then paste the gist ID into install-macos.sh and install-windows.ps1
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[OK]${NC}      $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}    $*"; exit 1; }

KEY_NAME="sudbringlab"
KEY_PATH="$HOME/.ssh/$KEY_NAME"
KEY_COMMENT="allen@sudbring.com"

echo -e "${BOLD}SSH Key Setup for sudbringlab servers${NC}"
echo -e "${BOLD}======================================${NC}\n"

# ── Pre-flight ─────────────────────────────────────────────────────────────
command -v age &>/dev/null || fail "age not found. Install with: brew install age"
command -v gh &>/dev/null  || fail "gh CLI not found. Install with: brew install gh"

# Verify gh is authenticated
if ! gh auth status &>/dev/null 2>&1; then
    fail "GitHub CLI not authenticated. Run: gh auth login"
fi

# ── Step 1: Generate SSH key ──────────────────────────────────────────────
if [[ -f "$KEY_PATH" ]]; then
    warn "SSH key already exists at $KEY_PATH"
    read -rp "Overwrite? (y/N): " overwrite
    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
        info "Using existing key"
    else
        ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$KEY_PATH" -N ""
        success "SSH key generated at $KEY_PATH"
    fi
else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$KEY_PATH" -N ""
    success "SSH key generated at $KEY_PATH"
fi

# ── Step 2: Encrypt private key with age ──────────────────────────────────
info "Encrypting private key with age..."
echo -e "${YELLOW}Enter a strong passphrase (you'll need this on every new machine):${NC}"

ENCRYPTED_FILE="/tmp/${KEY_NAME}.age"
ENCODED_FILE="/tmp/${KEY_NAME}.age.b64"
age -p -o "$ENCRYPTED_FILE" "$KEY_PATH"
base64 -i "$ENCRYPTED_FILE" -o "$ENCODED_FILE"
success "Private key encrypted and base64-encoded"

# ── Step 3: Upload to secret GitHub Gist ──────────────────────────────────
info "Uploading encrypted key and public key to secret GitHub Gist..."

GIST_URL=$(gh gist create \
    --desc "SSH keys for sudbringlab servers (age-encrypted, base64)" \
    "$ENCODED_FILE" \
    "${KEY_PATH}.pub" \
    2>&1)

# Extract gist ID from URL
GIST_ID=$(echo "$GIST_URL" | grep -oE '[a-f0-9]{32}' | head -1)

if [[ -z "$GIST_ID" ]]; then
    fail "Failed to create gist. Output: $GIST_URL"
fi

success "Secret gist created!"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  IMPORTANT — Save this gist ID:${NC}"
echo -e "${BOLD}  ${GREEN}$GIST_ID${NC}"
echo -e "${BOLD}  Gist URL: $GIST_URL${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""

# ── Step 4: Clean up temp files ───────────────────────────────────────────
rm -f "$ENCRYPTED_FILE" "$ENCODED_FILE"
success "Temp encrypted file cleaned up"

# ── Step 5: Print next steps ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo -e "1. ${YELLOW}Paste the gist ID into install-macos.sh and install-windows.ps1${NC}"
echo -e "   Look for: SSH_GIST_ID=\"PASTE_GIST_ID_HERE\""
echo ""
echo -e "2. ${YELLOW}Deploy public key to both servers:${NC}"
echo -e "   ssh-copy-id -i ${KEY_PATH}.pub allenadmin@media-server.sudbringlab.com"
echo -e "   ssh-copy-id -i ${KEY_PATH}.pub allenadmin@media.sudbringlab.com"
echo ""
echo -e "3. ${YELLOW}Test SSH access:${NC}"
echo -e "   ssh allenadmin@media-server.sudbringlab.com 'echo Connected!'"
echo -e "   ssh allenadmin@media.sudbringlab.com 'echo Connected!'"
echo ""
echo -e "4. ${YELLOW}Commit and push the updated install scripts${NC}"
echo ""

# Print the public key for reference
echo -e "${BOLD}Your public key (for reference):${NC}"
cat "${KEY_PATH}.pub"
echo ""
