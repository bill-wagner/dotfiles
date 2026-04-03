#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[install] $*"
}

OS="$(uname -s)"
log "Detected OS: $OS"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"

# --- Tool installation ---

# Homebrew
if command -v brew &>/dev/null; then
  log "Homebrew already installed, skipping."
else
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for the rest of this script
  if [ "$OS" = "Darwin" ]; then
    if [ -x "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  log "Homebrew installed."
fi

# git-delta
if command -v delta &>/dev/null; then
  log "git-delta already installed, skipping."
else
  log "Installing git-delta via Homebrew..."
  brew install git-delta
  log "git-delta installed."
fi

# oh-my-posh
if command -v oh-my-posh &>/dev/null; then
  log "oh-my-posh already installed, skipping."
else
  log "Installing oh-my-posh via Homebrew..."
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
  log "oh-my-posh installed."
fi

# oh-my-posh theme
OMP_THEME_DIR="$HOME/.oh-my-posh-custom-themes"
OMP_THEME_SRC="$SCRIPT_DIR/custom-atomic.omp.json"
OMP_THEME_DEST="$OMP_THEME_DIR/custom-atomic.omp.json"
log "Configuring oh-my-posh theme..."
mkdir -p "$OMP_THEME_DIR"
if [ -f "$OMP_THEME_SRC" ]; then
  cp "$OMP_THEME_SRC" "$OMP_THEME_DEST"
  log "Copied custom-atomic.omp.json to $OMP_THEME_DIR."
else
  log "WARNING: $OMP_THEME_SRC not found, skipping theme copy."
fi

# asdf (git clone for cross-platform reliability)
if [ -d "$HOME/.asdf" ]; then
  log "asdf already installed, skipping."
else
  log "Installing asdf..."
  git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf"
  log "asdf installed."
fi
# Source asdf for the rest of this script
# shellcheck disable=SC1091
. "$HOME/.asdf/asdf.sh"

# asdf plugins
ASDF_PLUGINS=(nodejs python ruby sqlite yarn)
log "Installing asdf plugins..."
for plugin in "${ASDF_PLUGINS[@]}"; do
  if asdf plugin list | grep -q "^${plugin}$"; then
    log "asdf plugin already installed, skipping: $plugin"
  else
    asdf plugin add "$plugin"
    log "Added asdf plugin: $plugin"
  fi
done

# asdf tool installation
if [ -f ".tool-versions" ]; then
  log "Found .tool-versions, running asdf install..."
  asdf install
  log "asdf install complete."
else
  log "No .tool-versions found, skipping asdf install."
fi

# SSH key — add to macOS Keychain so passphrase is not required on future logins
if [ "$OS" = "Darwin" ]; then
  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    log "Adding SSH key to macOS Keychain..."
    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"
    log "SSH key added to Keychain."
  else
    log "No ~/.ssh/id_ed25519 found, skipping Keychain ssh-add."
  fi
fi

# --- .bashrc configuration ---
# Order matters: PATH setup (Homebrew, asdf) must come before anything that uses those tools (oh-my-posh).

# 1. Homebrew shell environment (sets PATH so Homebrew tools are available)
if [ "$OS" = "Darwin" ]; then
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
  log "Added Homebrew shellenv to $BASHRC."
fi

# 2. asdf shell integration (sets PATH so asdf-managed tools are available)
ASDF_SOURCE='. "$HOME/.asdf/asdf.sh"'
log "Configuring asdf shell integration in $BASHRC..."
if grep -qxF "$ASDF_SOURCE" "$BASHRC" 2>/dev/null; then
  log "asdf shell integration already in $BASHRC, skipping."
else
  echo "$ASDF_SOURCE" >> "$BASHRC"
  log "Added asdf shell integration to $BASHRC."
fi

# 3. oh-my-posh init (requires Homebrew to be on PATH)
OMP_INIT_LINE='eval "$(oh-my-posh init bash --config $HOME/.oh-my-posh-custom-themes/custom-atomic.omp.json)"'
log "Configuring oh-my-posh init in $BASHRC..."
if grep -qxF "$OMP_INIT_LINE" "$BASHRC" 2>/dev/null; then
  log "oh-my-posh init already in $BASHRC, skipping."
else
  echo "$OMP_INIT_LINE" >> "$BASHRC"
  log "Added oh-my-posh init to $BASHRC."
fi

# 4. Shell aliases
if [ "$OS" = "Darwin" ]; then
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
    log "Added: $alias_line"
  fi
done

# 5. Homebrew analytics opt-out
HOMEBREW_LINE="export HOMEBREW_NO_ANALYTICS=1"
log "Configuring Homebrew analytics opt-out in $BASHRC..."
if grep -qxF "$HOMEBREW_LINE" "$BASHRC" 2>/dev/null; then
  log "Already present, skipping: $HOMEBREW_LINE"
else
  echo "$HOMEBREW_LINE" >> "$BASHRC"
  log "Added: $HOMEBREW_LINE"
fi

# 6. Disable terminal flow control (enables CTRL+S for forward history search)
FLOW_CONTROL_LINE="stty -ixon"
log "Configuring terminal flow control in $BASHRC..."
if grep -qxF "$FLOW_CONTROL_LINE" "$BASHRC" 2>/dev/null; then
  log "Already present, skipping: $FLOW_CONTROL_LINE"
else
  echo "$FLOW_CONTROL_LINE" >> "$BASHRC"
  log "Added: $FLOW_CONTROL_LINE"
fi

# 7. Eternal bash history
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
    log "Added: $line"
  fi
done

# Claude Code Dev Container permissions
if [ "${REMOTE_CONTAINERS:-}" = "true" ] || [ "${CODESPACES:-}" = "true" ]; then
  CLAUDE_SETTINGS_DIR=".claude"
  CLAUDE_SETTINGS_LOCAL="$CLAUDE_SETTINGS_DIR/settings.local.json"
  if [ -f "$CLAUDE_SETTINGS_LOCAL" ]; then
    log "Claude Code settings.local.json already exists, skipping."
  else
    log "Dev Container detected — creating $CLAUDE_SETTINGS_LOCAL with bypassPermissions..."
    mkdir -p "$CLAUDE_SETTINGS_DIR"
    cat > "$CLAUDE_SETTINGS_LOCAL" <<'EOF'
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
EOF
    log "Created $CLAUDE_SETTINGS_LOCAL."
  fi
else
  log "Not in a Dev Container, skipping Claude Code settings.local.json."
fi

log "Done."
