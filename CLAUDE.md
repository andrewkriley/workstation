# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Personal workstation scaffold — a turnkey, idempotent setup for an AI-augmented development environment across Ubuntu and macOS. Focus areas: agentic AI, AIOps, developer productivity, local LLM inference, and MCP-based tool integration.

## Agreed Architecture

### Repository Structure

```
.
├── setup.sh                        # Single entry point — bootstraps + orchestrates everything
├── skills/
│   ├── common/                     # Single source of truth: PROFILE.md, DESIGN.md, env template, portable prompt workflows
│   ├── claude/                     # Claude Code SKILL.md format (9 skills from skills repo + common wrappers)
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
    ├── install-docker.sh           # Docker Engine + Compose plugin, Open WebUI (Docker)
    ├── install-ops.sh              # lazygit, k9s, starship, gh, glab, terraform, ansible, kubectl, helm
    ├── install-dotfiles.sh         # Shell RC wiring, env.sh from template, starship config
    ├── audit.sh                    # Read-only environment inventory
    └── tests/                      # bats unit tests — one file per module
```

### Key Design Decisions

**Entry point:** `./setup.sh` — single command, no user prompting. Bootstraps Homebrew (macOS) or apt (Ubuntu) before calling modules. All scripts support `--dry-run`.

**Skills:** `common/` is the source of truth for portable prompt workflows. Tool dirs (`claude/`, `cursor/`) are consumers via absolute symlinks created by `setup.sh`. No duplication.

**Skills source:** A one-time copy into `skills/claude/` — no ongoing sync dependency.

**Python AI env:** `~/ai-env` (not project-local). Managed via `pyproject.toml` + `uv.lock`. `install-ai.sh` runs `uv venv ~/ai-env && uv sync`. PyTorch index URL is platform-conditional (CUDA on Linux, MPS on macOS ARM).

**Ollama:** Native install only — Docker adds GPU overhead on macOS. Open WebUI runs via Docker (web app, different case).

**Secrets:** Plaintext `~/.config/workstation/env.sh` sourced from shell RC. Generated from template at install time with placeholder values and inline comments. `direnv` + encrypted secrets (`sops`/`age`) is a planned future upgrade.

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

## Platform Differences: macOS vs Linux

All platform branching is centralised in `lib/os.sh`. `detect_os()` returns one of `macos-arm | macos-intel | linux-x86 | linux-arm`. Modules source `lib/os.sh` and branch on `$OS` — they never call `uname` themselves.

### setup.sh

| Step | macOS | Linux |
|------|-------|-------|
| Bootstrap | Install Homebrew if missing (`ensure_brew`) | `apt-get update` |
| `sed -i` | BSD sed requires `.bak` suffix — wrapped in `sed_i()` | GNU sed — same wrapper, `.bak` removed after |

### install-system.sh

| Tool | macOS | Linux |
|------|-------|-------|
| ripgrep, bat, fzf, jq, tmux | `brew install` (batch) | `apt-get install` (batch) |
| bat binary | named `bat` | named `batcat` on Ubuntu; `~/.local/bin/bat → batcat` symlink created |
| eza | `brew install` | Third-party apt repo (gierens.de) with GPG key |
| zoxide | `brew install` | Upstream install script via curl |
| yq | `brew install` | Binary download from GitHub releases; arch-mapped (`amd64`/`arm64`) |
| fnm | `brew install` | Upstream install script via curl; added to `~/.local/share/fnm` |
| Node LTS | `fnm install --lts` (after brew) | Same, but PATH must be set manually before fnm is on `$PATH` |

### install-ai.sh

| Step | macOS | Linux |
|------|-------|-------|
| Build deps | None needed | `apt-get install git-lfs clang build-essential python3-venv` |
| PyTorch index | MPS (Apple Silicon) via `pyproject.toml` platform marker | CUDA via `pyproject.toml` platform marker |
| Everything else (uv, ai-env, Ollama, Aider, llm) | Identical | Identical |

### install-docker.sh

| Tool | macOS | Linux |
|------|-------|-------|
| Docker | `brew install --cask docker` (Docker Desktop) | `get.docker.com` script; `usermod -aG docker $USER` (re-login needed) |
| Docker Compose | Bundled with Docker Desktop | Downloaded separately from GitHub releases as CLI plugin |
| Post-Docker | `open -a Docker` + 60s daemon wait | No wait needed (daemon starts automatically) |
| Open WebUI | `docker run` on port 3000 (same on both) | Same |

### install-ops.sh

| Tool | macOS | Linux |
|------|-------|-------|
| lazygit | `brew install lazygit` | Binary tarball from GitHub releases; `sudo install` to `/usr/local/bin` |
| k9s | `brew install k9s` | Binary tarball from GitHub releases; `sudo install` to `/usr/local/bin` |
| starship | `curl` install script (same on both) | Same |
| Terraform | `brew install hashicorp/tap/terraform` | HashiCorp apt repo |
| Ansible | `brew install ansible` | PPA (`ppa:ansible/ansible`) via apt |
| kubectl | `brew install kubectl` | Binary download from `dl.k8s.io` |
| Helm | `brew install helm` | Official `get-helm-3` install script |

### install-mcp.sh

| Step | macOS | Linux |
|------|-------|-------|
| Node prerequisite | `fnm install --lts` via brew-managed fnm | fnm binary from `~/.local/share/fnm`; PATH must be exported first |
| Everything else | Identical | Identical |

### install-dotfiles.sh

| Step | macOS | Linux |
|------|-------|-------|
| RC files targeted | `~/.zshrc`, `~/.bashrc`, `~/.bash_profile` | `~/.zshrc`, `~/.bashrc` only |
| Reload hint | `source ~/.zshrc` | `source ~/.bashrc` |
| All wiring (env.sh, PATH, aliases, fnm, zoxide, starship) | Identical | Identical |

## Deferred / Future

- `codex/` skill format — not yet needed
- `direnv` + `sops`/`age` encrypted secrets
- Slack and Splunk MCP servers
- Fuller k8s tooling in `install-ops.sh`
- Open WebUI model pre-pull strategy
