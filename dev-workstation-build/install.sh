#!/usr/bin/env bash
# install.sh — Applied AI Developer Workstation Setup
# Installs missing tools for an applied AI development environment.
# Safe to re-run — skips anything already installed.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log() { echo -e "${CYAN}-->${RESET} $1"; }
ok() { echo -e "${GREEN}[done]${RESET} $1"; }
skip() { echo -e "${YELLOW}[skip]${RESET} $1 (already installed)"; }
section() { echo -e "\n${BOLD}${CYAN}=== $1 ===${RESET}"; }

# ── Flags ─────────────────────────────────────────────────────────────────────
INSTALL_SYSTEM=true  # apt packages (requires sudo)
INSTALL_UV=true      # uv package manager
INSTALL_AI_PKGS=true # Python AI/ML packages
INSTALL_OLLAMA=true  # Ollama local LLM
INSTALL_AIDER=true   # Aider AI pair programmer

# Parse optional flags
for arg in "$@"; do
	case $arg in
	--no-system) INSTALL_SYSTEM=false ;;
	--no-uv) INSTALL_UV=false ;;
	--no-ai-pkgs) INSTALL_AI_PKGS=false ;;
	--no-ollama) INSTALL_OLLAMA=false ;;
	--no-aider) INSTALL_AIDER=false ;;
	--help)
		echo "Usage: $0 [--no-system] [--no-uv] [--no-ai-pkgs] [--no-ollama] [--no-aider]"
		exit 0
		;;
	esac
done

echo -e "${BOLD}Applied AI Developer Workstation — Install${RESET}"
echo -e "Date: $(date)\n"

