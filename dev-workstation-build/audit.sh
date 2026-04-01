#!/usr/bin/env bash
# audit.sh — Applied AI Developer Workstation Audit
# Reports what's installed, what's missing, and what version.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()      { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
missing() { echo -e "  ${RED}[MISSING]${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}[WARN]${RESET}   $1"; }
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

# ── System Resources ──────────────────────────────────────────────────────────
section "System Resources"
echo "  CPU:  $(lscpu 2>/dev/null | grep 'Model name' | sed 's/Model name:[ ]*//' || echo 'unknown')"
echo "  Cores: $(nproc)"
echo "  RAM:  $(free -h | awk '/^Mem:/ {print $2 " total, " $7 " available"}')"
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

echo -e "\n${BOLD}Audit complete.${RESET} Run ${CYAN}./install.sh${RESET} to install missing components.\n"
