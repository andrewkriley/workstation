#!/usr/bin/env bash
# install-mcp.sh — Claude Code CLI + MCP servers
# Installs: Claude Code CLI, filesystem, GitHub, Playwright, Brave Search MCP servers
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

echo -e "${BOLD}MCP Servers — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── Node / npm prerequisite ───────────────────────────────────────────────────
section "Node.js"
if command -v node &>/dev/null && command -v npm &>/dev/null; then
  skip "node ($(node --version))  npm ($(npm --version))"
else
  echo -e "  Node.js + npm are required for Claude Code CLI and MCP servers."
  if [[ "$OS" == macos-* ]]; then
    if command -v fnm &>/dev/null; then
      if $DRY_RUN; then
        dryrun "Would run: fnm install --lts && fnm use lts-latest"
      else
        log "Installing Node LTS via fnm..."
        eval "$(fnm env)"
        fnm install --lts
        fnm use lts-latest
        eval "$(fnm env)"
        ok "Node LTS installed"
      fi
    else
      echo "  Install fnm first: run install-system.sh" >&2
      exit 1
    fi
  else
    # Linux: fnm may need to be sourced from shell init
    if $DRY_RUN; then
      dryrun "Would source fnm env and install Node LTS"
    else
      # Try to activate fnm if installed
      export PATH="$HOME/.local/share/fnm:$PATH"
      if command -v fnm &>/dev/null; then
        eval "$(fnm env)"
        fnm install --lts 2>/dev/null || true
        fnm use lts-latest 2>/dev/null || true
      else
        echo "  fnm not found — install Node via install-system.sh first" >&2
        exit 1
      fi
    fi
  fi
fi

# ── Claude Code CLI ───────────────────────────────────────────────────────────
section "Claude Code CLI"
if command -v claude &>/dev/null; then
  skip "claude ($(claude --version 2>/dev/null | head -1))"
elif $DRY_RUN; then
  dryrun "Would run: npm install -g @anthropic-ai/claude-code"
else
  log "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code CLI installed ($(claude --version 2>/dev/null | head -1))"
fi

# ── MCP server helper ─────────────────────────────────────────────────────────
# Check registration by reading config directly — avoids starting any server
MCP_CFG="$HOME/.claude/settings.json"

mcp_registered() {
  local name="$1"
  [ -f "$MCP_CFG" ] && grep -q "\"$name\"" "$MCP_CFG"
}

section "MCP Servers"
echo -e "  ${YELLOW}Note:${RESET} first-time registration downloads npm packages via npx — this may take a minute."
echo ""

# Collect registration errors to surface at the end
MCP_ERRORS=()

add_mcp_tracked() {
  local name="$1"
  shift
  if mcp_registered "$name"; then
    skip "MCP: $name (already registered)"
  elif $DRY_RUN; then
    dryrun "Would run: claude mcp add $name --scope user $*"
  else
    log "Registering MCP server: $name"
    if claude mcp add "$name" --scope user "$@" 2>/tmp/mcp_err_"$name"; then
      ok "MCP: $name registered"
    else
      MCP_ERRORS+=("$name: $(cat /tmp/mcp_err_"$name" 2>/dev/null | head -1)")
      echo -e "${YELLOW}[warn]${RESET} MCP: $name — registration failed (see summary below)"
    fi
  fi
}

# filesystem — access to local files
add_mcp_tracked filesystem \
  -- npx -y @modelcontextprotocol/server-filesystem \
  "$HOME"

# github — GitHub API integration (requires GITHUB_TOKEN in env)
add_mcp_tracked github \
  -- npx -y @modelcontextprotocol/server-github

# playwright — browser automation for Claude
add_mcp_tracked playwright \
  -- npx -y @playwright/mcp@latest

# brave-search — web search (requires BRAVE_API_KEY in env)
add_mcp_tracked brave-search \
  -- npx -y @modelcontextprotocol/server-brave-search

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [ ${#MCP_ERRORS[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${YELLOW}Registration errors:${RESET}"
  for err in "${MCP_ERRORS[@]}"; do
    echo -e "    ${YELLOW}✘${RESET} $err"
  done
  echo ""
  echo -e "  ${CYAN}Tip:${RESET} Set required env vars in ~/.config/workstation/env.sh:"
  echo -e "    • ${CYAN}GITHUB_TOKEN${RESET}   — GitHub fine-grained PAT"
  echo -e "    • ${CYAN}BRAVE_API_KEY${RESET}  — Brave Search API key"
  echo -e "  Then re-run: ${CYAN}./install-mcp.sh${RESET}"
else
  echo ""
  echo -e "${BOLD}${GREEN}All MCP servers registered successfully.${RESET}"
  echo ""
  echo -e "  Required env vars in ~/.config/workstation/env.sh:"
  echo -e "    • ${CYAN}GITHUB_TOKEN${RESET}   — GitHub fine-grained PAT"
  echo -e "    • ${CYAN}BRAVE_API_KEY${RESET}  — Brave Search API key"
fi
echo ""
