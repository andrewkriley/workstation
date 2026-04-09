#!/usr/bin/env bash
# install-ops.sh — DevOps + platform tools
# Installs: lazygit, k9s, starship, gh, glab, terraform, ansible, kubectl, helm
# Docker is handled separately by install-docker.sh
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

echo -e "${BOLD}Ops Tools — Install${RESET}"
echo -e "Platform: $OS"
echo -e "Date:     $(date)\n"

# ── lazygit ───────────────────────────────────────────────────────────────────
section "lazygit"
if command -v lazygit &>/dev/null; then
  skip "lazygit ($(lazygit --version 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install lazygit"
  else
    log "Installing lazygit..."
    brew install lazygit
    ok "lazygit installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would download lazygit binary from GitHub releases"
  else
    log "Installing lazygit..."
    LAZYGIT_VERSION="$(curl -sSfL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
      grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')"
    ARCH="$(uname -m)"
    LG_ARCH="x86_64"
    [[ "$ARCH" == "aarch64" ]] && LG_ARCH="arm64"
    curl -sSfL \
      "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz" |
      tar -xz -C /tmp lazygit
    sudo install -m 755 /tmp/lazygit /usr/local/bin/lazygit
    rm -f /tmp/lazygit
    ok "lazygit ${LAZYGIT_VERSION} installed"
  fi
fi

# ── k9s ───────────────────────────────────────────────────────────────────────
section "k9s"
if command -v k9s &>/dev/null; then
  skip "k9s ($(k9s version --short 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install k9s"
  else
    log "Installing k9s..."
    brew install k9s
    ok "k9s installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would download k9s binary from GitHub releases"
  else
    log "Installing k9s..."
    K9S_VERSION="$(curl -sSfL https://api.github.com/repos/derailed/k9s/releases/latest |
      grep '"tag_name"' | cut -d'"' -f4)"
    ARCH="$(uname -m)"
    K9S_ARCH="amd64"
    [[ "$ARCH" == "aarch64" ]] && K9S_ARCH="arm64"
    curl -sSfL \
      "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${K9S_ARCH}.tar.gz" |
      tar -xz -C /tmp k9s
    sudo install -m 755 /tmp/k9s /usr/local/bin/k9s
    rm -f /tmp/k9s
    ok "k9s ${K9S_VERSION} installed"
  fi
fi

# ── starship ──────────────────────────────────────────────────────────────────
section "Starship Prompt"
if command -v starship &>/dev/null; then
  skip "starship ($(starship --version 2>/dev/null | head -1))"
elif $DRY_RUN; then
  dryrun "Would run: curl -sS https://starship.rs/install.sh | sh"
else
  log "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  ok "starship installed"
fi

# ── gh (GitHub CLI) ───────────────────────────────────────────────────────────
section "gh (GitHub CLI)"
if command -v gh &>/dev/null; then
  skip "gh ($(gh --version 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install gh"
  else
    log "Installing gh..."
    brew install gh
    ok "gh installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would add GitHub CLI apt repo and install gh"
  else
    log "Installing gh via apt..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq gh
    ok "gh installed"
  fi
fi

# ── glab (GitLab CLI) ─────────────────────────────────────────────────────────
section "glab (GitLab CLI)"
if command -v glab &>/dev/null; then
  skip "glab ($(glab --version 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install glab"
  else
    log "Installing glab..."
    brew install glab
    ok "glab installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would download glab binary from GitHub releases"
  else
    log "Installing glab..."
    GLAB_VERSION="$(curl -sSfL https://api.github.com/repos/gitlab-org/cli/releases/latest |
      grep '"tag_name"' | cut -d'"' -f4)"
    ARCH="$(uname -m)"
    GLAB_ARCH="amd64"
    [[ "$ARCH" == "aarch64" ]] && GLAB_ARCH="arm64"
    curl -sSfL \
      "https://github.com/gitlab-org/cli/releases/download/${GLAB_VERSION}/glab_${GLAB_VERSION#v}_linux_${GLAB_ARCH}.tar.gz" |
      tar -xz -C /tmp
    sudo install -m 755 /tmp/bin/glab /usr/local/bin/glab
    rm -rf /tmp/bin
    ok "glab ${GLAB_VERSION} installed"
  fi
fi

# ── Terraform ─────────────────────────────────────────────────────────────────
section "Terraform"
if command -v terraform &>/dev/null; then
  skip "terraform ($(terraform version -json 2>/dev/null | grep '"terraform_version"' | cut -d'"' -f4))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install hashicorp/tap/terraform"
  else
    log "Installing Terraform..."
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
    ok "terraform installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would add HashiCorp apt repo and install terraform"
  else
    log "Installing Terraform..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg |
      sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
      sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq terraform
    ok "terraform installed"
  fi
fi

# ── Ansible ───────────────────────────────────────────────────────────────────
section "Ansible"
if command -v ansible &>/dev/null; then
  skip "ansible ($(ansible --version 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install ansible"
  else
    log "Installing Ansible..."
    brew install ansible
    ok "ansible installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would run: apt-get install ansible"
  else
    log "Installing Ansible..."
    sudo apt-get install -y -qq software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y -qq ansible
    ok "ansible installed"
  fi
fi

# ── kubectl ───────────────────────────────────────────────────────────────────
section "kubectl"
if command -v kubectl &>/dev/null; then
  skip "kubectl ($(kubectl version --client --short 2>/dev/null | head -1))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install kubectl"
  else
    log "Installing kubectl..."
    brew install kubectl
    ok "kubectl installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would download kubectl binary from dl.k8s.io"
  else
    log "Installing kubectl..."
    KUBE_VERSION="$(curl -sSfL https://dl.k8s.io/release/stable.txt)"
    ARCH="$(uname -m)"
    KUBE_ARCH="amd64"
    [[ "$ARCH" == "aarch64" ]] && KUBE_ARCH="arm64"
    curl -sSfL "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${KUBE_ARCH}/kubectl" \
      -o /tmp/kubectl
    sudo install -m 755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl
    ok "kubectl ${KUBE_VERSION} installed"
  fi
fi

# ── Helm ──────────────────────────────────────────────────────────────────────
section "Helm"
if command -v helm &>/dev/null; then
  skip "helm ($(helm version --short 2>/dev/null))"
elif [[ "$OS" == macos-* ]]; then
  if $DRY_RUN; then
    dryrun "Would run: brew install helm"
  else
    log "Installing Helm..."
    brew install helm
    ok "helm installed"
  fi
else
  if $DRY_RUN; then
    dryrun "Would run: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
  else
    log "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ok "helm installed"
  fi
fi

echo -e "\n${BOLD}${GREEN}Ops tools install complete!${RESET}\n"
