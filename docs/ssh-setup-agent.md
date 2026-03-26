# AI Agent Instructions: Install SSH Keys for sudbringlab Servers

These instructions are for AI agents (GitHub Copilot CLI, OpenCode, etc.) to set up SSH key-based authentication for Allen's home lab servers on any workstation.

## When to use

Use these instructions when:
- Setting up a new or rebuilt workstation that needs SSH access to sudbringlab servers
- The user says "install SSH keys", "set up SSH for sudbringlab", or "configure SSH for media server"
- The full install script (`install-macos.sh` / `install-windows.ps1`) wasn't run, or the SSH section was skipped

## Target servers

| Host | User |
|---|---|
| `media-server.sudbringlab.com` | `allenadmin` |
| `media.sudbringlab.com` | `allenadmin` |

## Prerequisites

The following tools must be installed:
- `age` — file encryption (`brew install age` / `winget install FiloSottile.age` / `apt install age`)
- `gh` — GitHub CLI, authenticated (`gh auth status` must show logged in)

## Gist details

- **Gist ID**: `639363ac7797dced788c7b2706986fc6`
- **Files in gist**: `sudbringlab.age.b64` (base64-encoded age-encrypted private key), `sudbringlab.pub` (public key)

## Step-by-step procedure

### 1. Check if keys already exist

```bash
# If this file exists, SSH keys are already installed — STOP
ls ~/.ssh/sudbringlab
```

If the key exists, inform the user and stop. Do not overwrite.

### 2. Detect the operating system

Detect the OS and set variables accordingly:

- **macOS**: `base64 -d` uses `-D` flag or `-d` with `-i` input
- **Linux**: `base64 -d` works directly
- **Windows (PowerShell)**: Use `[System.Convert]::FromBase64String()`

### 3. Ensure prerequisites are installed

```bash
# Check age
command -v age || echo "INSTALL age FIRST"

# Check gh and auth
gh auth status
```

If `age` is missing, install it:
- macOS: `brew install age`
- Linux: `sudo apt install age` or `sudo dnf install age`
- Windows: `winget install FiloSottile.age`

### 4. Create .ssh directory

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

On Windows PowerShell:
```powershell
$sshDir = "$HOME\.ssh"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force }
```

### 5. Download and decrypt the private key

**IMPORTANT**: The decryption step prompts for a passphrase interactively. The agent MUST let the user type the passphrase at the terminal prompt. NEVER ask the user for the passphrase in chat or store it anywhere.

#### macOS / Linux

```bash
# Download base64-encoded encrypted key from gist
gh gist view 639363ac7797dced788c7b2706986fc6 -f sudbringlab.age.b64 --raw > /tmp/sudbringlab.b64

# Decode base64 to binary
base64 -d -i /tmp/sudbringlab.b64 -o /tmp/sudbringlab.age   # macOS
# OR: base64 -d /tmp/sudbringlab.b64 > /tmp/sudbringlab.age  # Linux

# Decrypt with age (USER ENTERS PASSPHRASE AT PROMPT)
age -d -o ~/.ssh/sudbringlab /tmp/sudbringlab.age

# Set permissions
chmod 600 ~/.ssh/sudbringlab

# Clean up
rm -f /tmp/sudbringlab.b64 /tmp/sudbringlab.age
```

#### Windows PowerShell

```powershell
# Download base64-encoded encrypted key from gist
$b64 = gh gist view 639363ac7797dced788c7b2706986fc6 -f sudbringlab.age.b64 --raw

# Decode base64 to binary file
[System.Convert]::FromBase64String($b64) | Set-Content "$env:TEMP\sudbringlab.age" -AsByteStream

# Decrypt with age (USER ENTERS PASSPHRASE AT PROMPT)
age -d -o "$HOME\.ssh\sudbringlab" "$env:TEMP\sudbringlab.age"

# Clean up
Remove-Item "$env:TEMP\sudbringlab.age" -Force
```

### 6. Download the public key

```bash
gh gist view 639363ac7797dced788c7b2706986fc6 -f sudbringlab.pub --raw > ~/.ssh/sudbringlab.pub
chmod 644 ~/.ssh/sudbringlab.pub
```

Windows:
```powershell
gh gist view 639363ac7797dced788c7b2706986fc6 -f sudbringlab.pub --raw | Set-Content "$HOME\.ssh\sudbringlab.pub"
```

### 7. Configure SSH config

Add host entries to `~/.ssh/config`. Use a marker comment to prevent duplicates.

Check if entries already exist first:
```bash
grep -q "sudbringlab" ~/.ssh/config 2>/dev/null && echo "ALREADY CONFIGURED" || echo "NEEDS CONFIG"
```

If not present, append:

```
# Managed by workstation install — sudbringlab
Host media-server.sudbringlab.com
    HostName media-server.sudbringlab.com
    User allenadmin
    IdentityFile ~/.ssh/sudbringlab

Host media.sudbringlab.com
    HostName media.sudbringlab.com
    User allenadmin
    IdentityFile ~/.ssh/sudbringlab
```

Set permissions:
```bash
chmod 600 ~/.ssh/config
```

### 8. Test the connection

```bash
ssh -o ConnectTimeout=10 media-server.sudbringlab.com "hostname && echo OK"
ssh -o ConnectTimeout=10 media.sudbringlab.com "hostname && echo OK"
```

Both should return the hostname and "OK" with no password prompt.

## Security notes

- The private key in the gist is **age-encrypted** — it's useless without the passphrase
- The gist is **secret** (unlisted) — not discoverable via search
- The passphrase is NEVER stored in code, config files, or chat history
- The passphrase is ONLY entered at an interactive terminal prompt
- If the agent needs to run the `age -d` command, it must use an async/interactive shell so the user can type the passphrase directly

## Troubleshooting

| Issue | Fix |
|---|---|
| `age: command not found` | Install age: `brew install age` / `winget install FiloSottile.age` / `apt install age` |
| `gh: not logged in` | Run `gh auth login` first |
| `Permission denied (publickey)` | The public key may not be deployed on the server — contact Allen |
| `age: decryption failed` | Wrong passphrase — try again |
| Binary decode errors on macOS | Use `base64 -D` instead of `base64 -d` if on older macOS |
