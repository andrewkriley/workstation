#!/usr/bin/env bash
# install-dotfiles.sh — Shell RC wiring and environment configuration
# Wires: env.sh sourcing, ai-env alias, starship init, zoxide init, fnm env,
#        ~/.local/bin on PATH, uv tools on PATH
# Safe to re-run — idempotent throughout (guards all appends with grep checks).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
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

echo -e "${BOLD}Dotfiles — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── Detect shell RC files ─────────────────────────────────────────────────────
RC_FILES=()
[ -f "$HOME/.bashrc" ]  && RC_FILES+=("$HOME/.bashrc")
[ -f "$HOME/.zshrc" ]   && RC_FILES+=("$HOME/.zshrc")
[ -f "$HOME/.bash_profile" ] && [[ "$OS" == macos-* ]] && RC_FILES+=("$HOME/.bash_profile")

if [ ${#RC_FILES[@]} -eq 0 ]; then
  log "No shell RC files found — creating ~/.bashrc"
  if ! $DRY_RUN; then
    touch "$HOME/.bashrc"
    RC_FILES+=("$HOME/.bashrc")
  fi
fi

log "Shell RC files: ${RC_FILES[*]}"

# Helper: append a block to a RC file if a guard string is not already present
append_to_rc() {
  local rc_file="$1"
  local guard="$2"    # grep pattern — if found, skip
  local block="$3"    # text to append
  local label="$4"    # human-readable label for output

  if grep -qF "$guard" "$rc_file" 2>/dev/null; then
    skip "$label ($rc_file)"
  elif $DRY_RUN; then
    dryrun "Would append $label to $rc_file"
  else
    printf '\n%s\n' "$block" >> "$rc_file"
    ok "$label → $rc_file"
  fi
}

# ── env.sh — secrets and API keys ────────────────────────────────────────────
section "Environment Config (env.sh)"

ENV_FILE="$HOME/.config/riles-workstation/env.sh"
ENV_TEMPLATE="$REPO_DIR/skills/common/env.sh.template"

if [ -f "$ENV_FILE" ]; then
  skip "~/.config/riles-workstation/env.sh (already exists)"
elif $DRY_RUN; then
  dryrun "Would create $ENV_FILE from template"
else
  mkdir -p "$(dirname "$ENV_FILE")"
  if [ -f "$ENV_TEMPLATE" ]; then
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    log "Created $ENV_FILE from template"
  else
    touch "$ENV_FILE"
    log "Created empty $ENV_FILE (template not found at $ENV_TEMPLATE)"
  fi
  chmod 600 "$ENV_FILE"
  ok "env.sh created — edit $ENV_FILE to add your API keys"
fi

# Wire env.sh sourcing into each shell RC
for rc in "${RC_FILES[@]}"; do
  append_to_rc "$rc" \
    "riles-workstation/env.sh" \
    "# riles-workstation — API keys and environment
[ -f \"\$HOME/.config/riles-workstation/env.sh\" ] && source \"\$HOME/.config/riles-workstation/env.sh\"" \
    "env.sh source"
done

# ── PATH — ~/.local/bin ───────────────────────────────────────────────────────
section "PATH — ~/.local/bin"
for rc in "${RC_FILES[@]}"; do
  append_to_rc "$rc" \
    '.local/bin' \
    '# ~/.local/bin on PATH (zoxide, yq, bat alias, uv tools)
export PATH="$HOME/.local/bin:$PATH"' \
    "~/.local/bin PATH"
done

# ── PATH — uv tools ───────────────────────────────────────────────────────────
section "PATH — uv tools (~/.cargo/bin)"
for rc in "${RC_FILES[@]}"; do
  append_to_rc "$rc" \
    '.cargo/bin' \
    '# uv tools (aider, llm, etc.)
export PATH="$HOME/.cargo/bin:$PATH"' \
    "uv tools PATH"
done

# ── ai-env alias ─────────────────────────────────────────────────────────────
section "ai-env Alias"
VENV_DIR="$HOME/ai-env"
for rc in "${RC_FILES[@]}"; do
  append_to_rc "$rc" \
    "alias ai-env=" \
    "# Activate AI/ML Python environment
alias ai-env='source $VENV_DIR/bin/activate'" \
    "ai-env alias"
done

# ── fnm (Fast Node Manager) ───────────────────────────────────────────────────
section "fnm Shell Integration"
if command -v fnm &>/dev/null || [ -f "$HOME/.local/share/fnm/fnm" ]; then
  for rc in "${RC_FILES[@]}"; do
    append_to_rc "$rc" \
      'fnm env' \
      '# fnm — Fast Node Manager
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd 2>/dev/null)" || true' \
      "fnm env"
  done
else
  skip "fnm not installed — skipping shell integration"
fi

# ── zoxide ────────────────────────────────────────────────────────────────────
section "zoxide Shell Integration"
if command -v zoxide &>/dev/null; then
  for rc in "${RC_FILES[@]}"; do
    # Detect shell type from filename
    if [[ "$rc" == *zshrc ]]; then
      append_to_rc "$rc" \
        'zoxide init' \
        '# zoxide — smarter cd
eval "$(zoxide init zsh)"' \
        "zoxide init (zsh)"
    else
      append_to_rc "$rc" \
        'zoxide init' \
        '# zoxide — smarter cd
eval "$(zoxide init bash)"' \
        "zoxide init (bash)"
    fi
  done
else
  skip "zoxide not installed — skipping shell integration"
fi

# ── starship prompt ───────────────────────────────────────────────────────────
section "Starship Prompt"
if command -v starship &>/dev/null; then
  for rc in "${RC_FILES[@]}"; do
    if [[ "$rc" == *zshrc ]]; then
      append_to_rc "$rc" \
        'starship init' \
        '# starship prompt
eval "$(starship init zsh)"' \
        "starship init (zsh)"
    else
      append_to_rc "$rc" \
        'starship init' \
        '# starship prompt
eval "$(starship init bash)"' \
        "starship init (bash)"
    fi
  done

  # Minimal starship config if none exists
  STARSHIP_CFG="$HOME/.config/starship.toml"
  if [ ! -f "$STARSHIP_CFG" ]; then
    if $DRY_RUN; then
      dryrun "Would create minimal $STARSHIP_CFG"
    else
      mkdir -p "$(dirname "$STARSHIP_CFG")"
      cat >"$STARSHIP_CFG" <<'TOML'
# starship.toml — riles-workstation default
# Docs: https://starship.rs/config/

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"

[git_branch]
symbol = " "

[python]
symbol = " "
TOML
      ok "Minimal starship config created at $STARSHIP_CFG"
    fi
  else
    skip "starship.toml (already exists)"
  fi
else
  skip "starship not installed — skipping shell integration"
fi

echo -e "\n${BOLD}${GREEN}Dotfiles wired!${RESET}"
echo ""
echo -e "  Reload your shell or run: ${CYAN}source ~/.bashrc${RESET}"
echo -e "  Set API keys in:          ${CYAN}~/.config/riles-workstation/env.sh${RESET}"
echo ""
