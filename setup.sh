#!/usr/bin/env bash
# setup.sh — riles-workstation bootstrap
# Single entry point: installs tools and wires up skills for all agent tools.
# Safe to re-run — idempotent throughout.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
PROMPT_KEYS=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log() { echo -e "${CYAN}-->${RESET} $1"; }
ok() { echo -e "${GREEN}[done]${RESET} $1"; }
skip() { echo -e "${YELLOW}[skip]${RESET} $1"; }
warn() { echo -e "${RED}[warn]${RESET} $1"; }
section() { echo -e "\n${BOLD}${CYAN}=== $1 ===${RESET}"; }
dryrun() { echo -e "${YELLOW}[dry-run]${RESET} $1"; }

# Portable in-place sed (GNU sed vs macOS BSD sed)
sed_i() {
  local file="${*: -1}"
  sed -i.bak "$@"
  rm -f "${file}.bak"
}

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --prompt-keys) PROMPT_KEYS=true ;;
    --help)
      echo "Usage: $0 [--dry-run] [--prompt-keys]"
      echo "  --dry-run      Show what would be done without making any changes"
      echo "  --prompt-keys  Interactively set API keys in ~/.config/riles-workstation/env.sh"
      exit 0
      ;;
  esac
done

# ── API key prompting ─────────────────────────────────────────────────────────
prompt_api_keys() {
  local env_file="$HOME/.config/riles-workstation/env.sh"
  local template="$REPO_DIR/skills/common/env.sh.template"

  section "API Keys"

  if [ ! -f "$template" ]; then
    warn "env.sh.template not found — skipping"
    return
  fi

  if $DRY_RUN; then
    dryrun "Would create $env_file from template (if missing)"
    dryrun "Would prompt for each key in template"
    return
  fi

  mkdir -p "$(dirname "$env_file")"

  if [ ! -f "$env_file" ]; then
    cp "$template" "$env_file"
    log "Created $env_file from template"
  fi

  echo -e "  Press ${BOLD}Enter${RESET} to skip a key (it will be commented out in the file)."
  echo -e "  Keys with values already set are shown as ${GREEN}[exists]${RESET} and left unchanged.\n"

  while IFS= read -r line; do
    # Skip comments and blank lines — just print them for context
    if [[ "$line" =~ ^#[[:space:]] ]] || [[ "$line" =~ ^#$ ]]; then
      echo -e "  ${CYAN}${line}${RESET}"
      continue
    fi

    # Only process export lines
    if [[ "$line" =~ ^export[[:space:]]+([A-Z_]+)= ]]; then
      key="${BASH_REMATCH[1]}"

      # Read current value from env file (handles quoted and unquoted)
      current_val=""
      if grep -qE "^export[[:space:]]+${key}=" "$env_file" 2>/dev/null; then
        current_val=$(grep -E "^export[[:space:]]+${key}=" "$env_file" |
          head -1 |
          sed -E "s/^export[[:space:]]+${key}=[\"']?([^\"']*)[\"']?$/\1/")
      fi

      if [ -n "$current_val" ]; then
        echo -e "    ${GREEN}[exists]${RESET} ${BOLD}${key}${RESET}"
      else
        read -r -p "    ${key}: " input_val </dev/tty || input_val=""
        if [ -n "$input_val" ]; then
          # Escape any forward slashes in the value for sed
          escaped_val="${input_val//\//\\/}"
          sed_i "s|^#*[[:space:]]*export[[:space:]]*${key}=.*|export ${key}=\"${escaped_val}\"|" "$env_file"
          ok "${key} set"
        else
          # Comment out the line so the file documents what keys exist
          sed_i "s|^[[:space:]]*export[[:space:]]*${key}=.*|# export ${key}=\"\"|" "$env_file"
          skip "${key} (skipped — commented out)"
        fi
      fi
    fi
  done <"$template"

  echo ""
  ok "API keys written to $env_file"
}

echo -e "${BOLD}riles-workstation setup${RESET}"
echo -e "Repo:     $REPO_DIR"
echo -e "Dry run:  $DRY_RUN"
echo -e "Date:     $(date)\n"

# ── Source OS detection ───────────────────────────────────────────────────────
# shellcheck source=dev-workstation-build/lib/os.sh
source "$REPO_DIR/dev-workstation-build/lib/os.sh"
OS="$(detect_os)"
log "Detected platform: $OS"

# ── Bootstrap package manager ─────────────────────────────────────────────────
section "Package Manager"
case "$OS" in
  macos-*)
    if ! command -v brew &>/dev/null; then
      if $DRY_RUN; then
        dryrun "Would install Homebrew"
      else
        log "Installing Homebrew..."
        ensure_brew
        ok "Homebrew installed"
      fi
    else
      skip "Homebrew ($(brew --version | head -1))"
    fi
    ;;
  linux-*)
    if $DRY_RUN; then
      dryrun "Would run: apt-get update"
    else
      log "Updating apt index..."
      sudo apt-get update -qq
    fi
    ;;
