#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'
NC=$'\033[0m'

log() {
  echo "[install] $*"
}
log_success() {
  echo "${GREEN}[install]${NC} $*"
}
log_error() {
  echo "${RED}[install]${NC} $*" >&2
}
log_warning() {
  echo "${YELLOW}[install]${NC} $*"
}
log_action() {
  echo ""
  echo "${YELLOW}${BOLD}[install] !! ACTION REQUIRED !!${NC}"
  for msg in "$@"; do
    echo "${YELLOW}${BOLD}[install]${NC} $msg"
  done
  echo ""
}

trap 'log_error "Script failed at line $LINENO"' ERR

OS="$(uname -s)"
log "Detected OS: $OS"

# Normalize to a three-way OS type: Darwin, Linux, or MSYS2
case "$OS" in
  MSYS_NT*|MINGW*) OS_TYPE="MSYS2"   ;;
  Darwin)          OS_TYPE="Darwin"  ;;
  *)               OS_TYPE="Linux"   ;;
esac
log "OS type: $OS_TYPE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$OS_TYPE" = "MSYS2" ]; then
  # Derive MSYS2 internal home from USERPROFILE. We cannot rely on $HOME here because the
  # script may be run from an already-initialized MSYS2 session where .bashrc has already
  # overridden HOME to $USERPROFILE. Strip everything up to the last backslash to get the
  # username (e.g. C:\Users\bill.wagner -> bill.wagner).
  MSYS2_INTERNAL_HOME="/home/${USERPROFILE##*\\}"
  BASHRC="$MSYS2_INTERNAL_HOME/.bashrc"
  HOME="$USERPROFILE"
else
  MSYS2_INTERNAL_HOME="$HOME"
  BASHRC="$HOME/.bashrc"
fi

# --- Tool installation ---

# MSYS2: inherit full Windows PATH so Windows-installed tools (dotnet, etc.) are accessible
if [ "$OS_TYPE" = "MSYS2" ]; then
  if [ "${MSYS2_PATH_TYPE:-}" = "inherit" ]; then
    log "MSYS2_PATH_TYPE already set to inherit, skipping."
  else
    log "Setting MSYS2_PATH_TYPE=inherit so Windows PATH is inherited..."
    setx MSYS2_PATH_TYPE inherit
    log_success "MSYS2_PATH_TYPE set. Restart your terminal for it to take effect."
  fi
  if [ "${MSYS:-}" = "winsymlinks:nativestrict" ]; then
    log "MSYS already set to winsymlinks:nativestrict, skipping."
  else
    log "Setting MSYS=winsymlinks:nativestrict so ln -s creates real Windows symlinks..."
    setx MSYS winsymlinks:nativestrict
    log_success "MSYS set. Restart your terminal for it to take effect."
  fi
  # Tell Claude Code CLI to use MSYS2 bash instead of Git Bash when spawning subprocesses
  if [ "${CLAUDE_CODE_GIT_BASH_PATH:-}" = "C:/msys64/usr/bin/bash.exe" ]; then
    log "CLAUDE_CODE_GIT_BASH_PATH already set, skipping."
  else
    log "Setting CLAUDE_CODE_GIT_BASH_PATH to MSYS2 bash..."
    setx CLAUDE_CODE_GIT_BASH_PATH "C:/msys64/usr/bin/bash.exe"
    log_success "CLAUDE_CODE_GIT_BASH_PATH set. Restart your terminal for it to take effect."
  fi
fi

# Linux prerequisites for Homebrew
if [ "$OS_TYPE" = "Linux" ]; then
  log "Installing Linux prerequisites for Homebrew..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq build-essential curl file git
  log_success "Linux prerequisites installed."
fi

