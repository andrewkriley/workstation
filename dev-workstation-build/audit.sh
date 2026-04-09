#!/usr/bin/env bash
# audit.sh — Applied AI Developer Workstation Audit
# Reports what's installed, what's missing, and what version.
# Options:
#   --validate-auth   Make live API calls to verify configured service tokens

set -euo pipefail

# ── Flag parsing ───────────────────────────────────────────────────────────────
VALIDATE_AUTH=false
for _arg in "$@"; do
	case "$_arg" in
	--validate-auth) VALIDATE_AUTH=true ;;
	esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok() { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
missing() { echo -e "  ${RED}[MISSING]${RESET} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${RESET}   $1"; }
section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${RESET}"; }

check_cmd() {
	local name="$1"
	local cmd="${2:-$1}"
	local version_flag="${3:---version}"
	if command -v "$cmd" &>/dev/null; then
		local ver
		ver=$("$cmd" $version_flag 2>&1 | head -1 | sed 's/^[^0-9]*//' | cut -c1-40) || ver="(version unknown)"
		ok "$name: $ver"
		return 0
	else
		missing "$name"
		return 1
	fi
}

check_python_pkg() {
	local pkg="$1"
	local import="${2:-$1}"
	if python3 -c "import $import" &>/dev/null 2>&1; then
		local ver
		ver=$(python3 -c "import $import; print(getattr($import, '__version__', 'installed'))" 2>/dev/null || echo "installed")
		ok "$pkg: $ver"
	else
		missing "$pkg"
	fi
}

echo -e "${BOLD}Applied AI Developer Workstation Audit${RESET}"
echo -e "Date: $(date)"
echo -e "Host: $(hostname)"

# Inline OS detection — audit.sh is meant to be run standalone
_AUDIT_OS="linux"
[[ "$(uname)" == "Darwin" ]] && _AUDIT_OS="macos"

# ── System Resources ──────────────────────────────────────────────────────────
section "System Resources"
if [ "$_AUDIT_OS" = "macos" ]; then
	echo "  CPU:  $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'unknown')"
	echo "  Cores: $(sysctl -n hw.ncpu 2>/dev/null || echo 'unknown')"
	_mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
	echo "  RAM:  $((_mem_bytes / 1024 / 1024 / 1024))GB total"
else
	echo "  CPU:  $(lscpu 2>/dev/null | grep 'Model name' | sed 's/Model name:[ ]*//' || echo 'unknown')"
	echo "  Cores: $(nproc 2>/dev/null || echo 'unknown')"
	echo "  RAM:  $(free -h 2>/dev/null | awk '/^Mem:/ {print $2 " total, " $7 " available"}' || echo 'unknown')"
fi
echo "  Disk: $(df -h / | awk 'NR==2 {print $4 " free of " $2}')"

# ── GPU ───────────────────────────────────────────────────────────────────────
section "GPU / Accelerator"
if command -v nvidia-smi &>/dev/null; then
	ok "NVIDIA GPU detected"
	nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | while IFS=',' read -r name driver mem; do
		echo "    GPU: $name | Driver: $driver | VRAM: $mem"
	done
	check_cmd "CUDA (nvcc)" nvcc "--version"
else
	warn "No NVIDIA GPU / nvidia-smi not found (CPU-only)"
fi
if command -v rocminfo &>/dev/null; then
	ok "ROCm (AMD GPU) detected"
else
	warn "No ROCm (AMD GPU) detected"
fi

# ── Python ────────────────────────────────────────────────────────────────────
section "Python Environment"
check_cmd "python3" python3 "--version"
check_cmd "pip3" pip3 "--version"
check_cmd "uv (astral)" uv "--version"
check_cmd "conda" conda "--version"
check_cmd "virtualenv" virtualenv "--version"

# ── AI/ML Python Packages ─────────────────────────────────────────────────────
section "AI/ML Python Packages"
check_python_pkg "torch (PyTorch)" torch
check_python_pkg "tensorflow" tensorflow
check_python_pkg "jax" jax
check_python_pkg "transformers (HuggingFace)" transformers
check_python_pkg "diffusers" diffusers
check_python_pkg "datasets" datasets
check_python_pkg "accelerate" accelerate
check_python_pkg "peft" peft
check_python_pkg "trl" trl
check_python_pkg "anthropic SDK" anthropic
check_python_pkg "openai SDK" openai
check_python_pkg "langchain" langchain
check_python_pkg "llama-index" llama_index
check_python_pkg "litellm" litellm
check_python_pkg "sentence-transformers" sentence_transformers
check_python_pkg "chromadb" chromadb
check_python_pkg "faiss" faiss

# ── Notebooks ─────────────────────────────────────────────────────────────────
section "Notebooks"
check_cmd "jupyter" jupyter "--version"
check_cmd "jupyterlab" jupyter "lab --version"

# ── AI CLI Tools ──────────────────────────────────────────────────────────────
section "AI CLI Tools"
check_cmd "ollama" ollama "--version"
check_cmd "huggingface-cli" huggingface-cli "--version"
check_cmd "claude (Claude Code)" claude "--version"
check_cmd "aider" aider "--version"
check_cmd "llm (Simon Willison)" llm "--version"
check_cmd "openai CLI" openai "--version"

# ── Dev Tools ─────────────────────────────────────────────────────────────────
section "Core Dev Tools"
check_cmd "git" git "--version"
check_cmd "git-lfs" git-lfs "--version"
check_cmd "docker" docker "--version"
check_cmd "curl" curl "--version"
check_cmd "wget" wget "--version"
check_cmd "jq" jq "--version"
check_cmd "make" make "--version"
check_cmd "gcc" gcc "--version"
check_cmd "node" node "--version"
check_cmd "npm" npm "--version"
check_cmd "rust/cargo" cargo "--version"

# ── Cloud CLIs ────────────────────────────────────────────────────────────────
section "Cloud CLIs"
check_cmd "AWS CLI (aws)" aws "--version"
check_cmd "Google Cloud CLI (gcloud)" gcloud "version"
check_cmd "Azure CLI (az)" az "--version"

# ── IDEs ──────────────────────────────────────────────────────────────────────
section "IDEs"
check_cmd "VSCode (code)" code "--version"
check_cmd "Cursor" cursor "--version"

# ── Environment Config (env.sh) ───────────────────────────────────────────────
section "Environment Config (env.sh)"

ENV_FILE="$HOME/.config/workstation/env.sh"

if [ -f "$ENV_FILE" ]; then
	ok "env.sh exists: $ENV_FILE"
	chmod_val=$(stat -c '%a' "$ENV_FILE" 2>/dev/null || stat -f '%OLp' "$ENV_FILE" 2>/dev/null || echo "unknown")
	if [ "$chmod_val" = "600" ]; then
		ok "env.sh permissions: 600 (private)"
	else
		warn "env.sh permissions: $chmod_val (expected 600 — run: chmod 600 $ENV_FILE)"
	fi

	# Source env.sh in a subshell and check each expected variable
	check_env_var() {
		local var="$1"
		local val
		val=$(bash -c "source \"$ENV_FILE\" 2>/dev/null; printf '%s' \"\${$var:-}\"")
		if [ -n "$val" ]; then
			ok "$var: set"
		else
			warn "$var: not set (empty in $ENV_FILE)"
		fi
	}

	echo ""
	echo "  API Keys:"
	check_env_var "GITHUB_TOKEN"
	check_env_var "HF_TOKEN"

	echo ""
	echo "  LinkedIn:"
	check_env_var "LINKEDIN_CLIENT_ID"
	check_env_var "LINKEDIN_CLIENT_SECRET"
	check_env_var "LINKEDIN_TOKEN"
	check_env_var "LINKEDIN_PERSON_URN"

	echo ""
	echo "  Webex:"
	check_env_var "WEBEX_CLIENT_ID"
	check_env_var "WEBEX_CLIENT_SECRET"
	check_env_var "WEBEX_TOKEN"
	check_env_var "WEBEX_REFRESH_TOKEN"

	echo ""
	echo "  Splunk:"
	check_env_var "SPLUNK_HOST"
	check_env_var "SPLUNK_TOKEN"
	check_env_var "SPLUNK_USER"
	check_env_var "SPLUNK_PASS"
	check_env_var "SPLUNK_API_TOKEN"

	# Check it's wired into shell RC files
	echo ""
	echo "  Shell RC wiring:"
	for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
		[ -f "$rc" ] || continue
		if grep -qF "workstation/env.sh" "$rc"; then
			ok "Sourced in $rc"
		else
			warn "Not sourced in $rc — run: ./install-dotfiles.sh"
		fi
	done
else
	missing "env.sh not found at $ENV_FILE — run: ./install-dotfiles.sh"
fi

# ── Auth Validation ───────────────────────────────────────────────────────────
if [ "$VALIDATE_AUTH" = "true" ]; then
	section "Auth Validation"

	_env_file="$HOME/.config/workstation/env.sh"
	if [ -f "$_env_file" ]; then
		# shellcheck source=/dev/null
		source "$_env_file" 2>/dev/null || true
	else
		warn "env.sh not found — cannot validate auth"
	fi

	_check_auth() {
		local name="$1" url="$2" header="$3" extra_flags="${4:-}"
		local status
		# shellcheck disable=SC2086
		status=$(curl -s -o /dev/null -w "%{http_code}" -H "$header" $extra_flags "$url" 2>/dev/null) || {
			warn "$name: connection failed"
			return
		}
		if [ "$status" = "200" ]; then
			ok "$name: authenticated"
		else
			warn "$name: auth failed (HTTP $status)"
		fi
	}

	echo ""
	echo "  API Keys:"
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		_check_auth "GitHub" "https://api.github.com/user" "Authorization: token $GITHUB_TOKEN"
	else
		warn "GitHub: GITHUB_TOKEN not set, skipping"
	fi
	if [ -n "${HF_TOKEN:-}" ]; then
		_check_auth "HuggingFace" "https://huggingface.co/api/whoami" "Authorization: Bearer $HF_TOKEN"
	else
		warn "HuggingFace: HF_TOKEN not set, skipping"
	fi

	echo ""
	echo "  LinkedIn:"
	if [ -n "${LINKEDIN_TOKEN:-}" ]; then
		_check_auth "LinkedIn" "https://api.linkedin.com/v2/userinfo" "Authorization: Bearer $LINKEDIN_TOKEN"
	else
		warn "LinkedIn: LINKEDIN_TOKEN not set, skipping"
	fi

	echo ""
	echo "  Webex:"
	if [ -n "${WEBEX_TOKEN:-}" ]; then
		_check_auth "Webex" "https://webexapis.com/v1/people/me" "Authorization: Bearer $WEBEX_TOKEN"
	else
		warn "Webex: WEBEX_TOKEN not set, skipping"
	fi

	echo ""
	echo "  Splunk:"
	_splunk_token="${SPLUNK_TOKEN:-${SPLUNK_API_TOKEN:-}}"
	if [ -n "${SPLUNK_HOST:-}" ] && [ -n "$_splunk_token" ]; then
		_check_auth "Splunk (token)" \
			"https://${SPLUNK_HOST}:8089/services/authentication/current-context?output_mode=json" \
			"Authorization: Bearer $_splunk_token" "-k"
	elif [ -n "${SPLUNK_HOST:-}" ] && [ -n "${SPLUNK_USER:-}" ] && [ -n "${SPLUNK_PASS:-}" ]; then
		_splunk_status=$(curl -s -o /dev/null -w "%{http_code}" -k \
			-u "${SPLUNK_USER}:${SPLUNK_PASS}" \
			"https://${SPLUNK_HOST}:8089/services/authentication/current-context?output_mode=json" 2>/dev/null) || _splunk_status="000"
		if [ "$_splunk_status" = "200" ]; then
			ok "Splunk (basic auth): authenticated"
		else
			warn "Splunk (basic auth): auth failed (HTTP $_splunk_status)"
		fi
	else
		warn "Splunk: credentials not set, skipping"
	fi
fi

echo -e "\n${BOLD}Audit complete.${RESET} Run ${CYAN}./install.sh${RESET} to install missing components.\n"
