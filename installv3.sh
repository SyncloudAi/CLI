#!/usr/bin/env bash
set -euo pipefail # Corrected to 'pipefail' (fixes 'namepefail' typo)
IFS=$'\n\t'

VERSION="v0.2.0"
REPO="Gggggggggbbb/syncloudAi"

echo "==================================================="
echo "==> Installing Syncloud CLI ($VERSION) from $REPO"
echo "==================================================="

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# ----------------------------------------------------------------------
# Detect OS and Architecture (Improved for common macOS/Linux variants)
# ----------------------------------------------------------------------
OS=$(uname | tr '[:upper:]' '[:lower:]') # darwin | linux
ARCH=$(uname -m)                         # x86_64 | arm64 | aarch64

# Normalize architecture names
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

echo "==> Extracting to $INSTALL_DIR"
tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"

# ----------------------------------------------------------------------
# Place binary with correct permissions (Simplified fallback logic)
# ----------------------------------------------------------------------
if [ -f "$tmpdir/syncloud" ]; then
    install -m 0755 "$tmpdir/syncloud" "$INSTALL_DIR/syncloud"
else
    # Find first executable file using POSIX-compliant method
    binpath=$(find "$tmpdir" -maxdepth 1 -type f -perm +111 | head -n 1)
    
    if [ -z "${binpath}" ]; then
        echo "ERROR: syncloud binary not found in archive"; exit 1
    fi
    install -m 0755 "$binpath" "$INSTALL_DIR/syncloud"
fi

echo "==> Syncloud installed at $INSTALL_DIR/syncloud"

# Update PATH for the current session (temporary)
export PATH="$INSTALL_DIR:$PATH"
hash -r 2>/dev/null || true # Force shell to immediately recognize the new command

# ----------------------------------------------------------------------
# Persist PATH for future shells
# ----------------------------------------------------------------------
# zsh (macOS default and common on Linux)
zprofile="$HOME/.zprofile"
if [ -n "${ZDOTDIR:-}" ]; then zprofile="$ZDOTDIR/.zprofile"; fi

if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zprofile"
  echo "==> Added $INSTALL_DIR to PATH in $zprofile (for zsh login shells)"
fi

# bash (if used)
bash_profile="$HOME/.bashrc"
if [ "$OS" = "darwin" ] && [ ! -f "$HOME/.bashrc" ]; then
    bash_profile="$HOME/.bash_profile" # macOS typically uses .bash_profile
fi

if [ -n "${BASH_VERSION:-}" ]; then
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$bash_profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bash_profile"
    echo "==> Added $INSTALL_DIR to PATH in $bash_profile (for bash sessions)"
  fi
fi

# ----------------------------------------------------------------------
# Install Terraform (Added macOS unzip dependency check)
# ----------------------------------------------------------------------
if ! command -v terraform >/dev/null 2>&1; then
  echo ""
  echo "⚠️ Terraform not found."
  read -p "Do you want to install Terraform now? (y/n): " yn
  if [ "$yn" = "y" ]; then
    echo "==> Installing Terraform..."
    
    # Ensure unzip exists across different OS/package managers
    if ! command -v unzip >/dev/null 2>&1; then
      if [ "$OS" = "linux" ]; then
        if command -v apt >/dev/null 2>&1; then
          sudo apt update && sudo apt install -y unzip
        elif command -v yum >/dev/null 2>&1; then
          sudo yum install -y unzip
        elif command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y unzip
        else
          echo "ERROR: Please install 'unzip' using your Linux package manager (apt, yum, dnf) and re-run."
          exit 1
        fi
      elif [ "$OS" = "darwin" ]; then
         if command -v brew >/dev/null 2>&1; then
             echo "Installing 'unzip' via Homebrew..."
             brew install unzip
         else
             # Fallback: assume built-in unzip is often present, but warn if missing
             echo "WARNING: 'unzip' not found. If this install fails, please install Homebrew and 'unzip'."
         fi
      else
        echo "ERROR: Please install 'unzip' manually and re-run the installer."
        exit 1
      fi
    fi
    
    curl -fsSL "https://releases.hashicorp.com/terraform/1.9.8/terraform_${OS}_${ARCH}.zip" -o "$tmpdir/terraform.zip"
    unzip -o "$tmpdir/terraform.zip" -d "$tmpdir" >/dev/null
    install -m 0755 "$tmpdir/terraform" "$INSTALL_DIR/terraform"
    echo "Terraform installed to $INSTALL_DIR/terraform."
  else
    echo "Skipped Terraform installation."
  fi
else
  echo "Terraform already installed."
fi

# ----------------------------------------------------------------------
# Install AWS CLI (Added Homebrew option for macOS)
# ----------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo ""
  echo "⚠️ AWS CLI not found."
  read -p "Do you want to install AWS CLI now? (y/n): " yn
  if [ "$yn" = "y" ]; then
    echo "==> Installing AWS CLI..."
    if [ "$OS" = "darwin" ]; then
      if command -v brew >/dev/null 2>&1; then
        echo "Installing AWS CLI via Homebrew..."
        brew install awscli
      else
        # Original .pkg install (requires sudo)
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
    echo "Skipped AWS CLI installation."
  fi
else
  echo "AWS CLI already installed."
fi

# ----------------------------------------------------------------------
# Final Instructions (Improved Clarity)
# ----------------------------------------------------------------------
echo ""
echo "==================================================="
echo "✅ Syncloud CLI installation finished."
echo "==================================================="
echo "The CLI was installed to: $INSTALL_DIR"
echo "Your shell configuration was updated, but for your shell to find 'syncloud':"
echo ""
echo "  1. **OPEN A NEW TERMINAL WINDOW** (Recommended) or"
echo "  2. **RELOAD YOUR CURRENT SHELL** by running: exec $SHELL -l"
echo ""
echo "Once done, you can try: syncloud --help"
