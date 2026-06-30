#!/usr/bin/env bash
# install-dotfiles.sh — Shell RC wiring and environment configuration
# Wires: env.sh sourcing, ai-env alias, tmux config + auto-start, zoxide init,
#        fnm env, ~/.local/bin on PATH, uv tools on PATH, shell prompt
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

echo -e "${BOLD}Dotfiles — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── Detect shell RC files ─────────────────────────────────────────────────────
RC_FILES=()
[ -f "$HOME/.bashrc" ] && RC_FILES+=("$HOME/.bashrc")
[ -f "$HOME/.zshrc" ] && RC_FILES+=("$HOME/.zshrc")
[ -f "$HOME/.bash_profile" ] && [[ "$OS" == macos-* ]] && RC_FILES+=("$HOME/.bash_profile")

if [ ${#RC_FILES[@]} -eq 0 ]; then
  log "No shell RC files found — creating ~/.bashrc"
  if ! $DRY_RUN; then
    touch "$HOME/.bashrc"
    RC_FILES+=("$HOME/.bashrc")
  fi
fi

log "Shell RC files: ${RC_FILES[*]}"

# Helper: append a block to a RC file if a guard string is not already present.
# Add-once semantics — never rewrites an existing match. Use this for blocks a
# user may have hand-rolled their own version of (e.g. the shell prompt), where
# clobbering would be unwelcome.
append_to_rc() {
  local rc_file="$1"
  local guard="$2" # grep pattern — if found, skip
  local block="$3" # text to append
  local label="$4" # human-readable label for output

  if grep -qF "$guard" "$rc_file" 2>/dev/null; then
    skip "$label ($rc_file)"
  elif $DRY_RUN; then
    dryrun "Would append $label to $rc_file"
  else
    printf '\n%s\n' "$block" >>"$rc_file"
    ok "$label → $rc_file"
  fi
}

# Helper: keep a workstation-managed block in sync with desired content.
# Blocks we own are wrapped in sentinel markers keyed by an id, so edits to the
# block actually propagate on re-run (the original append_to_rc skips forever
# once its guard matches, so changed content never lands on an existing machine):
#   - markers present, content drifted → replaced in place      ("updated")
#   - markers present, content identical → left alone            ("skip")
#   - markers absent, legacy guard hit → legacy paragraph removed,
#     managed block appended (one-time migration)                ("migrated")
#   - neither present → managed block appended                   ("added")
# Managed blocks have no internal blank lines and are blank-separated from their
# neighbours, so a legacy (un-delimited) block is exactly the blank-line paragraph
# containing its guard — which is what the migration removes.
sync_block_to_rc() {
  local rc_file="$1"
  local key="$2"   # stable id for the sentinel markers
  local guard="$3" # grep -F pattern identifying a pre-sentinel (legacy) block
  local block="$4" # desired block body (without sentinels)
  local label="$5"

  local begin="# >>> workstation:${key} >>>"
  local end="# <<< workstation:${key} <<<"
  local desired
  desired="$(printf '%s\n%s\n%s' "$begin" "$block" "$end")"

  [ -e "$rc_file" ] || touch "$rc_file"

  if grep -qF "$begin" "$rc_file" 2>/dev/null; then
    # Managed block exists — replace only if it has drifted from desired.
    local current
    current="$(awk -v b="$begin" -v e="$end" '
      $0==b {f=1} f {print} $0==e {f=0}' "$rc_file")"
    if [ "$current" = "$desired" ]; then
      skip "$label ($rc_file)"
    elif $DRY_RUN; then
      dryrun "Would update $label in $rc_file"
    else
      local tmp
      tmp="$(mktemp)"
      # $desired is multi-line — pass via the environment (awk -v mangles newlines).
      DESIRED="$desired" awk -v b="$begin" -v e="$end" '
        $0==b {print ENVIRON["DESIRED"]; inblk=1; next}
        inblk && $0==e {inblk=0; next}
        inblk {next}
        {print}' "$rc_file" >"$tmp"
      cat "$tmp" >"$rc_file"
      rm -f "$tmp"
      ok "$label updated → $rc_file"
    fi
    return
  fi

  # No managed block yet.
  local legacy=false
  grep -qF "$guard" "$rc_file" 2>/dev/null && legacy=true

  if $DRY_RUN; then
    if $legacy; then
      dryrun "Would migrate $label to a managed block in $rc_file"
    else
      dryrun "Would append $label to $rc_file"
    fi
    return
  fi

  if $legacy; then
    # Drop the blank-line paragraph containing the guard (plus its trailing blank
    # separator), leaving every other line byte-identical, then append the managed
    # block fresh.
    local tmp
    tmp="$(mktemp)"
    awk -v g="$guard" '
      function flush(  i) {
        if (drop) { drop=0; n=0; dropped=1; return }
        for (i=0;i<n;i++) print para[i]; n=0; dropped=0
      }
      /^[[:space:]]*$/ { flush(); if (dropped) { dropped=0; next } print; next }
      { para[n++]=$0; if (index($0,g)) drop=1 }
      END { flush() }' "$rc_file" >"$tmp"
    cat "$tmp" >"$rc_file"
    rm -f "$tmp"
    printf '\n%s\n' "$desired" >>"$rc_file"
    ok "$label migrated → $rc_file"
  else
    printf '\n%s\n' "$desired" >>"$rc_file"
    ok "$label → $rc_file"
  fi
}

# Test hook: source the script with WORKSTATION_LIB_ONLY=1 to load the helpers
# (append_to_rc / sync_block_to_rc) without running the installer. No effect on a
# normal run, where the variable is unset.
[ -n "${WORKSTATION_LIB_ONLY:-}" ] && return 0 2>/dev/null || true

# ── env.sh — secrets and API keys ────────────────────────────────────────────
section "Environment Config (env.sh)"

ENV_FILE="$HOME/.config/workstation/env.sh"
ENV_TEMPLATE="$REPO_DIR/skills/common/env.sh.template"

if [ -f "$ENV_FILE" ]; then
  skip "$HOME/.config/workstation/env.sh (already exists)"
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
  sync_block_to_rc "$rc" \
    "env-sh" \
    "workstation/env.sh" \
    "# workstation — API keys and environment
[ -f \"\$HOME/.config/workstation/env.sh\" ] && source \"\$HOME/.config/workstation/env.sh\"" \
    "env.sh source"
done

# ── PATH — ~/.local/bin ───────────────────────────────────────────────────────
section "PATH — ~/.local/bin"
for rc in "${RC_FILES[@]}"; do
  sync_block_to_rc "$rc" \
    "path-local-bin" \
    '.local/bin' \
    '# ~/.local/bin on PATH (zoxide, yq, bat alias, uv tools)
export PATH="$HOME/.local/bin:$PATH"' \
    "$HOME/.local/bin PATH"
done

# ── PATH — uv tools ───────────────────────────────────────────────────────────
section "PATH — uv tools (~/.cargo/bin)"
for rc in "${RC_FILES[@]}"; do
  sync_block_to_rc "$rc" \
    "path-uv" \
    '.cargo/bin' \
    '# uv tools (aider, llm, etc.)
export PATH="$HOME/.cargo/bin:$PATH"' \
    "uv tools PATH"
done

# ── ai-env alias ─────────────────────────────────────────────────────────────
section "ai-env Alias"
VENV_DIR="$HOME/ai-env"
for rc in "${RC_FILES[@]}"; do
  sync_block_to_rc "$rc" \
    "ai-env-alias" \
    "alias ai-env=" \
    "# Activate AI/ML Python environment
alias ai-env='source $VENV_DIR/bin/activate'" \
    "ai-env alias"
done

# ── fnm (Fast Node Manager) ───────────────────────────────────────────────────
section "fnm Shell Integration"
if command -v fnm &>/dev/null || [ -f "$HOME/.local/share/fnm/fnm" ]; then
  for rc in "${RC_FILES[@]}"; do
    sync_block_to_rc "$rc" \
      "fnm" \
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
      sync_block_to_rc "$rc" \
        "zoxide" \
        'zoxide init' \
        '# zoxide — smarter cd
eval "$(zoxide init zsh)"' \
        "zoxide init (zsh)"
    else
      sync_block_to_rc "$rc" \
        "zoxide" \
        'zoxide init' \
        '# zoxide — smarter cd
eval "$(zoxide init bash)"' \
        "zoxide init (bash)"
    fi
  done
else
  skip "zoxide not installed — skipping shell integration"
fi

# ── Terminal colours (portable, palette-following) ────────────────────────────
# These follow the terminal's own 16-colour ANSI palette rather than hardcoding
# shades, so they adopt whatever scheme the host uses — the Cobalt2 profile on
# macOS, or the user's emulator theme on Linux.
section "Terminal Colours"
for rc in "${RC_FILES[@]}"; do
  sync_block_to_rc "$rc" \
    "terminal-colours" \
    'BAT_THEME' \
    '# Terminal colours (workstation) — follow the terminal'"'"'s ANSI palette
export CLICOLOR=1                  # BSD ls colour (macOS)
export BAT_THEME=ansi              # bat syntax highlight uses the 16-colour palette
command -v dircolors &>/dev/null && eval "$(dircolors -b 2>/dev/null)" || true' \
    "terminal colours"
done

# ── Shell prompt (workstation) ────────────────────────────────────────────────
# username (grey 245) · directory (Cobalt2 amber 220) · git branch (Cobalt2 cyan
# 123), then the prompt char ($) in the terminal's default foreground — white on
# the Cobalt2 profile. Colour indices are fixed 256-colour values so both hosts
# render the prompt identically regardless of their palette. Guarded on
# parse_git_branch, so a host that already defines it (e.g. a hand-rolled block)
# is left untouched.
section "Shell Prompt"

PROMPT_ZSH=$(
  cat <<'EOF'
# Prompt (workstation) — user · dir · git branch
parse_git_branch() { git branch 2>/dev/null | sed -n -e 's/^\* \(.*\)/[\1]/p'; }
COLOR_DEF=$'%f'
COLOR_USR=$'%F{245}'
COLOR_DIR=$'%F{220}'
COLOR_GIT=$'%F{123}'
setopt PROMPT_SUBST
PROMPT='${COLOR_USR}%n ${COLOR_DIR}%~ ${COLOR_GIT}$(parse_git_branch)${COLOR_DEF} $ '
EOF
)

PROMPT_BASH=$(
  cat <<'EOF'
# Prompt (workstation) — user · dir · git branch
parse_git_branch() { git branch 2>/dev/null | sed -n -e 's/^\* \(.*\)/[\1]/p'; }
PS1='\[\e[38;5;245m\]\u \[\e[38;5;220m\]\w \[\e[38;5;123m\]$(parse_git_branch)\[\e[0m\] $ '
EOF
)

for rc in "${RC_FILES[@]}"; do
  if [[ "$rc" == *zshrc ]]; then
    append_to_rc "$rc" 'parse_git_branch' "$PROMPT_ZSH" "shell prompt (zsh)"
  else
    append_to_rc "$rc" 'parse_git_branch' "$PROMPT_BASH" "shell prompt (bash)"
  fi
done

# ── Apple Terminal profile (macOS only) ───────────────────────────────────────
# Imports the Cobalt2 colour profile (dark-blue background, amber accents) and
# sets it as the default + startup profile, so new Terminal windows on any Mac
# match. No effect on Linux (no Apple Terminal).
if [[ "$OS" == macos-* ]]; then
  section "Apple Terminal Profile"
  TERM_PROFILE="$SCRIPT_DIR/assets/Cobalt2.terminal"
  # `defaults read` prints the profile name unquoted, as a dict key
  # (`    Cobalt2 =     {`) — not a quoted `"Cobalt2"` — so match the key line.
  cobalt2_profile_present() {
    defaults read com.apple.Terminal "Window Settings" 2>/dev/null |
      grep -qE '^[[:space:]]*Cobalt2[[:space:]]*='
  }
  if [ ! -f "$TERM_PROFILE" ]; then
    skip "Cobalt2.terminal not found at $TERM_PROFILE"
  elif cobalt2_profile_present; then
    skip "Apple Terminal 'Cobalt2' profile (already imported)"
  elif $DRY_RUN; then
    dryrun "Would import $TERM_PROFILE and set it as default + startup profile"
  else
    open "$TERM_PROFILE"
    # Give Terminal a moment to register the imported profile before we point at it
    for _ in 1 2 3 4 5; do
      cobalt2_profile_present && break
      sleep 1
    done
    defaults write com.apple.Terminal "Default Window Settings" -string "Cobalt2"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Cobalt2"
    ok "Apple Terminal 'Cobalt2' profile imported and set as default + startup"
    log "Restart Terminal (or open a new window) to see the Cobalt2 colours"
  fi
fi

# ── tmux — auto-start + config ────────────────────────────────────────────────
section "tmux"

# Auto-start tmux for interactive standalone terminals. Skips when already inside
# tmux, non-interactive, or in an IDE/embedded terminal (vscode/kiro/cursor/
# Antigravity/JetBrains) whose shell integration tmux would break.
# Reprint the login banner/MOTD inside the new tmux session — tmux switches the
# terminal's screen buffer on attach, which wipes the SSH pre-auth banner
# (/etc/issue.net) and MOTD. Single-quoted so $f/$SHELL expand when tmux runs it,
# not when the RC is sourced. Inside tmux $TMUX is set, so the exec'd login shell
# won't recurse into this block.
TMUX_AUTOSTART='if command -v tmux &>/dev/null && [[ $- == *i* ]] && [[ -z "${TMUX:-}" ]]; then
  case "${TERM_PROGRAM:-}" in
    vscode | kiro | cursor | Cursor | Antigravity) ;;
    *)
      [[ -z "${TERMINAL_EMULATOR:-}" ]] && exec tmux new-session '\''for f in /etc/issue.net /run/motd.dynamic /etc/motd; do [ -s "$f" ] && cat "$f"; done; exec "${SHELL:-/bin/bash}" -l'\''
      ;;
  esac
fi'
for rc in "${RC_FILES[@]}"; do
  sync_block_to_rc "$rc" \
    "tmux-autostart" \
    'Auto-start tmux (workstation)' \
    "$TMUX_AUTOSTART" \
    "tmux auto-start"
done

# Minimal tmux config if none exists
TMUX_CFG="$HOME/.tmux.conf"
if [ -f "$TMUX_CFG" ]; then
  skip "$TMUX_CFG (already exists)"
elif $DRY_RUN; then
  dryrun "Would create $TMUX_CFG"
else
  cat >"$TMUX_CFG" <<'CONF'
# ~/.tmux.conf — workstation default
# Managed by dev-workstation-build/install-dotfiles.sh. Docs: https://github.com/tmux/tmux/wiki

# ── General ───────────────────────────────────────────────────────────────────
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"      # truecolor passthrough
set -g mouse on
set -g history-limit 10000
set -sg escape-time 10
set -g focus-events on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
setw -g mode-keys vi

# ── Reload ────────────────────────────────────────────────────────────────────
unbind r
bind r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"

# ── Splits / windows open in the current path ─────────────────────────────────
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# ── Status bar (replaces starship's at-a-glance info) ─────────────────────────
# Colours are explicit hex from the Cobalt2 palette rather than named ANSI
# colours, so the bar renders identically on every host regardless of the
# terminal emulator's own colour scheme. bg=default inherits the terminal
# background (the dark-blue Cobalt2 profile on macOS; see assets/).
set -g status on
set -g status-interval 5
set -g status-justify left
set -g status-position bottom
set -g status-style "bg=default,fg=#BFBFBF"          # inherit bg; dim-white text

set -g status-left-length 30
set -g status-left "#[fg=#FFC600,bold] #S #[default]"   # session — Cobalt2 amber

# Right side: git branch · path · host · time
set -g status-right-length 120
set -g status-right "#[fg=#3AD900]#(cd '#{pane_current_path}' && git rev-parse --abbrev-ref HEAD 2>/dev/null) #[fg=#80FCFF]#{b:pane_current_path} #[fg=#FB94FF]#H #[fg=#BFBFBF]%H:%M "

setw -g window-status-current-style "fg=#3AD900,bold"   # active window — Cobalt2 green
setw -g window-status-current-format " #I:#W "
setw -g window-status-format " #I:#W "
CONF
  ok "Minimal tmux config created at $TMUX_CFG"
fi

echo -e "\n${BOLD}${GREEN}Dotfiles wired!${RESET}"
echo ""
if [[ "$OS" == macos-* ]]; then
  echo -e "  Reload your shell or run: ${CYAN}source ~/.zshrc${RESET}"
else
  echo -e "  Reload your shell or run: ${CYAN}source ~/.bashrc${RESET}"
fi
echo -e "  Set API keys in:          ${CYAN}~/.config/workstation/env.sh${RESET}"
echo ""
