#!/usr/bin/env bash
# install-system.sh — Developer productivity tools
# Installs: ripgrep, bat, fzf, eza, zoxide, jq, yq, fnm, tmux
# Safe to re-run — idempotent throughout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()     { echo -e "${CYAN}-->${RESET} $1"; }
ok()      { echo -e "${GREEN}[done]${RESET} $1"; }
skip()    { echo -e "${YELLOW}[skip]${RESET} $1"; }
section() { echo -e "\n${BOLD}${CYAN}=== $1 ===${RESET}"; }
dryrun()  { echo -e "${YELLOW}[dry-run]${RESET} $1"; }

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

echo -e "${BOLD}System Tools — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── macOS (Homebrew) ──────────────────────────────────────────────────────────
if [[ "$OS" == macos-* ]]; then
  section "Homebrew Packages"

  BREW_PKGS=()
  for pkg in ripgrep bat fzf eza zoxide jq yq fnm tmux; do
    if brew list "$pkg" &>/dev/null; then
      skip "$pkg"
    else
      BREW_PKGS+=("$pkg")
    fi
  done

  if [ ${#BREW_PKGS[@]} -gt 0 ]; then
    if $DRY_RUN; then
      dryrun "Would run: brew install ${BREW_PKGS[*]}"
    else
      log "Installing: ${BREW_PKGS[*]}"
      brew install "${BREW_PKGS[@]}"
      ok "Homebrew packages installed"
    fi
  fi

  # fnm: install LTS node after fnm is available
  if command -v fnm &>/dev/null && ! fnm list | grep -q "lts"; then
    if $DRY_RUN; then
      dryrun "Would run: fnm install --lts"
    else
      log "Installing Node LTS via fnm..."
      fnm install --lts
      ok "Node LTS installed"
    fi
  fi
fi

# ── Linux (apt + scripts) ─────────────────────────────────────────────────────
if [[ "$OS" == linux-* ]]; then
  section "APT Packages"

  APT_PKGS=()
  for pkg in ripgrep fzf jq tmux; do
    if command -v "$pkg" &>/dev/null; then
      skip "$pkg"
    else
      APT_PKGS+=("$pkg")
    fi
  done

  # bat binary may be 'bat' or 'batcat' depending on Ubuntu version
  if ! command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
    APT_PKGS+=(bat)
  else
    skip "bat"
  fi

  if [ ${#APT_PKGS[@]} -gt 0 ]; then
    if $DRY_RUN; then
      dryrun "Would run: apt-get install -y ${APT_PKGS[*]}"
    else
      log "Installing apt packages: ${APT_PKGS[*]}"
      sudo apt-get install -y -qq "${APT_PKGS[@]}"
      ok "APT packages installed"
    fi
  fi

  # bat alias (Ubuntu names binary 'batcat')
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    if $DRY_RUN; then
      dryrun "Would create: $HOME/.local/bin/bat -> batcat"
    else
      mkdir -p "$HOME/.local/bin"
      ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
      ok "bat -> batcat alias created in ~/.local/bin"
    fi
  fi

  section "eza"
  if command -v eza &>/dev/null; then
    skip "eza"
  elif $DRY_RUN; then
    dryrun "Would add eza apt repo and install eza"
  else
    log "Adding eza apt repository..."
    sudo apt-get install -y -qq gpg
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq
    sudo apt-get install -y -qq eza
    ok "eza installed"
  fi

  section "zoxide"
  if command -v zoxide &>/dev/null; then
    skip "zoxide"
  elif $DRY_RUN; then
    dryrun "Would run: curl ... | sh  (zoxide install script)"
  else
    log "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed"
  fi

  section "yq"
  if command -v yq &>/dev/null; then
    skip "yq"
  elif $DRY_RUN; then
    dryrun "Would download yq binary from GitHub releases"
  else
    log "Installing yq..."
    ARCH="$(uname -m)"
    YQ_ARCH="amd64"
    [[ "$ARCH" == "aarch64" ]] && YQ_ARCH="arm64"
    YQ_VERSION="$(curl -sSfL https://api.github.com/repos/mikefarah/yq/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)"
    curl -sSfL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" \
      -o /tmp/yq
    sudo install -m 755 /tmp/yq /usr/local/bin/yq
    rm -f /tmp/yq
    ok "yq ${YQ_VERSION} installed"
  fi

  section "fnm (Fast Node Manager)"
  if command -v fnm &>/dev/null; then
    skip "fnm"
  elif $DRY_RUN; then
    dryrun "Would run: curl ... | bash  (fnm install script)"
  else
    log "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)" 2>/dev/null || true
    ok "fnm installed"
  fi

  # fnm: install Node LTS
  if command -v fnm &>/dev/null; then
    if $DRY_RUN; then
      dryrun "Would run: fnm install --lts && fnm use lts-latest"
    else
      if ! fnm list 2>/dev/null | grep -q "lts"; then
        log "Installing Node LTS via fnm..."
        fnm install --lts
        fnm use lts-latest
        ok "Node LTS installed"
      else
        skip "Node LTS (already installed via fnm)"
      fi
    fi
  fi
fi

echo -e "\n${BOLD}${GREEN}System tools install complete!${RESET}\n"
