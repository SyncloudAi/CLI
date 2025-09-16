#!/usr/bin/env bash
# install.sh — Syncloud macOS/Linux installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SyncloudAi/syncloud/main/install.sh | bash
set -euo pipefail

APP="syncloud"
REPO="Gggggggggbbb/syncloudAi"
VERSION="${VERSION:-latest}"   # set VERSION=v0.1.0 to pin

say(){ printf "==> %s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1; }

# Detect OS/arch
case "$(uname -s)" in
  Linux)  OS="linux" ;;
  Darwin) OS="darwin" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1;;
esac

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64"; AWS_ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64"; AWS_ARCH="aarch64" ;;
  *) echo "Unsupported arch: $(uname -m)" >&2; exit 1;;
esac

# Pick install dir
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ]; then
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *) SHELL_RC="${HOME}/.bashrc"
       [ -n "${ZSH_VERSION:-}" ] && SHELL_RC="${HOME}/.zshrc"
       echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
       say "Added $INSTALL_DIR to PATH in $SHELL_RC"
       ;;
  esac
fi

need curl || { echo "curl required"; exit 1; }
need tar  || { echo "tar required";  exit 1; }

# Resolve release asset
if [ "$VERSION" = "latest" ]; then
  API="https://api.github.com/repos/${REPO}/releases/latest"
else
  API="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
fi
say "Fetching release metadata"
TAG=$(curl -fsSL "$API" | grep -oE '"tag_name":\s*"[^"]+"' | head -1 | cut -d'"' -f4)
[ -n "$TAG" ] || { echo "Cannot resolve tag"; exit 1; }

ASSET="${APP}_${TAG}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

# Download & extract
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
say "Downloading $URL"
curl -fsSL -o "$TMP/$ASSET" "$URL"
say "Extracting"
tar -xzf "$TMP/$ASSET" -C "$TMP"

# Move binary
chmod +x "$TMP/$APP"
mv "$TMP/$APP" "$INSTALL_DIR/$APP"
say "Installed $APP to $INSTALL_DIR/$APP"

# ----- Dependencies -----
ensure_terraform() {
  if need terraform; then say "Terraform present: $(terraform version | head -1)"; return; fi
  say "Terraform missing: installing…"
  TFV="1.9.5"
  TZIP="terraform_${TFV}_${OS}_${ARCH}.zip"
  if need brew; then
    brew install terraform
    return
  fi
  # Generic zip fallback (works on mac & most linux)
  need unzip || { say "Installing unzip"; if need apt; then sudo apt update && sudo apt install -y unzip; elif need dnf; then sudo dnf -y install unzip; elif need yum; then sudo yum -y install unzip; fi; }
  curl -fsSL -o "$TMP/$TZIP" "https://releases.hashicorp.com/terraform/${TFV}/${TZIP}"
  unzip -q "$TMP/$TZIP" -d "$TMP"
  chmod +x "$TMP/terraform"
  mv "$TMP/terraform" "$INSTALL_DIR/terraform"
}

ensure_awscli() {
  if need aws; then say "AWS CLI present: $(aws --version)"; return; fi
  say "AWS CLI missing: installing…"
  if [ "$OS" = "darwin" ]; then
    PKG="$(mktemp).pkg"
    curl -fsSL -o "$PKG" "https://awscli.amazonaws.com/AWSCLIV2.pkg"
    sudo installer -pkg "$PKG" -target /
  else
    need unzip || { say "Installing unzip"; if need apt; then sudo apt update && sudo apt install -y unzip; elif need dnf; then sudo dnf -y install unzip; elif need yum; then sudo yum -y install unzip; fi; }
    curl -fsSL -o "$TMP/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"
    unzip -q "$TMP/awscliv2.zip" -d "$TMP"
    sudo "$TMP/aws/install" || sudo "$TMP/aws/install" --update
  fi
}

ensure_terraform
ensure_awscli

# Prompt to configure AWS if no identity
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  cat <<EOF

Please run to configure AWS credentials:
  aws configure

EOF
fi

cat <<EOF

✔ ${APP} installed to ${INSTALL_DIR}
Try:
  ${APP} --help
  terraform version
  aws --version

EOF
