#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

VERSION="v0.2.0"
REPO="Gggggggggbbb/syncloudAi"

echo "==> Installing Syncloud CLI ($VERSION) from $REPO"

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

OS=$(uname | tr '[:upper:]' '[:lower:]')   # darwin | linux
ARCH=$(uname -m)                            # x86_64 | arm64 | aarch64
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then ARCH="amd64"; fi
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

ASSET="syncloud_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "==> Downloading Syncloud CLI from $URL"
curl -fsSL "$URL" -o "$tmpdir/$ASSET"

echo "==> Extracting to $INSTALL_DIR"
tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"

# Place binary with correct permissions
if [ -f "$tmpdir/syncloud" ]; then
  install -m 0755 "$tmpdir/syncloud" "$INSTALL_DIR/syncloud"
else
  binpath="$(find "$tmpdir" -maxdepth 1 -type f -perm -u+x -print -quit || true)"
  if [ -z "${binpath}" ]; then
    echo "ERROR: syncloud binary not found in archive"; exit 1
  fi
  install -m 0755 "$binpath" "$INSTALL_DIR/syncloud"
fi

echo "==> Syncloud installed at $INSTALL_DIR/syncloud"
export PATH="$INSTALL_DIR:$PATH"

# Persist PATH for future shells
# zsh (macOS default)
if [ -n "${ZDOTDIR:-}" ]; then zprofile="$ZDOTDIR/.zprofile"; else zprofile="$HOME/.zprofile"; fi
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zprofile"
  echo "==> Added $INSTALL_DIR to PATH in $zprofile"
fi
# bash (if used)
if [ -n "${BASH_VERSION:-}" ]; then
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "==> Added $INSTALL_DIR to PATH in ~/.bashrc"
  fi
fi

# --- Terraform ---
if ! command -v terraform >/dev/null 2>&1; then
  echo "⚠️ Terraform not found."
  read -p "Do you want to install Terraform now? (y/n): " yn
  if [ "$yn" = "y" ]; then
    echo "==> Installing Terraform..."
    # ensure unzip exists (Linux minimal distros)
    if ! command -v unzip >/dev/null 2>&1; then
      if [ "$OS" = "linux" ]; then
        if command -v apt >/dev/null 2>&1; then
          sudo apt update && sudo apt install -y unzip
        elif command -v yum >/dev/null 2>&1; then
          sudo yum install -y unzip
        elif command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y unzip
        else
          echo "Please install 'unzip' with your package manager and re-run."
          exit 1
        fi
      fi
    fi
    curl -fsSL "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_${OS}_${ARCH}.zip" -o "$tmpdir/terraform.zip"
    unzip -o "$tmpdir/terraform.zip" -d "$tmpdir" >/dev/null
    install -m 0755 "$tmpdir/terraform" "$INSTALL_DIR/terraform"
    echo "Terraform installed."
  else
    echo "Skipped Terraform installation."
  fi
else
  echo "Terraform already installed."
fi

# --- AWS CLI ---
if ! command -v aws >/dev/null 2>&1; then
  echo "⚠️ AWS CLI not found."
  read -p "Do you want to install AWS CLI now? (y/n): " yn
  if [ "$yn" = "y" ]; then
    echo "==> Installing AWS CLI..."
    if [ "$OS" = "darwin" ]; then
      curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "$tmpdir/AWSCLIV2.pkg"
      sudo installer -pkg "$tmpdir/AWSCLIV2.pkg" -target /
    else
      # pick correct Linux arch asset
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

echo "✅ Installation finished. Open a new terminal (or run 'exec $SHELL -l') and try: syncloud --help"
