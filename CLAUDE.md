# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository for setting up development environments on macOS and Linux (including Dev Containers). The primary entry point is `install.sh`.

## Running the Install Script

```bash
bash install.sh
```

The script is idempotent — safe to run multiple times. It logs every action with `[install]` prefixed messages.

## What install.sh Does

The script is split into two phases:

**Tool installation** (in order):
1. Linux prerequisites via `apt-get` (Linux only)
2. Homebrew — handles Apple Silicon (`/opt/homebrew`), Intel Mac (`/usr/local`), and Linux (`/home/linuxbrew/.linuxbrew`)
3. git-delta, ag (the_silver_searcher), oh-my-posh via Homebrew
4. oh-my-posh theme — copies `custom-atomic.omp.json` from the repo to `~/.oh-my-posh-custom-themes/`
5. asdf via git clone, pinned to v0.15.0 (last bash-based version)
6. asdf plugins and tool versions — installs from the repo's `.tool-versions`, copies it to `~/.tool-versions` as global fallback, then installs project-specific tools if a `.tool-versions` exists in the working directory
7. Global `.gitignore` — copies `.gitignore_global` to `~/.gitignore_global` and registers it via `git config --global core.excludesfile`
8. SSH key → macOS Keychain via `ssh-add --apple-use-keychain` (macOS only)

**`.bashrc` configuration** (appended in this order, which matters):
1. Homebrew `shellenv` (PATH setup)
2. asdf shell integration (PATH setup)
3. oh-my-posh init — must come after Homebrew is on PATH
4. Shell aliases (`ls`, `ll`, `l`, `grep`)
5. `HOMEBREW_NO_ANALYTICS=1`
6. `stty -ixon` (flow control, enables CTRL+S forward history search)
7. Eternal bash history settings

All `.bashrc` additions use `grep -xF` (exact whole-line match) to avoid matching commented-out example lines in the default `.bashrc`.

## Key Files

- `.tool-versions` — default asdf tool versions used as the system-wide global fallback (`~/.tool-versions`)
- `.gitignore_global` — global gitignore (Vim swap files, macOS artifacts); registered via `git config`
- `custom-atomic.omp.json` — oh-my-posh theme file (not yet added to repo; install.sh warns if missing)

## Dev Container Usage

This repo is intended to be used as a dotfiles repo in Dev Containers via `postCreateCommand`. When run from a project workspace, `install.sh` will install both the default tools (from this repo's `.tool-versions`) and any project-specific tools (from the workspace's `.tool-versions`).

The `bypassPermissions` Claude Code setting for Dev Containers belongs in a `post-start.sh` script, not here.
