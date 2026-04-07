#!/usr/bin/env bash
# install-ops.sh — DevOps + platform tools
# Installs: Docker + Compose, Open WebUI (Docker), lazygit, k9s, starship
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

echo -e "${BOLD}Ops Tools — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── Docker ────────────────────────────────────────────────────────────────────
section "Docker + Compose"
if command -v docker &>/dev/null; then
  skip "docker ($(docker --version))"
else
  if [[ "$OS" == macos-* ]]; then
    if $DRY_RUN; then
      dryrun "Would run: brew install --cask docker"
    else
      log "Installing Docker Desktop via Homebrew..."
      # Pre-create dir the docker-desktop cask needs — brew spawns a subprocess
      # that loses the TTY, so sudo can't prompt there. Run it here first.
      sudo mkdir -p /usr/local/cli-plugins
      brew install --cask docker
      ok "Docker Desktop installed"
      log "Launching Docker Desktop..."
      open -a Docker
      log "Waiting for Docker daemon (up to 60s)..."
      for i in $(seq 1 60); do
        if docker info &>/dev/null 2>&1; then
          ok "Docker daemon is ready"
          break
        fi
        if [[ $i -eq 60 ]]; then
          echo "Docker daemon did not start in time — Open WebUI will be skipped."
          echo "Re-run this script after Docker Desktop is running."
        fi
        sleep 1
      done
    fi
  else
    # Linux: official Docker apt repo
    if $DRY_RUN; then
      dryrun "Would install Docker via get.docker.com script"
    else
      log "Installing Docker..."
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER"
      ok "Docker installed — log out and back in for group membership to take effect"
    fi
  fi
fi

# Docker Compose v2 (plugin)
if docker compose version &>/dev/null 2>&1; then
  skip "docker compose plugin ($(docker compose version --short 2>/dev/null))"
elif $DRY_RUN; then
  dryrun "Would install docker compose plugin"
else
  if [[ "$OS" == linux-* ]]; then
    log "Installing Docker Compose plugin..."
    COMPOSE_VERSION="$(curl -sSfL https://api.github.com/repos/docker/compose/releases/latest |
      grep '"tag_name"' | cut -d'"' -f4)"
    ARCH="$(uname -m)"
    sudo curl -sSfL \
      "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${ARCH}" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ok "docker compose plugin installed"
  else
    ok "docker compose plugin included with Docker Desktop"
  fi
fi

# ── Open WebUI ────────────────────────────────────────────────────────────────
section "Open WebUI (Docker)"
if ! docker info &>/dev/null 2>&1; then
  skip "Open WebUI — Docker daemon not running, skipping"
elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^open-webui$"; then
  skip "open-webui container (already exists)"
elif $DRY_RUN; then
  dryrun "Would run: docker run -d open-webui on port 3000"
else
  log "Starting Open WebUI container..."
  docker run -d \
    --name open-webui \
    -p 3000:8080 \
    -v open-webui:/app/backend/data \
    --restart always \
    ghcr.io/open-webui/open-webui:main
  ok "Open WebUI running at http://localhost:3000"
fi

# ── lazygit ───────────────────────────────────────────────────────────────────
section "lazygit"
if command -v lazygit &>/dev/null; then
  skip "lazygit ($(lazygit --version 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install lazygit"
  else
    log "Installing lazygit..."
    brew install lazygit
    ok "lazygit installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would download lazygit binary from GitHub releases"
  else
    log "Installing lazygit..."
    LAZYGIT_VERSION="$(curl -sSfL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
      grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')"
    ARCH="$(uname -m)"
    LG_ARCH="x86_64"
    [[ "$ARCH" == "aarch64" ]] && LG_ARCH="arm64"
    curl -sSfL \
      "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz" |
      tar -xz -C /tmp lazygit
    sudo install -m 755 /tmp/lazygit /usr/local/bin/lazygit
    rm -f /tmp/lazygit
    ok "lazygit ${LAZYGIT_VERSION} installed"
  fi
fi

# ── k9s ───────────────────────────────────────────────────────────────────────
section "k9s"
if command -v k9s &>/dev/null; then
  skip "k9s ($(k9s version --short 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install k9s"
  else
    log "Installing k9s..."
    brew install k9s
    ok "k9s installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would download k9s binary from GitHub releases"
  else
    log "Installing k9s..."
    K9S_VERSION="$(curl -sSfL https://api.github.com/repos/derailed/k9s/releases/latest |
      grep '"tag_name"' | cut -d'"' -f4)"
    ARCH="$(uname -m)"
    K9S_ARCH="amd64"
    [[ "$ARCH" == "aarch64" ]] && K9S_ARCH="arm64"
    curl -sSfL \
      "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${K9S_ARCH}.tar.gz" |
      tar -xz -C /tmp k9s
    sudo install -m 755 /tmp/k9s /usr/local/bin/k9s
    rm -f /tmp/k9s
    ok "k9s ${K9S_VERSION} installed"
  fi
fi

# ── starship ──────────────────────────────────────────────────────────────────
section "Starship Prompt"
if command -v starship &>/dev/null; then
  skip "starship ($(starship --version 2>/dev/null | head -1))"
elif $DRY_RUN; then
  dryrun "Would run: curl -sS https://starship.rs/install.sh | sh"
else
  log "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  ok "starship installed"
fi

echo -e "\n${BOLD}${GREEN}Ops tools install complete!${RESET}\n"
