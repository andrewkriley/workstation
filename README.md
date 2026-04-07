# workstation

A turnkey, idempotent setup for an AI-augmented development environment across Ubuntu and macOS.

**Focus areas:** agentic AI · AIOps · developer productivity · local LLM inference · MCP-based tool integration

## Quick start

```bash
# Full install — bootstraps everything, safe to re-run
./setup.sh

# Preview without making any changes
./setup.sh --dry-run

# Audit what's currently installed
./dev-workstation-build/audit.sh
```

## Structure

```
.
├── setup.sh                        # Single entry point — bootstraps + orchestrates everything
├── skills/
│   ├── common/                     # Source of truth: PROFILE.md, env template, portable prompt workflows
│   ├── claude/                     # Claude Code skills (SKILL.md format)
│   ├── cursor/                     # Cursor rules — symlinked from common/ by setup.sh
│   └── codex/                      # GitHub Copilot format — deferred
└── dev-workstation-build/
    ├── install.sh                  # Orchestrator — calls modules in dependency order
    ├── pyproject.toml              # AI/ML Python packages (uv-managed)
    ├── uv.lock                     # Platform-conditional lockfile
    ├── lib/os.sh                   # detect_os() → macos-arm | macos-intel | linux-x86 | linux-arm
    ├── install-system.sh           # apt/brew: ripgrep, bat, fzf, eza, zoxide, jq, yq, fnm, tmux
    ├── install-ai.sh               # uv, ~/ai-env, Ollama (native), Aider, llm CLI, faster-whisper
    ├── install-mcp.sh              # Claude Code CLI, filesystem/GitHub/Playwright/Brave Search MCPs
    ├── install-ops.sh              # Docker + Compose, Open WebUI, lazygit, k9s, starship
    ├── install-dotfiles.sh         # Shell RC wiring, env.sh from template
    ├── audit.sh                    # Read-only environment inventory
    └── tests/                      # bats unit tests
```

`setup.sh` calls modules in dependency order. Each module is independently runnable and supports `--dry-run`.

## Skills

Agent prompt skills are structured in three layers:

- **`skills/common/`** — tool-agnostic workflow bodies (single source of truth)
- **`skills/claude/`** — Claude Code wrappers (`SKILL.md` format with frontmatter)
- **`skills/cursor/rules/`** — symlinks into `common/`, wired by `setup.sh`

Skills available: `grill-me`, `repo-status`, `summarise-session`, `keep-current`, `linkedin-post`, `security-audit`, `splunk-dashboard-gen`, `webex-update`, `skills`

## Platform support

Ubuntu (x86 + ARM) and macOS (Intel + Apple Silicon). All OS branching is centralised in `lib/os.sh` — modules never branch on OS themselves.

## API keys

Generated at `~/.config/workstation/env.sh` from `skills/common/env.sh.template` on first run. Fill in placeholders — file is never committed.

## Testing

```bash
cd dev-workstation-build && bats tests/        # all unit tests
bats tests/test_os_detect.bats                 # single file
shellcheck dev-workstation-build/**/*.sh       # lint
```

CI runs `shellcheck`, `shfmt`, and `bats` on every push.