# Homebrew (macOS and Linux only — not available on Windows/MSYS2)
if [ "$OS_TYPE" != "MSYS2" ]; then
  if ! command -v brew &>/dev/null; then
    if [ "$OS_TYPE" = "Darwin" ]; then
      [ -x "/opt/homebrew/bin/brew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"
      [ -x "/usr/local/bin/brew" ]    && eval "$(/usr/local/bin/brew shellenv)"
    else
      [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi

  if command -v brew &>/dev/null; then
    log "Homebrew already installed, skipping."
  else
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    if [ "$OS_TYPE" = "Darwin" ]; then
      if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    else
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    log_success "Homebrew installed."
  fi
fi

# git-delta
if command -v delta &>/dev/null; then
  log "git-delta already installed, skipping."
elif [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing git-delta via pacman..."
  pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-delta
  log_success "git-delta installed."
else
  log "Installing git-delta via Homebrew..."
  brew install git-delta
  log_success "git-delta installed."
fi

# GitHub CLI
if command -v gh &>/dev/null; then
  log "GitHub CLI already installed, skipping."
elif [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing GitHub CLI via pacman..."
  pacman -S --noconfirm --needed mingw-w64-x86_64-github-cli
  log_success "GitHub CLI installed."
else
  log "Installing GitHub CLI via Homebrew..."
  brew install gh
  log_success "GitHub CLI installed."
fi

# JFrog CLI
if command -v jf &>/dev/null; then
  log "JFrog CLI already installed, skipping."
elif [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing JFrog CLI from releases.jfrog.io..."
  mkdir -p /usr/local/bin
  curl -fsSLg "https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf/[RELEASE]/jfrog-cli-windows-amd64/jf.exe" \
    -o /usr/local/bin/jf.exe
  log_success "JFrog CLI installed."
else
  log "Installing JFrog CLI via Homebrew..."
  brew install jfrog-cli
  log_success "JFrog CLI installed."
fi

# ag (the_silver_searcher)
if command -v ag &>/dev/null; then
  log "ag already installed, skipping."
elif [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing ag via pacman..."
  pacman -S --noconfirm --needed mingw-w64-x86_64-ag
  log_success "ag installed."
else
  log "Installing ag via Homebrew..."
  brew install the_silver_searcher
  log_success "ag installed."
fi

# circleci CLI
if command -v circleci &>/dev/null; then
  log "circleci CLI already installed, skipping."
elif [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing circleci CLI from GitHub releases..."
  pacman -S --noconfirm --needed unzip
  CIRCLECI_VERSION="$(curl -fsSL https://api.github.com/repos/CircleCI-Public/circleci-cli/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
  log "Latest circleci CLI version: ${CIRCLECI_VERSION}"
  CIRCLECI_TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/CircleCI-Public/circleci-cli/releases/download/v${CIRCLECI_VERSION}/circleci-cli_${CIRCLECI_VERSION}_windows_amd64.zip" \
    -o "${CIRCLECI_TMP}/circleci.zip"
  unzip -o "${CIRCLECI_TMP}/circleci.zip" -d "${CIRCLECI_TMP}"
  mkdir -p /usr/local/bin
  find "${CIRCLECI_TMP}" -name "circleci.exe" -exec cp {} /usr/local/bin/circleci \;
  rm -rf "${CIRCLECI_TMP}"
  log_success "circleci CLI installed."
else
  log "Installing circleci CLI via Homebrew..."
  brew install circleci
  log_success "circleci CLI installed."
fi

# Additional MSYS2 packages
if [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing additional MSYS2 base packages..."
  pacman -S --noconfirm --needed bash-completion less perl python rsync vim
  log "Installing additional MSYS2 mingw64 packages..."
  pacman -S --noconfirm --needed \
    mingw-w64-x86_64-jq \
    mingw-w64-x86_64-python \
    mingw-w64-x86_64-ruby \
    mingw-w64-x86_64-go \
    mingw-w64-x86_64-sqlite3
  log_success "Additional MSYS2 packages installed."
fi

# nodejs (MSYS2 — macOS/Linux uses asdf; native Windows installer preferred over pacman for
# compatibility with native addons and non-MSYS2 tools like VS Code)
if [ "$OS_TYPE" = "MSYS2" ]; then
  if command -v node &>/dev/null; then
    log "nodejs already available ($(node --version)), skipping."
  else
    log_action \
      "nodejs not found. Install the native Windows Node.js from https://nodejs.org," \
      "then re-run this script. (install.sh is idempotent — safe to run again.)"
  fi
fi

# yarn (MSYS2 — macOS/Linux uses asdf)
if [ "$OS_TYPE" = "MSYS2" ]; then
  if command -v yarn &>/dev/null; then
    log "yarn already installed, skipping."
  elif ! command -v node &>/dev/null; then
    log_action \
      "yarn requires nodejs. Install Node.js from https://nodejs.org first," \
      "then re-run this script to install yarn. (install.sh is idempotent — safe to run again.)"
  else
    log "Installing yarn via npm..."
    npm install -g yarn
    log_success "yarn installed."
  fi
fi

# postgres (MSYS2 — macOS/Linux uses asdf; native Windows installer recommended)
if [ "$OS_TYPE" = "MSYS2" ]; then
  if command -v psql &>/dev/null; then
    log "postgres already available, skipping."
  else
    log_action \
      "PostgreSQL not found. Install it from https://www.postgresql.org/download/windows/," \
      "then re-run this script. (install.sh is idempotent — safe to run again.)"
  fi
fi

# kubectl (MSYS2 — macOS/Linux uses asdf)
if [ "$OS_TYPE" = "MSYS2" ]; then
  if command -v kubectl &>/dev/null; then
    log "kubectl already installed, skipping."
  else
    log "Installing kubectl from Kubernetes releases..."
    KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    log "Latest kubectl version: ${KUBECTL_VERSION}"
    mkdir -p /usr/local/bin
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/windows/amd64/kubectl.exe" \
      -o /usr/local/bin/kubectl.exe
    log_success "kubectl installed."
  fi
fi

# helm (MSYS2 — macOS/Linux uses asdf)
if [ "$OS_TYPE" = "MSYS2" ]; then
  if command -v helm &>/dev/null; then
    log "helm already installed, skipping."
  else
    log "Installing helm from GitHub releases..."
    HELM_VERSION="$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest \
      | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    log "Latest helm version: ${HELM_VERSION}"
    HELM_TMP="$(mktemp -d)"
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-windows-amd64.zip" \
      -o "${HELM_TMP}/helm.zip"
    pacman -S --noconfirm --needed unzip
    unzip -o "${HELM_TMP}/helm.zip" -d "${HELM_TMP}"
    mkdir -p /usr/local/bin
    find "${HELM_TMP}" -name "helm.exe" -exec cp {} /usr/local/bin/helm.exe \;
    rm -rf "${HELM_TMP}"
    log_success "helm installed."
  fi
fi

# bash-completion (provides git tab-completion and other tool completions)
if [ "$OS_TYPE" = "MSYS2" ]; then
  log "bash-completion already in MSYS2 package list, skipping."
elif [ -f "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]; then
  log "bash-completion already installed, skipping."
else
  log "Installing bash-completion via Homebrew..."
  brew install bash-completion@2
  log_success "bash-completion installed."
fi

# oh-my-posh
if command -v oh-my-posh &>/dev/null; then
  log "oh-my-posh already installed, skipping."
elif [ "$OS_TYPE" = "MSYS2" ]; then
  log "Installing oh-my-posh via pacman..."
  pacman -S --noconfirm --needed mingw-w64-x86_64-oh-my-posh
  log_success "oh-my-posh installed."
else
  log "Installing oh-my-posh via Homebrew..."
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
  log_success "oh-my-posh installed."
fi

# oh-my-posh theme
OMP_THEME_DIR="$HOME/.oh-my-posh-custom-themes"
OMP_THEME_SRC="$SCRIPT_DIR/custom-atomic.omp.json"
OMP_THEME_DEST="$OMP_THEME_DIR/custom-atomic.omp.json"
log "Configuring oh-my-posh theme..."
mkdir -p "$OMP_THEME_DIR"
if [ -f "$OMP_THEME_SRC" ]; then
  cp "$OMP_THEME_SRC" "$OMP_THEME_DEST"
  log_success "Copied custom-atomic.omp.json to $OMP_THEME_DIR."
else
  log_warning "WARNING: $OMP_THEME_SRC not found, skipping theme copy."
fi

# asdf (not supported on Windows/MSYS2)
if [ "$OS_TYPE" != "MSYS2" ]; then
  if [ -d "$HOME/.asdf" ]; then
    log "asdf already installed, skipping."
  else
    log "Installing asdf..."
    git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.15.0
    log_success "asdf installed."
  fi
  # Source asdf for the rest of this script
  # shellcheck disable=SC1091
  . "$HOME/.asdf/asdf.sh"

  # asdf plugins
  ASDF_PLUGINS=(nodejs python ruby sqlite yarn postgres kubectl golang helm)
  log "Installing asdf plugins..."
  for plugin in "${ASDF_PLUGINS[@]}"; do
    if asdf plugin list | grep -q "^${plugin}$"; then
      log "asdf plugin already installed, skipping: $plugin"
    else
      asdf plugin add "$plugin"
      log_success "Added asdf plugin: $plugin"
    fi
  done

  # asdf tool installation — default tools from dotfiles
  log "Installing default tools from dotfiles .tool-versions..."
  (cd "$SCRIPT_DIR" && asdf install)
  log_success "Default tools installed."

  # Copy dotfiles .tool-versions to ~/.tool-versions as global fallback if not already present
  if [ ! -f "$HOME/.tool-versions" ]; then
    log "Copying .tool-versions to ~/.tool-versions as global default..."
    cp "$SCRIPT_DIR/.tool-versions" "$HOME/.tool-versions"
    log_success "Copied .tool-versions to ~/.tool-versions."
  else
    log "~/.tool-versions already exists, skipping."
  fi

  # asdf tool installation — project-specific tools
  if [ -f ".tool-versions" ] && [ "$(pwd)" != "$SCRIPT_DIR" ]; then
    log "Found .tool-versions in workspace, running asdf install..."
    asdf install
    log_success "Project tools installed."
  fi
else
  log "Skipping asdf installation on MSYS2 (not supported on Windows)."
fi

# Global .gitignore
log "Configuring global .gitignore..."
cp "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global"
git config --global core.excludesfile "$HOME/.gitignore_global"
log_success "Global .gitignore configured."

# git-delta configuration
log "Configuring git to use delta..."
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only --features=interactive"
git config --global delta.navigate "true"
git config --global delta.features "decorations"
git config --global delta.side-by-side "true"
git config --global delta.interactive.keep-plus-minus-markers "false"
git config --global delta.decorations.commit-decoration-style "blue ol"
git config --global delta.decorations.commit-style "raw"
git config --global delta.decorations.file-style "omit"
git config --global delta.decorations.hunk-header-decoration-style "blue box"
git config --global delta.decorations.hunk-header-file-style "red"
git config --global delta.decorations.hunk-header-line-number-style "#067a00"
git config --global delta.decorations.hunk-header-style "file line-number syntax"
git config --global merge.conflictstyle "diff3"
git config --global diff.colorMoved "default"
log_success "git-delta configured."

# SSH key — add to the platform keychain/agent so passphrase is not required on future logins
if [ "$OS_TYPE" = "Darwin" ]; then
  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    log "Adding SSH key to macOS Keychain..."
    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"
    log_success "SSH key added to Keychain."
  else
    log "No ~/.ssh/id_ed25519 found, skipping Keychain ssh-add."
  fi
fi

# --- .bashrc configuration ---
# Order matters: PATH setup (Homebrew, asdf, MSYS2 mingw64) must come before anything that uses those tools (oh-my-posh).

# 1. MSYS2: set HOME to $USERPROFILE so Windows-native tools (Claude, etc.) find config in the right place
if [ "$OS_TYPE" = "MSYS2" ]; then
  HOME_LINE='export HOME="$USERPROFILE"'
  log "Configuring HOME=\$USERPROFILE in $BASHRC..."
  if grep -qxF "$HOME_LINE" "$BASHRC" 2>/dev/null; then
    log "HOME already set in $BASHRC, skipping."
  else
    echo "$HOME_LINE" >> "$BASHRC"
    log_success "Added HOME=\$USERPROFILE to $BASHRC."
  fi
fi

# 2. MSYS2: write a runtime warning into $USERPROFILE/.bashrc and .bash_profile.
# These files are NOT auto-sourced by MSYS2 at startup; they only become reachable via
# 'source ~/.bashrc' after $HOME is changed to $USERPROFILE mid-session — a subtle footgun.
# The warning detects MSYS2 at source-time and prints a reminder to the user.
if [ "$OS_TYPE" = "MSYS2" ]; then
  for warn_file in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if grep -qF "MSYS2 footgun warning" "$warn_file" 2>/dev/null; then
      log "MSYS2 sourcing warning already in $warn_file, skipping."
    else
      log "Adding MSYS2 sourcing warning to $warn_file..."
      cat >> "$warn_file" << EOF

# MSYS2 footgun warning — added by https://github.com/bill-wagner/dotfiles/blob/master/install.sh
# This file is NOT automatically sourced by MSYS2 at startup.
if uname -s 2>/dev/null | grep -qE '(MSYS|MINGW)'; then
  echo "WARNING: You are in an MSYS2 session and have sourced a file from your Windows" >&2
  echo "user profile. This file is NOT automatically sourced by MSYS2 at startup." >&2
  echo "MSYS2 reads shell config from: $MSYS2_INTERNAL_HOME/.bashrc" >&2
  echo "To reload your MSYS2 shell config, run: source $MSYS2_INTERNAL_HOME/.bashrc" >&2
fi
EOF
      log_success "Added MSYS2 sourcing warning to $warn_file."
    fi
  done
fi

# 3. MSYS2: add /mingw64/bin and /ucrt64/bin to PATH so mingw64/ucrt64 packages are available in all terminal types
if [ "$OS_TYPE" = "MSYS2" ]; then
  MINGW_PATH='export PATH="/mingw64/bin:/ucrt64/bin:$PATH"'
  log "Configuring MINGW64/UCRT64 PATH in $BASHRC..."
  if grep -qxF "$MINGW_PATH" "$BASHRC" 2>/dev/null; then
    log "MINGW64/UCRT64 PATH already in $BASHRC, skipping."
  else
    # Remove any old mingw64-only PATH line before appending the updated one
    sed -i '/export PATH="\/mingw64\/bin/d' "$BASHRC"
    echo "$MINGW_PATH" >> "$BASHRC"
    log_success "Added MINGW64/UCRT64 PATH to $BASHRC."
  fi
fi

# 4. Homebrew shell environment (sets PATH so Homebrew tools are available; not applicable on MSYS2)
if [ "$OS_TYPE" != "MSYS2" ]; then
  if [ "$OS_TYPE" = "Darwin" ]; then
    if [ -x "/opt/homebrew/bin/brew" ]; then
      BREW_SHELLENV='eval "$(/opt/homebrew/bin/brew shellenv)"'
    else
      BREW_SHELLENV='eval "$(/usr/local/bin/brew shellenv)"'
    fi
  else
    BREW_SHELLENV='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  fi
  log "Configuring Homebrew shell environment in $BASHRC..."
  if grep -qF "brew shellenv" "$BASHRC" 2>/dev/null; then
    log "Homebrew shellenv already in $BASHRC, skipping."
  else
    echo "$BREW_SHELLENV" >> "$BASHRC"
    log_success "Added Homebrew shellenv to $BASHRC."
  fi
fi

# 5. bash-completion (git tab-completion and other completions; must come after Homebrew shellenv)
log "Configuring bash-completion in $BASHRC..."
if [ "$OS_TYPE" = "MSYS2" ]; then
  BASH_COMPLETION_LINE='[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion'
else
  BASH_COMPLETION_LINE='[[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]] && . "$(brew --prefix)/etc/profile.d/bash_completion.sh"'
fi
if grep -qF "bash_completion" "$BASHRC" 2>/dev/null; then
  log "bash-completion already in $BASHRC, skipping."
else
  echo "$BASH_COMPLETION_LINE" >> "$BASHRC"
  log_success "Added bash-completion to $BASHRC."
fi

# 6. asdf shell integration (sets PATH so asdf-managed tools are available; not applicable on MSYS2)
if [ "$OS_TYPE" != "MSYS2" ]; then
  ASDF_SOURCE='. "$HOME/.asdf/asdf.sh"'
  log "Configuring asdf shell integration in $BASHRC..."
  if grep -qxF "$ASDF_SOURCE" "$BASHRC" 2>/dev/null; then
    log "asdf shell integration already in $BASHRC, skipping."
  else
    echo "$ASDF_SOURCE" >> "$BASHRC"
    log_success "Added asdf shell integration to $BASHRC."
  fi
fi

# 7. oh-my-posh init (requires Homebrew to be on PATH on macOS/Linux)
OMP_INIT_LINE='eval "$(oh-my-posh init bash --config $HOME/.oh-my-posh-custom-themes/custom-atomic.omp.json)"'
log "Configuring oh-my-posh init in $BASHRC..."
if grep -qxF "$OMP_INIT_LINE" "$BASHRC" 2>/dev/null; then
  log "oh-my-posh init already in $BASHRC, skipping."
else
  echo "$OMP_INIT_LINE" >> "$BASHRC"
  log_success "Added oh-my-posh init to $BASHRC."
fi

# 8. Shell aliases
if [ "$OS_TYPE" = "Darwin" ]; then
  LS_ALIAS="alias ls='ls -G'"
else
  LS_ALIAS="alias ls='ls --color'"
fi
ALIASES=(
  "alias grep='grep --color'"
  "$LS_ALIAS"
  "alias ll='ls -l'"
  "alias l='ls -CF'"
)
log "Configuring shell aliases in $BASHRC..."
for alias_line in "${ALIASES[@]}"; do
  if grep -qxF "$alias_line" "$BASHRC" 2>/dev/null; then
    log "Already present, skipping: $alias_line"
  else
    echo "$alias_line" >> "$BASHRC"
    log_success "Added: $alias_line"
  fi
done

# 9. Homebrew analytics opt-out (not applicable on MSYS2)
if [ "$OS_TYPE" != "MSYS2" ]; then
  HOMEBREW_LINE="export HOMEBREW_NO_ANALYTICS=1"
  log "Configuring Homebrew analytics opt-out in $BASHRC..."
  if grep -qxF "$HOMEBREW_LINE" "$BASHRC" 2>/dev/null; then
    log "Already present, skipping: $HOMEBREW_LINE"
  else
    echo "$HOMEBREW_LINE" >> "$BASHRC"
    log_success "Added: $HOMEBREW_LINE"
  fi
fi

# 10. Disable terminal flow control (enables CTRL+S for forward history search)
FLOW_CONTROL_LINE="stty -ixon"
log "Configuring terminal flow control in $BASHRC..."
if grep -qxF "$FLOW_CONTROL_LINE" "$BASHRC" 2>/dev/null; then
  log "Already present, skipping: $FLOW_CONTROL_LINE"
else
  echo "$FLOW_CONTROL_LINE" >> "$BASHRC"
  log_success "Added: $FLOW_CONTROL_LINE"
fi

# 11. Eternal bash history
HISTORY_LINES=(
  "export HISTFILESIZE=999999"
  "export HISTSIZE=999999"
  'export HISTTIMEFORMAT="[%F %T] "'
  "export HISTFILE=~/.bash_eternal_history"
  'PROMPT_COMMAND="history -a; $PROMPT_COMMAND"'
)
log "Configuring eternal bash history in $BASHRC..."
for line in "${HISTORY_LINES[@]}"; do
  if grep -qxF "$line" "$BASHRC" 2>/dev/null; then
    log "Already present, skipping: $line"
  else
    echo "$line" >> "$BASHRC"
    log_success "Added: $line"
  fi
done

# 12. SSH agent (MSYS2 only — macOS uses Keychain, Linux typically has a system agent)
# Reuses an existing agent across terminal windows; starts a new one (prompting for passphrase once) if needed.
if [ "$OS_TYPE" = "MSYS2" ]; then
  log "Configuring SSH agent setup in $BASHRC..."
  if grep -qF "SSH_ENV=" "$BASHRC" 2>/dev/null; then
    log "SSH agent setup already in $BASHRC, skipping."
  else
    cat >> "$BASHRC" << 'EOF'
# SSH agent — reuse existing agent if still running, otherwise start a new one
SSH_ENV="$HOME/.ssh/agent.env"
if [ -f "$SSH_ENV" ]; then
  . "$SSH_ENV" > /dev/null
fi
if [ -z "${SSH_AGENT_PID:-}" ] || ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
  ssh-agent | sed 's/^echo/#echo/' > "$SSH_ENV"
  chmod 600 "$SSH_ENV"
  . "$SSH_ENV" > /dev/null
  [ -f "$HOME/.ssh/id_ed25519" ] && ssh-add "$HOME/.ssh/id_ed25519"
fi
EOF
    log_success "Added SSH agent setup to $BASHRC."
  fi
fi

# 13. MSYS2: git-completion from Git for Windows — must be last so bash-completion cannot overwrite it
if [ "$OS_TYPE" = "MSYS2" ]; then
  GIT_COMPLETION_LINE='[[ -r "/c/Program Files/Git/mingw64/share/git/completion/git-completion.bash" ]] && . "/c/Program Files/Git/mingw64/share/git/completion/git-completion.bash"'
  log "Configuring Git for Windows completion in $BASHRC (at end to prevent overwrite)..."
  # Always remove any existing line and re-append so it stays at the end
  sed -i '/git-completion\.bash/d' "$BASHRC"
  echo "$GIT_COMPLETION_LINE" >> "$BASHRC"
  log_success "Added Git for Windows completion to $BASHRC."
fi

log_success "Done."