# ── System Packages (apt) ─────────────────────────────────────────────────────
if $INSTALL_SYSTEM; then
	section "System Packages"
	log "Updating apt index..."
	sudo apt-get update -qq

	APT_PKGS=()
	command -v git-lfs &>/dev/null || APT_PKGS+=(git-lfs)
	command -v clang &>/dev/null || APT_PKGS+=(clang)
	command -v cargo &>/dev/null || APT_PKGS+=(cargo)
	dpkg -s build-essential &>/dev/null 2>&1 || APT_PKGS+=(build-essential)
	dpkg -s python3-venv &>/dev/null 2>&1 || APT_PKGS+=(python3-venv)

	if [ ${#APT_PKGS[@]} -gt 0 ]; then
		log "Installing: ${APT_PKGS[*]}"
		sudo apt-get install -y -qq "${APT_PKGS[@]}"
		ok "System packages installed"
	else
		skip "All system packages"
	fi

	if command -v git-lfs &>/dev/null; then
		git lfs install --skip-repo 2>/dev/null || true
		ok "git-lfs initialised"
	fi
fi

# ── uv (Python package manager) ───────────────────────────────────────────────
if $INSTALL_UV; then
	section "uv — Python Package Manager"
	if command -v uv &>/dev/null; then
		skip "uv ($(uv --version))"
	else
		log "Installing uv..."
		curl -LsSf https://astral.sh/uv/install.sh | sh
		export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
		ok "uv installed"
	fi
fi

# ── AI Python Environment ─────────────────────────────────────────────────────
if $INSTALL_AI_PKGS; then
	section "AI/ML Python Environment"

	VENV_DIR="$HOME/ai-env"

	if [ ! -d "$VENV_DIR" ]; then
		log "Creating virtual environment at $VENV_DIR..."
		if command -v uv &>/dev/null; then
			uv venv "$VENV_DIR"
		else
			python3 -m venv "$VENV_DIR"
		fi
		ok "Virtual environment created"
	else
		skip "Virtual environment ($VENV_DIR already exists)"
	fi

	# shellcheck disable=SC1091
	source "$VENV_DIR/bin/activate"

	install_pkg() {
		local pkg="$1"
		local import="${2:-$1}"
		if python3 -c "import $import" &>/dev/null 2>&1; then
			skip "$pkg"
		else
			log "Installing $pkg..."
			if command -v uv &>/dev/null; then
				uv pip install "$pkg"
			else
				pip install -q "$pkg"
			fi
			ok "$pkg installed"
		fi
	}

	log "Upgrading pip..."
	if command -v uv &>/dev/null; then
		uv pip install --upgrade pip 2>/dev/null || true
	else
		pip install -q --upgrade pip
	fi

	# Core ML
	install_pkg "torch" torch
	install_pkg "torchvision" torchvision
	install_pkg "transformers" transformers
	install_pkg "diffusers" diffusers
	install_pkg "datasets" datasets
	install_pkg "accelerate" accelerate
	install_pkg "peft" peft
	install_pkg "trl" trl

	# APIs
	install_pkg "anthropic" anthropic
	install_pkg "openai" openai

	# Application frameworks
	install_pkg "langchain" langchain
	install_pkg "llama-index" llama_index
	install_pkg "litellm" litellm

	# Embeddings & vector stores
	install_pkg "sentence-transformers" sentence_transformers
	install_pkg "chromadb" chromadb

	# Hugging Face Hub CLI
	install_pkg "huggingface-hub" huggingface_hub

	# Notebooks
	install_pkg "jupyterlab" jupyterlab
	install_pkg "ipywidgets" ipywidgets

	# Utilities
	install_pkg "python-dotenv" dotenv
	install_pkg "rich" rich
	install_pkg "httpx" httpx
	install_pkg "tqdm" tqdm

	deactivate
	echo ""
	ok "AI environment ready. Activate with: source $VENV_DIR/bin/activate"

	# Shell activation helper
	ACTIVATE_LINE="alias ai-env='source $VENV_DIR/bin/activate'"
	SHELL_RC="$HOME/.bashrc"
	[[ "$SHELL" == */zsh ]] && SHELL_RC="$HOME/.zshrc"
	if ! grep -q "alias ai-env=" "$SHELL_RC" 2>/dev/null; then
		echo "$ACTIVATE_LINE" >>"$SHELL_RC"
		ok "Added 'ai-env' alias to $SHELL_RC"
	fi
fi

# ── Ollama ────────────────────────────────────────────────────────────────────
if $INSTALL_OLLAMA; then
	section "Ollama — Local LLM Inference"
	if command -v ollama &>/dev/null; then
		skip "ollama ($(ollama --version 2>/dev/null | head -1))"
	else
		log "Installing ollama..."
		curl -fsSL https://ollama.com/install.sh | sh
		ok "ollama installed"
		echo "  Run 'ollama pull llama3.2' to download your first model"
	fi
fi

# ── Aider ─────────────────────────────────────────────────────────────────────
if $INSTALL_AIDER; then
	section "Aider — AI Pair Programming"
	if command -v aider &>/dev/null; then
		skip "aider ($(aider --version 2>/dev/null | head -1))"
	else
		if command -v uv &>/dev/null; then
			log "Installing aider via uv tool..."
			uv tool install aider-chat
		else
			log "Installing aider via pipx/pip..."
			if command -v pipx &>/dev/null; then
				pipx install aider-chat
			else
				pip install -q aider-chat
			fi
		fi
		ok "aider installed"
	fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}Install complete!${RESET}"
echo ""
echo -e "  Activate AI env:  ${CYAN}source ~/ai-env/bin/activate${RESET}  (or type ${CYAN}ai-env${RESET} after shell restart)"
echo -e "  Run audit:        ${CYAN}./audit.sh${RESET}"
echo ""
echo -e "  Next steps:"
echo -e "    • Set API keys: ${CYAN}export ANTHROPIC_API_KEY=... OPENAI_API_KEY=...${RESET}"
echo -e "    • Log in to HF:  ${CYAN}huggingface-cli login${RESET}"
if $INSTALL_OLLAMA; then
	echo -e "    • Pull a model:  ${CYAN}ollama pull llama3.2${RESET}"
fi
echo ""
