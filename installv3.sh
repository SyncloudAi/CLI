#!/usr/bin/env bash
set -euo pipefail # Ensures script exits immediately on errors (pipefail)
IFS=$'\n\t'

VERSION="v0.4.1"
REPO="Gggggggggbbb/syncloudAi"
INSTALL_DIR="$HOME/.local/bin"

# ----------------------------------------------------------------------
# 1. ANNOUNCEMENT
# ----------------------------------------------------------------------
echo "==================================================="
echo "==> Syncloud Installation Script ($VERSION)"
echo "==================================================="
echo "Installing the following components:"
echo "  - 🔑 Syncloud CLI (to $INSTALL_DIR)"
echo "  - 🌎 Terraform (if missing)"
echo "  - ☁️ AWS CLI (if missing)"
echo ""

# ----------------------------------------------------------------------
# 2. SYNCLOUD CLI INSTALLATION (Main Binary)
# ----------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"

# Detect OS and Architecture
OS="$(uname | tr '[:upper:]' '[:lower:]')"   # darwin | linux
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  ARCH="arm64"
fi

ASSET="syncloud_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "==> Downloading Syncloud CLI from $URL"
curl -fsSL "$URL" -o "$tmpdir/$ASSET"

echo "==> Extracting archive"
tar -xzf "$tmpdir/$ASSET" -C "$tmpdir" --strip-components=1 || tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"

# Try to locate the binary robustly:
binpath=""

# exact name preferred
binpath="$(find "$tmpdir" -maxdepth 3 -type f -name 'syncloud' -print -quit)"

# pattern fallback
if [ -z "${binpath:-}" ]; then
  binpath="$(find "$tmpdir" -maxdepth 3 -type f \( -name 'syncloud-*' -o -name 'syncloud_*' \) -print -quit)"
fi

# last resort: any single file
if [ -z "${binpath:-}" ]; then
  binpath="$(find "$tmpdir" -maxdepth 3 -type f -print -quit)"
fi

if [ -z "${binpath:-}" ]; then
  echo "ERROR: syncloud binary not found in archive"
  exit 1
fi

echo "==> Installing to $INSTALL_DIR/syncloud"
rm -f "$INSTALL_DIR/syncloud"
install -m 0755 "$binpath" "$INSTALL_DIR/syncloud"

# Clear macOS quarantine flag if present (no-op elsewhere)
command -v xattr >/dev/null 2>&1 && xattr -d com.apple.quarantine "$INSTALL_DIR/syncloud" 2>/dev/null || true

echo "==> Syncloud installed at $INSTALL_DIR/syncloud"

# Refresh PATH for current shell and clear command cache
export PATH="$INSTALL_DIR:$PATH"
hash -r 2>/dev/null || true
[ -n "${ZSH_VERSION:-}" ] && rehash || true

# Persist PATH for future shells
zprofile="$HOME/.zprofile"
[ -n "${ZDOTDIR:-}" ] && zprofile="$ZDOTDIR/.zprofile"
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zprofile"
  echo "==> Added $INSTALL_DIR to PATH in $zprofile (for zsh login shells)"
fi

bash_profile="$HOME/.bashrc"
if [ "$OS" = "darwin" ] && [ ! -f "$HOME/.bashrc" ]; then
  bash_profile="$HOME/.bash_profile"
fi
if [ -n "${BASH_VERSION:-}" ]; then
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$bash_profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bash_profile"
    echo "==> Added $INSTALL_DIR to PATH in $bash_profile (for bash sessions)"
  fi
fi

# ----------------------------------------------------------------------
# 3. VERIFY INSTALLATION
# ----------------------------------------------------------------------
echo ""
echo "==> Installed Syncloud version:"
"$INSTALL_DIR/syncloud" --version 2>/dev/null || "$INSTALL_DIR/syncloud" -ver || true
echo ""
echo "==================================================="
echo "✅ Syncloud CLI installation finished."
echo "==================================================="

# ----------------------------------------------------------------------
# 3. INSTALL TERRAFORM (Non-Interactive, conditional)
# ----------------------------------------------------------------------
# Set the current stable version for Terraform installation
TERRAFORM_VERSION="1.13.3" # Replaced the old/failing version 1.9.8

if ! command -v terraform >/dev/null 2>&1; then
  echo ""
  echo "==> Terraform not found. Installing version ${TERRAFORM_VERSION} now..."
    
  # Check for Homebrew on macOS and use it (prioritized)
  if [ "$OS" = "darwin" ] && command -v brew >/dev/null 2>&1; then
      echo "Installing Terraform via Homebrew (Recommended)..."
      brew tap hashicorp/tap 2>/dev/null || true
      brew install hashicorp/tap/terraform
      echo "Terraform installed via Homebrew."
  else
      # Manual download and install (For Linux and macOS without Homebrew)
      
      # Ensure unzip exists (The logic for apt/yum/dnf for Linux remains here)
      if ! command -v unzip >/dev/null 2>&1; then
          # ... (Linux/macOS unzip installation/warning logic) ...
          if [ "$OS" = "linux" ]; then
            if command -v apt >/dev/null 2>&1; then
              sudo apt update && sudo apt install -y unzip
            # ... (other Linux package managers) ...
            fi
          fi
      fi
      
      # --- CORRECTED DOWNLOAD URL ---
      curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" -o "$tmpdir/terraform.zip"
      # ----------------------------
      
      unzip -o "$tmpdir/terraform.zip" -d "$tmpdir" >/dev/null
      install -m 0755 "$tmpdir/terraform" "$INSTALL_DIR/terraform"
      echo "Terraform installed to $INSTALL_DIR/terraform."
  fi
else
  echo "Terraform already installed."
fi
# ----------------------------------------------------------------------
# 4. INSTALL AWS CLI (Non-Interactive, conditional)
# ----------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo ""
  echo "==> AWS CLI not found. Installing now..."

  if [ "$OS" = "darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "Installing AWS CLI via Homebrew..."
      brew install awscli
    else
      # Fallback to official .pkg install (requires sudo)
      echo "Installing AWS CLI using official .pkg installer (requires sudo)..."
      curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "$tmpdir/AWSCLIV2.pkg"
      sudo installer -pkg "$tmpdir/AWSCLIV2.pkg" -target /
    fi
  else
    # Linux installation logic
    AWS_ARCH="x86_64"; [ "$ARCH" = "arm64" ] && AWS_ARCH="aarch64"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "$tmpdir/awscliv2.zip"
    unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
    sudo "$tmpdir/aws/install"
  fi
  echo "AWS CLI installed. Run 'aws configure' to set up credentials."
else
  echo "AWS CLI already installed."
fi

# ----------------------------------------------------------------------
# 5. FINAL INSTRUCTIONS
# ----------------------------------------------------------------------
echo ""
echo "==================================================="
echo "✅ Syncloud CLI installation finished."
echo "==================================================="
echo "The CLI and dependencies were installed to: $INSTALL_DIR"
echo "Your shell configuration was updated, but for your shell to find 'syncloud':"
echo ""
echo "  1. **OPEN A NEW TERMINAL WINDOW** (Recommended) or"
echo "  2. **RELOAD YOUR CURRENT SHELL** by running: exec $SHELL -l"
echo ""
echo "Once done, you can try: syncloud --help"
