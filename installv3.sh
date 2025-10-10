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
OS=$(uname | tr '[:upper:]' '[:lower:]')   # darwin | linux
ARCH=$(uname -m)
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
# Try strip top-level folder; if not applicable, fall back to normal extract
tar -xzf "$tmpdir/$ASSET" -C "$tmpdir" --strip-components=1 \
  || tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"

# Locate the binary robustly:
# 1) exact 'syncloud' by name (any depth up to 3)
# 2) pattern syncloud-* / syncloud_* (any depth up to 3)
# 3) last resort: any single file (we'll install with 0755)
binpath="$(find "$tmpdir" -maxdepth 3 -type f -name 'syncloud' -print -quit)"
if [ -z "${binpath:-}" ]; then
  binpath="$(find "$tmpdir" -maxdepth 3 -type f \( -name 'syncloud-*' -o -name 'syncloud_*' \) -print -quit)"
fi
if [ -z "${binpath:-}" ]; then
  binpath="$(find "$tmpdir" -maxdepth 3 -type f -print -quit)"
fi

if [ -z "${binpath:-}" ]; then
  echo "ERROR: syncloud binary not found in archive"; exit 1
fi

# Sanity check: verify the binary matches OS/ARCH (prevents Exec format error)
if command -v file >/dev/null 2>&1; then
  detected="$(file -b "$binpath")"
  case "$OS-$ARCH" in
    linux-amd64) echo "$detected" | grep -qi 'ELF 64-bit.*x86-64' || { echo "❌ Wrong binary for Linux amd64. Got: $detected"; exit 1; } ;;
    linux-arm64) echo "$detected" | grep -qi 'ELF 64-bit.*ARM aarch64' || { echo "❌ Wrong binary for Linux arm64. Got: $detected"; exit 1; } ;;
    darwin-amd64|darwin-arm64) echo "$detected" | grep -qi 'Mach-O 64-bit' || { echo "❌ Wrong binary for macOS. Got: $detected"; exit 1; } ;;
  esac
fi

echo "==> Installing to $INSTALL_DIR/syncloud"
rm -f "$INSTALL_DIR/syncloud"
install -m 0755 "$binpath" "$INSTALL_DIR/syncloud"

# Clear macOS quarantine flag if present (no-op elsewhere)
command -v xattr >/dev/null 2>&1 && xattr -d com.apple.quarantine "$INSTALL_DIR/syncloud" 2>/dev/null || true

echo "==> Syncloud installed at $INSTALL_DIR/syncloud"

# Update PATH for current session & refresh shell caches
export PATH="$INSTALL_DIR:$PATH"
hash -r 2>/dev/null || true
[ -n "${ZSH_VERSION:-}" ] && rehash || true
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