esac

# ── API key prompting (optional) ──────────────────────────────────────────────
if $PROMPT_KEYS; then
  prompt_api_keys
fi

# ── Run install modules ───────────────────────────────────────────────────────
MODULES=(
  install-system.sh
  install-ai.sh
  install-mcp.sh
  install-ops.sh
  install-dotfiles.sh
)

section "Install Modules"
TOTAL_MODULES=${#MODULES[@]}
STEP=0
for module in "${MODULES[@]}"; do
  STEP=$((STEP + 1))
  module_path="$REPO_DIR/dev-workstation-build/$module"
  if [ -f "$module_path" ]; then
    echo -e "\n${BOLD}[${STEP}/${TOTAL_MODULES}]${RESET} ${CYAN}${module}${RESET}"
    if $DRY_RUN; then
      bash "$module_path" --dry-run
    else
      bash "$module_path"
    fi
  else
    echo -e "\n${BOLD}[${STEP}/${TOTAL_MODULES}]${RESET} ${CYAN}${module}${RESET}"
    skip "$module (not yet implemented)"
  fi
done

# ── Wire skills ───────────────────────────────────────────────────────────────
section "Skills"

CLAUDE_SKILLS_SRC="$REPO_DIR/skills/claude"
CLAUDE_SKILLS_DEST="$HOME/.claude/skills"

if $DRY_RUN; then
  dryrun "Would create: $CLAUDE_SKILLS_DEST"
  for skill_dir in "$CLAUDE_SKILLS_SRC"/*/; do
    skill_name="$(basename "$skill_dir")"
    dryrun "Would symlink: $CLAUDE_SKILLS_DEST/$skill_name -> $skill_dir"
  done
else
  mkdir -p "$CLAUDE_SKILLS_DEST"
  for skill_dir in "$CLAUDE_SKILLS_SRC"/*/; do
    skill_name="$(basename "$skill_dir")"
    target="$CLAUDE_SKILLS_DEST/$skill_name"
    if [ -L "$target" ]; then
      skip "Claude skill: $skill_name (symlink exists)"
    elif [ -e "$target" ]; then
      echo -e "${RED}[conflict]${RESET} $target exists and is not a symlink — skipping"
    else
      ln -s "$skill_dir" "$target"
      ok "Claude skill: $skill_name"
    fi
  done
fi

# ── Wire Cursor rules ─────────────────────────────────────────────────────────
CURSOR_RULES_SRC="$REPO_DIR/skills/common/workflows"
CURSOR_RULES_DEST="$REPO_DIR/skills/cursor/rules"

if $DRY_RUN; then
  for workflow in "$CURSOR_RULES_SRC"/*.md; do
    name="$(basename "$workflow")"
    dryrun "Would symlink: $CURSOR_RULES_DEST/$name -> $workflow"
  done
else
  mkdir -p "$CURSOR_RULES_DEST"
  for workflow in "$CURSOR_RULES_SRC"/*.md; do
    name="$(basename "$workflow")"
    target="$CURSOR_RULES_DEST/$name"
    if [ -L "$target" ]; then
      skip "Cursor rule: $name (symlink exists)"
    else
      ln -s "$workflow" "$target"
      ok "Cursor rule: $name"
    fi
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}Setup complete!${RESET}"
if $DRY_RUN; then
  echo -e "${YELLOW}Dry run — no changes were made.${RESET}"
fi
echo ""
if ! $PROMPT_KEYS; then
  echo -e "  Next: run ${CYAN}./setup.sh --prompt-keys${RESET} to set API keys interactively"
  echo -e "        or edit ${CYAN}~/.config/riles-workstation/env.sh${RESET} directly"
fi
echo ""
