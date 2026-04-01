# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Andrew Riley's personal workstation scaffold — a turnkey, idempotent setup for an AI-augmented development environment across Ubuntu and macOS. Focus areas: agentic AI, AIOps, developer productivity, local LLM inference, and MCP-based tool integration.

## Agreed Architecture

### Repository Structure

```
.
├── setup.sh                        # Single entry point — bootstraps + orchestrates everything
├── skills/
│   ├── common/                     # Single source of truth: PROFILE.md, DESIGN.md, env template, portable prompt workflows
│   ├── claude/                     # Claude Code SKILL.md format (9 skills from andrewkriley/claude + common wrappers)
│   ├── cursor/                     # Cursor rules — symlinks into common/ via setup.sh
│   └── codex/                      # GitHub Copilot format — deferred, symlinks into common/
└── dev-workstation-build/
    ├── install.sh                  # Orchestrator — calls modules in dependency order
    ├── pyproject.toml              # AI/ML Python package list (replaces imperative install loop)
    ├── uv.lock                     # Platform-conditional lockfile
    ├── lib/
    │   └── os.sh                   # detect_os() → macos-arm | macos-intel | linux-x86 | linux-arm
    ├── install-system.sh           # apt/brew: ripgrep, bat, fzf, eza, zoxide, jq, yq, fnm, tmux
    ├── install-ai.sh               # uv, ~/ai-env via uv sync, Ollama (native), Aider, llm CLI, faster-whisper
    ├── install-mcp.sh              # Claude Code CLI, filesystem/GitHub/Playwright/Brave Search MCP servers
    ├── install-ops.sh              # Docker + Compose, Open WebUI (Docker), lazygit, k9s, starship
    ├── install-dotfiles.sh         # Shell RC wiring, env.sh from template, starship config
    ├── audit.sh                    # Read-only environment inventory
    └── tests/                      # bats unit tests — one file per module
```

### Key Design Decisions

**Entry point:** `./setup.sh` — single command, no user prompting. Bootstraps Homebrew (macOS) or apt (Ubuntu) before calling modules. All scripts support `--dry-run`.

**Skills:** `common/` is the source of truth for portable prompt workflows. Tool dirs (`claude/`, `cursor/`) are consumers via absolute symlinks created by `setup.sh`. No duplication.

**Skills source:** `andrewkriley/claude` (GitHub) was a one-time copy into `skills/claude/` — no ongoing sync dependency.

**Python AI env:** `~/ai-env` (not project-local). Managed via `pyproject.toml` + `uv.lock`. `install-ai.sh` runs `uv venv ~/ai-env && uv sync`. PyTorch index URL is platform-conditional (CUDA on Linux, MPS on macOS ARM).

**Ollama:** Native install only — Docker adds GPU overhead on macOS. Open WebUI runs via Docker (web app, different case).

**Secrets:** Plaintext `~/.config/riles-workstation/env.sh` sourced from shell RC. Generated from template at install time with placeholder values and inline comments. `direnv` + encrypted secrets (`sops`/`age`) is a planned future upgrade.

**Portability:** All scripts use `#!/usr/bin/env bash`. Platform branching centralised in `lib/os.sh` — all modules source this, never branch on OS themselves.

## Testing

```bash
# Run all bats unit tests
cd dev-workstation-build && bats tests/

# Run a single test file
bats tests/test_os_detect.bats

# Lint all scripts
shellcheck dev-workstation-build/**/*.sh
shfmt -d dev-workstation-build/
```

CI runs `shellcheck` + `shfmt` on every push. Docker-based integration tests run on `ubuntu:22.04` and `ubuntu:24.04`. macOS unit tests run via GitHub Actions.

## Running the Workstation Setup

```bash
# Full install (idempotent)
./setup.sh

# Preview without making changes
./setup.sh --dry-run

# Run a single module directly
cd dev-workstation-build && ./install-ai.sh
./install-ai.sh --dry-run

# Audit current state (no writes)
./dev-workstation-build/audit.sh
```

## Deferred / Future

- `codex/` skill format — not yet needed
- `direnv` + `sops`/`age` encrypted secrets
- Slack and Splunk MCP servers
- Fuller k8s tooling in `install-ops.sh`
- Open WebUI model pre-pull strategy
