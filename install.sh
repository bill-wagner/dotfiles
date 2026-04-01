#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[install] $*"
}

# Homebrew
if command -v brew &>/dev/null; then
  log "Homebrew already installed, skipping."
else
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

log "Done."
