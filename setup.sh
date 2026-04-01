#!/usr/bin/env bash
# setup.sh — riles-workstation bootstrap
# Single entry point: installs tools and wires up skills for all agent tools.
# Safe to re-run — idempotent throughout.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

RED='\033[0;31m'
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
      echo "  --dry-run   Show what would be done without making any changes"
      exit 0
      ;;
  esac
done

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

# ── Run install modules ───────────────────────────────────────────────────────
MODULES=(
  install-system.sh
  install-ai.sh
  install-mcp.sh
  install-ops.sh
  install-dotfiles.sh
)

section "Install Modules"
for module in "${MODULES[@]}"; do
  module_path="$REPO_DIR/dev-workstation-build/$module"
  if [ -f "$module_path" ]; then
    log "Running $module..."
    if $DRY_RUN; then
      bash "$module_path" --dry-run
    else
      bash "$module_path"
    fi
  else
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
echo -e "  Next: set API keys in ${CYAN}~/.config/riles-workstation/env.sh${RESET}"
echo ""
