#!/usr/bin/env bash
# setup.sh — workstation bootstrap
# Single entry point: installs tools and wires up skills for all agent tools.
# Safe to re-run — idempotent throughout.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
PROMPT_KEYS=false
INTERACTIVE=true

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
    --select) INTERACTIVE=true ;;
    --no-select) INTERACTIVE=false ;;
    --help)
      echo "Usage: $0 [--dry-run] [--prompt-keys] [--no-select]"
      echo "  --dry-run      Show what would be done without making any changes"
      echo "  --prompt-keys  Interactively set API keys in ~/.config/workstation/env.sh"
      echo "  --no-select    Skip the component selection menu and install everything"
      exit 0
      ;;
  esac
done

# ── API key prompting ─────────────────────────────────────────────────────────
prompt_api_keys() {
  local env_file="$HOME/.config/workstation/env.sh"
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

# ── Selection menu ────────────────────────────────────────────────────────────
# Each entry maps 1:1: MENU_LABELS[i] <-> MENU_KEYS[i] <-> MENU_SELECTED[i]
MENU_LABELS=(
  "System tools       (ripgrep, bat, fzf, eza, zoxide, jq, fnm, tmux)"
  "AI tools           (uv, Ollama, Aider, llm CLI)"
  "AI Python env      (~/ai-env — uv sync, ML packages; opt-in)"
  "MCP servers        (Claude Code CLI, filesystem/GitHub/Playwright MCP)"
  "Ops tools          (Docker, Open WebUI, lazygit, k9s, starship, gh, glab, terraform, ansible, kubectl, helm)"
  "Dotfiles           (shell RC, env.sh, starship config)"
  "Claude skills      (symlink skills to ~/.claude/skills)"
  "Cursor rules       (symlink workflows to skills/cursor/rules)"
  "API keys           (prompt for keys interactively)"
  "CLI auth           (wire gh / glab / huggingface-cli via env.sh tokens)"
)
MENU_KEYS=(
  "install-system.sh"
  "install-ai.sh"
  "_ai_env"
  "install-mcp.sh"
  "install-ops.sh"
  "install-dotfiles.sh"
  "_claude_skills"
  "_cursor_rules"
  "_api_keys"
  "_cli_auth"
)
# Default: none selected
MENU_SELECTED=(0 0 0 0 0 0 0 0 0 0)

show_menu() {
  while true; do
    echo -e "\n${BOLD}${CYAN}=== Select components ===${RESET}"
    echo -e "  ${YELLOW}Note: package manager bootstrap always runs.${RESET}\n"
    local i
    for i in "${!MENU_LABELS[@]}"; do
      local num=$((i + 1))
      local mark
      if [ "${MENU_SELECTED[$i]}" -eq 1 ]; then
        mark="${GREEN}[x]${RESET}"
      else
        mark="[ ]"
      fi
      echo -e "  ${BOLD}${num}.${RESET} ${mark} ${MENU_LABELS[$i]}"
    done
    echo -e "\n  Toggle: enter number(s) separated by spaces (e.g. ${CYAN}2 4${RESET})"
    echo -e "  ${CYAN}a${RESET} = select all   ${CYAN}n${RESET} = select none   ${CYAN}Enter${RESET} = confirm   ${CYAN}q${RESET} = exit\n"
    local input
    read -r -p "> " input </dev/tty || input=""

    case "$input" in
      "")
        break
        ;;
      q | Q)
        echo -e "\n${YELLOW}Exiting.${RESET}"
        exit 0
        ;;
      a | A)
        MENU_SELECTED=(1 1 1 1 1 1 1 1 1 1)
        ;;
      n | N)
        MENU_SELECTED=(0 0 0 0 0 0 0 0 0 0)
        ;;
      *)
        local token idx
        for token in $input; do
          if [[ "$token" =~ ^[0-9]+$ ]]; then
            idx=$((token - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#MENU_SELECTED[@]}" ]; then
              if [ "${MENU_SELECTED[$idx]}" -eq 1 ]; then
                MENU_SELECTED[$idx]=0
              else
                MENU_SELECTED[$idx]=1
              fi
            else
              warn "Invalid selection: $token"
            fi
          fi
        done
        ;;
    esac
  done
}

# Returns 1 if the given key was deselected in the menu, 0 otherwise
is_selected() {
  local key="$1"
  local i
  for i in "${!MENU_KEYS[@]}"; do
    if [ "${MENU_KEYS[$i]}" = "$key" ]; then
      return $((1 - MENU_SELECTED[$i]))
    fi
  done
  return 0
}

echo -e "${BOLD}workstation setup${RESET}"
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

# ── Selection menu (optional) ─────────────────────────────────────────────────
if $INTERACTIVE; then
  # Pre-tick API keys if --prompt-keys was also passed
  if $PROMPT_KEYS; then
    MENU_SELECTED[8]=1
  fi
  show_menu
  # Sync PROMPT_KEYS with whatever the user selected in the menu
  if [ "${MENU_SELECTED[8]}" -eq 1 ]; then
    PROMPT_KEYS=true
  else
    PROMPT_KEYS=false
  fi
fi

# ── API key prompting (optional) ──────────────────────────────────────────────
if $PROMPT_KEYS; then
  prompt_api_keys
fi

# ── Run install modules ───────────────────────────────────────────────────────
ALL_MODULES=(
  install-system.sh
  install-ai.sh
  install-mcp.sh
  install-ops.sh
  install-dotfiles.sh
)

# Filter down to selected modules
MODULES=()
for m in "${ALL_MODULES[@]}"; do
  if is_selected "$m"; then
    MODULES+=("$m")
  fi
done

if [ "${#MODULES[@]}" -gt 0 ]; then
  section "Install Modules"
  TOTAL_MODULES=${#MODULES[@]}
  STEP=0
  for module in "${MODULES[@]}"; do
    STEP=$((STEP + 1))
    module_path="$REPO_DIR/dev-workstation-build/$module"
    if [ -f "$module_path" ]; then
      echo -e "\n${BOLD}[${STEP}/${TOTAL_MODULES}]${RESET} ${CYAN}${module}${RESET}"
      MODULE_ARGS=()
      if [[ "$module" == "install-ai.sh" ]] && is_selected "_ai_env"; then
        MODULE_ARGS+=(--with-venv)
      fi
      if $DRY_RUN; then
        bash "$module_path" --dry-run ${MODULE_ARGS[@]+"${MODULE_ARGS[@]}"}
      else
        bash "$module_path" ${MODULE_ARGS[@]+"${MODULE_ARGS[@]}"}
      fi
    else
      echo -e "\n${BOLD}[${STEP}/${TOTAL_MODULES}]${RESET} ${CYAN}${module}${RESET}"
      skip "$module (not yet implemented)"
    fi
  done
fi

# ── CLI auth wiring ───────────────────────────────────────────────────────────
if is_selected "_cli_auth"; then
  section "CLI Auth"

  ENV_FILE="$HOME/.config/workstation/env.sh"

  # Re-source env.sh to pick up any token updates written by prompt_api_keys or
  # applied externally since the shell session started.
  if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE" 2>/dev/null || true
    log "Sourced $ENV_FILE"
  else
    warn "$ENV_FILE not found — run './setup.sh --prompt-keys' to create it"
  fi

  # gh (GitHub CLI)
  if command -v gh &>/dev/null; then
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      if gh auth status &>/dev/null 2>&1; then
        skip "gh auth (already authenticated)"
      else
        if $DRY_RUN; then
          dryrun "Would authenticate gh via GITHUB_TOKEN"
        else
          echo "$GITHUB_TOKEN" | gh auth login --with-token
          ok "gh authenticated via GITHUB_TOKEN"
        fi
      fi
    else
      skip "gh auth (GITHUB_TOKEN not set)"
    fi
  fi

  # glab (GitLab CLI)
  if command -v glab &>/dev/null; then
    if [ -n "${GITLAB_TOKEN:-}" ]; then
      if glab auth status &>/dev/null 2>&1; then
        skip "glab auth (already authenticated)"
      else
        if $DRY_RUN; then
          dryrun "Would authenticate glab via GITLAB_TOKEN"
        else
          echo "$GITLAB_TOKEN" | glab auth login --stdin
          ok "glab authenticated via GITLAB_TOKEN"
        fi
      fi
    else
      skip "glab auth (GITLAB_TOKEN not set)"
    fi
  fi

  # huggingface-cli (Hugging Face Hub)
  if command -v huggingface-cli &>/dev/null; then
    if [ -n "${HF_TOKEN:-}" ]; then
      if huggingface-cli whoami &>/dev/null 2>&1; then
        skip "huggingface-cli auth (already authenticated)"
      else
        if $DRY_RUN; then
          dryrun "Would authenticate huggingface-cli via HF_TOKEN"
        else
          huggingface-cli login --token "$HF_TOKEN"
          ok "huggingface-cli authenticated via HF_TOKEN"
        fi
      fi
    else
      skip "huggingface-cli auth (HF_TOKEN not set)"
    fi
  fi

fi # is_selected "_cli_auth"

# ── Wire skills ───────────────────────────────────────────────────────────────
if is_selected "_claude_skills"; then
  section "Claude Skills"

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
fi

# ── Wire Cursor rules ─────────────────────────────────────────────────────────
if is_selected "_cursor_rules"; then
  section "Cursor Rules"

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
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}Setup complete!${RESET}"
if $DRY_RUN; then
  echo -e "${YELLOW}Dry run — no changes were made.${RESET}"
fi
echo ""
if ! $PROMPT_KEYS; then
  echo -e "  Next: run ${CYAN}./setup.sh --prompt-keys${RESET} to set API keys interactively"
  echo -e "        or edit ${CYAN}~/.config/workstation/env.sh${RESET} directly"
fi
if ! $INTERACTIVE; then
  echo -e "  Tip:  re-run without ${CYAN}--no-select${RESET} to use the component selection menu"
fi
echo ""
