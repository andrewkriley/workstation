#!/usr/bin/env bash
# install-cloud.sh — Cloud provider CLIs
# Installs: AWS CLI v2, Google Cloud CLI (gcloud)
# Safe to re-run — idempotent throughout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log() { echo -e "${CYAN}-->${RESET} $1"; }
ok() { echo -e "${GREEN}[done]${RESET} $1"; }
skip() { echo -e "${YELLOW}[skip]${RESET} $1"; }
section() { echo -e "\n${BOLD}${CYAN}=== $1 ===${RESET}"; }
dryrun() { echo -e "${YELLOW}[dry-run]${RESET} $1"; }

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --help)
      echo "Usage: $0 [--dry-run]"
      exit 0
      ;;
  esac
done

# shellcheck source=lib/os.sh
source "$SCRIPT_DIR/lib/os.sh"
OS="$(detect_os)"

echo -e "${BOLD}Cloud CLIs — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

install_aws_cli_linux() {
  if command -v aws &>/dev/null; then
    skip "aws ($(aws --version 2>&1 | head -1))"
    return 0
  fi

  if $DRY_RUN; then
    dryrun "Would install AWS CLI v2 (official zip installer)"
    return 0
  fi

  log "Installing AWS CLI v2..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq unzip ca-certificates curl

  arch="$(uname -m)"
  aws_arch="x86_64"
  if [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
    aws_arch="aarch64"
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  curl -sSfL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o "$tmpdir/awscliv2.zip"
  unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
  sudo "$tmpdir/aws/install" --update
  ok "aws installed ($(aws --version 2>&1 | head -1))"
}

install_aws_cli_macos() {
  if command -v aws &>/dev/null; then
    skip "aws ($(aws --version 2>&1 | head -1))"
    return 0
  fi

  if $DRY_RUN; then
    dryrun "Would run: brew install awscli"
    return 0
  fi

  log "Installing AWS CLI..."
  brew install awscli
  ok "aws installed ($(aws --version 2>&1 | head -1))"
}

install_gcloud_macos() {
  if command -v gcloud &>/dev/null; then
    skip "gcloud ($(gcloud version 2>/dev/null | head -1))"
    return 0
  fi

  if $DRY_RUN; then
    dryrun "Would run: brew install --cask google-cloud-sdk"
    return 0
  fi

  log "Installing Google Cloud SDK..."
  brew install --cask google-cloud-sdk
  ok "gcloud installed ($(gcloud version 2>/dev/null | head -1))"
}

install_gcloud_linux() {
  if command -v gcloud &>/dev/null; then
    skip "gcloud ($(gcloud version 2>/dev/null | head -1))"
    return 0
  fi

  if $DRY_RUN; then
    dryrun "Would add Google Cloud SDK apt repo and install google-cloud-cli"
    return 0
  fi

  log "Installing Google Cloud SDK via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg |
    sudo gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg
  sudo chmod a+r /etc/apt/keyrings/cloud.google.gpg

  echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" |
    sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq google-cloud-cli
  ok "gcloud installed ($(gcloud version 2>/dev/null | head -1))"
}

section "AWS CLI"
if [[ "$OS" == macos-* ]]; then
  install_aws_cli_macos
elif [[ "$OS" == linux-* ]]; then
  install_aws_cli_linux
else
  skip "aws (unsupported OS: $OS)"
fi

section "Google Cloud CLI (gcloud)"
if [[ "$OS" == macos-* ]]; then
  install_gcloud_macos
elif [[ "$OS" == linux-* ]]; then
  install_gcloud_linux
else
  skip "gcloud (unsupported OS: $OS)"
fi

echo -e "\n${BOLD}${GREEN}Cloud CLIs install complete!${RESET}\n"

