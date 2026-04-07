#!/usr/bin/env bash
# install-ai.sh — AI/ML Python environment
# Installs: uv, ~/ai-env (via uv sync + pyproject.toml), Ollama, Aider, llm CLI
# Safe to re-run — idempotent throughout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
WITH_VENV=false
VENV_DIR="$HOME/ai-env"

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
    --with-venv) WITH_VENV=true ;;
    --help)
      echo "Usage: $0 [--dry-run] [--with-venv]"
      echo "  --with-venv    Create ~/ai-env and sync ML packages via uv sync"
      exit 0
      ;;
  esac
done

# shellcheck source=lib/os.sh
source "$SCRIPT_DIR/lib/os.sh"
OS="$(detect_os)"

echo -e "${BOLD}AI Environment — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── uv ────────────────────────────────────────────────────────────────────────
section "uv — Python Package Manager"
if command -v uv &>/dev/null; then
  skip "uv ($(uv --version))"
elif $DRY_RUN; then
  dryrun "Would run: curl -LsSf https://astral.sh/uv/install.sh | sh"
else
  log "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  ok "uv installed ($(uv --version))"
fi

# Ensure uv is on PATH for subsequent steps
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# ── System build deps (Linux only) ───────────────────────────────────────────
if [[ "$OS" == linux-* ]]; then
  section "System Build Dependencies"
  APT_PKGS=()
  for pkg in git-lfs clang build-essential python3-venv; do
    if dpkg -s "$pkg" &>/dev/null 2>&1; then
      skip "$pkg"
    else
      APT_PKGS+=("$pkg")
    fi
  done
  if [ ${#APT_PKGS[@]} -gt 0 ]; then
    if $DRY_RUN; then
      dryrun "Would run: apt-get install -y ${APT_PKGS[*]}"
    else
      log "Installing: ${APT_PKGS[*]}"
      sudo apt-get install -y -qq "${APT_PKGS[@]}"
      ok "Build dependencies installed"
    fi
  fi

  if command -v git-lfs &>/dev/null; then
    git lfs install --skip-repo 2>/dev/null || true
  fi
fi

# ── ~/ai-env virtual environment (opt-in via --with-venv) ────────────────────
if $WITH_VENV; then
  section "Python Virtual Environment (~/ai-env)"
  if [ -d "$VENV_DIR" ]; then
    skip "$VENV_DIR (already exists)"
  elif $DRY_RUN; then
    dryrun "Would run: uv venv $VENV_DIR"
  else
    log "Creating virtual environment at $VENV_DIR..."
    uv venv "$VENV_DIR"
    ok "Virtual environment created"
  fi

  # ── AI/ML packages via uv sync ──────────────────────────────────────────────
  section "AI/ML Packages (uv sync)"
  if $DRY_RUN; then
    dryrun "Would run: UV_PROJECT_ENVIRONMENT=$VENV_DIR uv sync --directory $SCRIPT_DIR"
  else
    log "Syncing packages from pyproject.toml..."
    UV_PROJECT_ENVIRONMENT="$VENV_DIR" uv sync \
      --directory "$SCRIPT_DIR" \
      --no-dev \
      --inexact
    ok "AI/ML packages installed"
  fi
else
  section "Python Virtual Environment (~/ai-env)"
  skip "$HOME/ai-env (opt-in — pass --with-venv to create)"
fi

# ── Ollama ────────────────────────────────────────────────────────────────────
section "Ollama — Local LLM Inference"
if command -v ollama &>/dev/null; then
  skip "ollama ($(ollama --version 2>/dev/null | head -1))"
elif $DRY_RUN; then
  dryrun "Would run: curl -fsSL https://ollama.com/install.sh | sh"
else
  log "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  ok "Ollama installed"
  echo "  Tip: run 'ollama pull llama3.2' to download your first model"
fi

# ── Aider ─────────────────────────────────────────────────────────────────────
section "Aider — AI Pair Programming"
if command -v aider &>/dev/null; then
  skip "aider ($(aider --version 2>/dev/null | head -1))"
elif $DRY_RUN; then
  dryrun "Would run: uv tool install aider-chat"
else
  log "Installing aider..."
  uv tool install aider-chat --python 3.13
  ok "aider installed"
fi

# ── llm CLI ───────────────────────────────────────────────────────────────────
section "llm CLI — Simon Willison's LLM tool"
if command -v llm &>/dev/null; then
  skip "llm ($(llm --version 2>/dev/null | head -1))"
elif $DRY_RUN; then
  dryrun "Would run: uv tool install llm"
else
  log "Installing llm CLI..."
  uv tool install llm
  ok "llm installed"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}AI environment install complete!${RESET}"
echo ""
echo -e "  Activate:  ${CYAN}source $VENV_DIR/bin/activate${RESET}"
echo -e "  Audit:     ${CYAN}$(dirname "$SCRIPT_DIR")/dev-workstation-build/audit.sh${RESET}"
echo ""
echo -e "  Next steps:"
echo -e "    • Set API keys in ${CYAN}~/.config/workstation/env.sh${RESET}"
echo -e "    • Log in to HF:  ${CYAN}huggingface-cli login${RESET}"
echo -e "    • Pull a model:  ${CYAN}ollama pull llama3.2${RESET}"
echo ""
