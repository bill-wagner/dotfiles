#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[install] $*"
}

OS="$(uname -s)"
log "Detected OS: $OS"

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

# oh-my-posh
if command -v oh-my-posh &>/dev/null; then
  log "oh-my-posh already installed, skipping."
else
  log "Installing oh-my-posh via Homebrew..."
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
  log "oh-my-posh installed."
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

BASHRC="$HOME/.bashrc"

# ls alias is OS-dependent (macOS uses -G, Linux uses --color)
if [ "$OS" = "Darwin" ]; then
  LS_ALIAS="alias ls='ls -G'"
else
  LS_ALIAS="alias ls='ls --color'"
fi

# Shell aliases
ALIASES=(
  "alias grep='grep --color'"
  "$LS_ALIAS"
  "alias ll='ls -l'"
  "alias l='ls -CF'"
)
log "Configuring shell aliases in $BASHRC..."
for alias_line in "${ALIASES[@]}"; do
  if grep -qF "$alias_line" "$BASHRC" 2>/dev/null; then
    log "Already present, skipping: $alias_line"
  else
    echo "$alias_line" >> "$BASHRC"
    log "Added: $alias_line"
  fi
done

# Homebrew shell environment
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

# Opt out of Homebrew analytics
HOMEBREW_LINE="export HOMEBREW_NO_ANALYTICS=1"
log "Configuring Homebrew analytics opt-out in $BASHRC..."
if grep -qF "$HOMEBREW_LINE" "$BASHRC" 2>/dev/null; then
  log "Already present, skipping: $HOMEBREW_LINE"
else
  echo "$HOMEBREW_LINE" >> "$BASHRC"
  log "Added: $HOMEBREW_LINE"
fi

# Disable terminal flow control (enables CTRL+S for forward history search)
FLOW_CONTROL_LINE="stty -ixon"
log "Configuring terminal flow control in $BASHRC..."
if grep -qF "$FLOW_CONTROL_LINE" "$BASHRC" 2>/dev/null; then
  log "Already present, skipping: $FLOW_CONTROL_LINE"
else
  echo "$FLOW_CONTROL_LINE" >> "$BASHRC"
  log "Added: $FLOW_CONTROL_LINE"
fi

# Eternal bash history
HISTORY_LINES=(
  "export HISTFILESIZE=999999"
  "export HISTSIZE=999999"
  'export HISTTIMEFORMAT="[%F %T] "'
  "export HISTFILE=~/.bash_eternal_history"
  'PROMPT_COMMAND="history -a; $PROMPT_COMMAND"'
)
log "Configuring eternal bash history in $BASHRC..."
for line in "${HISTORY_LINES[@]}"; do
  if grep -qF "$line" "$BASHRC" 2>/dev/null; then
    log "Already present, skipping: $line"
  else
    echo "$line" >> "$BASHRC"
    log "Added: $line"
  fi
done

# asdf shell integration
ASDF_SOURCE='. "$HOME/.asdf/asdf.sh"'
log "Configuring asdf shell integration in $BASHRC..."
if grep -qF "$ASDF_SOURCE" "$BASHRC" 2>/dev/null; then
  log "asdf shell integration already in $BASHRC, skipping."
else
  echo "$ASDF_SOURCE" >> "$BASHRC"
  log "Added asdf shell integration to $BASHRC."
fi

log "Done."
