#!/usr/bin/env bash
# lib/os.sh — OS and architecture detection
# Source this file in all install modules: source "$(dirname "$0")/lib/os.sh"

detect_os() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin)
      case "$arch" in
        arm64) echo "macos-arm" ;;
        x86_64) echo "macos-intel" ;;
        *) echo "macos-unknown" ;;
      esac
      ;;
    Linux)
      case "$arch" in
        x86_64) echo "linux-x86" ;;
        aarch64 | arm64) echo "linux-arm" ;;
        *) echo "linux-unknown" ;;
      esac
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Set PKG_MANAGER based on detected OS
set_pkg_manager() {
  local os
  os="$(detect_os)"
  case "$os" in
    macos-*) PKG_MANAGER="brew" ;;
    linux-*) PKG_MANAGER="apt" ;;
    *)
      echo "ERROR: Unsupported OS: $os" >&2
      exit 1
      ;;
  esac
  export PKG_MANAGER
}

# Ensure Homebrew is installed (macOS only)
ensure_brew() {
  if ! command -v brew &>/dev/null; then
    echo "--> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
}

# Install a package using the appropriate package manager
pkg_install() {
  local pkg="$1"
  case "$PKG_MANAGER" in
    brew) brew install "$pkg" ;;
    apt) sudo apt-get install -y -qq "$pkg" ;;
  esac
}

# Check if a package is installed (by command name)
pkg_installed() {
  command -v "$1" &>/dev/null
}
