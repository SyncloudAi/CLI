#!/usr/bin/env bash
set -e

VERSION="v0.1.0"
REPO="Gggggggggbbb/syncloudAi"

echo "==> Installing Syncloud CLI ($VERSION) from $REPO"

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then ARCH="arm64"; fi

ASSET="syncloud_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET"

echo "==> Downloading Syncloud CLI from $URL"
curl -fsSL "$URL" -o "/tmp/$ASSET"
tar -xzf "/tmp/$ASSET" -C "$INSTALL_DIR"
rm "/tmp/$ASSET"

echo "==> Syncloud installed at $INSTALL_DIR"
export PATH="$INSTALL_DIR:$PATH"

# --- Terraform ---
if ! command -v terraform >/dev/null 2>&1; then
  echo "⚠️ Terraform not found."
  read -p "Do you want to install Terraform now? (y/n): " yn
  if [ "$yn" = "y" ]; then
    echo "==> Installing Terraform..."
    curl -fsSL "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_${OS}_${ARCH}.zip" -o /tmp/terraform.zip
    unzip -o /tmp/terraform.zip -d "$INSTALL_DIR"
    rm /tmp/terraform.zip
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
    if [[ "$OS" == "darwin" ]]; then
      curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
      sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
    else
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
      unzip -q /tmp/awscliv2.zip -d /tmp
      sudo /tmp/aws/install
    fi
    echo "AWS CLI installed. Run 'aws configure' to set up credentials."
  else
    echo "Skipped AWS CLI installation."
  fi
else
  echo "AWS CLI already installed."
fi

echo "✅ Installation finished. Run 'syncloud --help' to get started."
