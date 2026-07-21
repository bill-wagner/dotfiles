# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository for setting up development environments on macOS, Linux (including Dev Containers), and Windows (MSYS2). The primary entry point is `install.sh`.

## Running the Install Script

```bash
bash install.sh
```

The script is idempotent — safe to run multiple times. It logs every action with `[install]` prefixed messages.

## What install.sh Does

`set -euo pipefail` means any failed command aborts the script. An `ERR` trap (`handle_failure`)
writes a timestamped line to `~/.dotfiles-install-failed` and prints a loud banner whenever that
happens; the marker is removed on a clean run. A `.bashrc` snippet (item 2 below) checks for that
marker on every new shell, so a failed run stays visible until it's fixed and re-run — not just
inferred later from a missing oh-my-posh prompt.

Because of this, the **`.bashrc` configuration** section is deliberately sandwiched inside tool
installation, *before* the `asdf install` step — the one most likely to fail (a tool compiling
from source) — so a failure there still leaves a working shell.

**Tool installation, part 1** (in order):
1. MSYS2 environment variables — sets `MSYS2_PATH_TYPE=inherit`, `MSYS=winsymlinks:nativestrict`, and `CLAUDE_CODE_GIT_BASH_PATH` via `setx` (MSYS2 only)
2. Linux prerequisites via `apt-get` (Linux only)
3. Homebrew — handles Apple Silicon (`/opt/homebrew`), Intel Mac (`/usr/local`), and Linux (`/home/linuxbrew/.linuxbrew`); skipped on MSYS2
4. git-delta — via pacman on MSYS2, Homebrew otherwise
5. GitHub CLI (`gh`) — via pacman on MSYS2, Homebrew otherwise
6. JFrog CLI (`jf`) — downloaded from releases.jfrog.io on MSYS2, Homebrew otherwise
7. ag (the_silver_searcher) — via pacman on MSYS2, Homebrew otherwise
8. circleci CLI — downloaded from GitHub releases on MSYS2, Homebrew otherwise
9. Additional MSYS2 packages — `bash-completion`, `less`, `perl`, `python`, `rsync`, `vim`, `jq`, `ruby`, `go`, `sqlite3` (MSYS2 only)
10. MSYS2 tool equivalents for asdf-managed tools (MSYS2 only):
    - nodejs — warns to install the native Windows Node.js from nodejs.org (native installer preferred over pacman for addon compatibility and non-MSYS2 tool access); re-run after installing
    - yarn — `npm install -g yarn` if nodejs is present; warns to install nodejs first + re-run if not
    - postgres — warns to install from postgresql.org/download/windows; re-run after installing (this is independent of asdf — postgres is no longer asdf-managed on any platform, see Key Files below)
    - kubectl — downloaded directly from dl.k8s.io (latest stable)
    - helm — downloaded from get.helm.sh (latest release)
    - python, ruby, go, sqlite — covered by pacman in step 9 (not version-pinned, unlike asdf)
11. bash-completion — via Homebrew (macOS/Linux only; already included in MSYS2 step above)
12. oh-my-posh — via pacman on MSYS2, Homebrew otherwise
13. oh-my-posh theme — copies `custom-atomic.omp.json` from the repo to `~/.oh-my-posh-custom-themes/`
14. asdf via git clone, pinned to v0.15.0 (last bash-based version), plus asdf plugin registration (nodejs, python, ruby, sqlite, yarn, kubectl, golang, helm); skipped on MSYS2. Note: this only registers plugins — it does not install tool versions yet (see part 2)

**`.bashrc` configuration** (appended in this order, which matters):
1. MSYS2: `export HOME="$USERPROFILE"` so Windows-native tools find config in the right place
2. Install-failure warning — checks for `~/.dotfiles-install-failed` and warns on stderr if a previous run failed (all platforms)
3. MSYS2: sourcing warning written to `$USERPROFILE/.bashrc` and `.bash_profile` (those files are not auto-sourced by MSYS2)
4. MSYS2: `/mingw64/bin:/ucrt64/bin` prepended to PATH
5. Homebrew `shellenv` (PATH setup; macOS/Linux only)
6. bash-completion (sources the bash_completion script; path differs by OS)
7. asdf shell integration (PATH setup; macOS/Linux only)
8. oh-my-posh init — must come after Homebrew/asdf are on PATH
9. Shell aliases (`ls`, `ll`, `l`, `grep`)
10. `HOMEBREW_NO_ANALYTICS=1` (macOS/Linux only)
11. `stty -ixon` (flow control, enables CTRL+S forward history search)
12. Eternal bash history settings
13. MSYS2: SSH agent setup — reuses existing agent across terminal windows, starts a new one if needed
14. MSYS2: git-completion from Git for Windows — appended last so bash-completion cannot overwrite it

All `.bashrc` additions use `grep -xF` (exact whole-line match) to avoid matching commented-out example lines in the default `.bashrc`.

**Tool installation, part 2** (in order, after `.bashrc` configuration):
1. asdf tool installation — runs `asdf install` from the repo's `.tool-versions` (nodejs, python, ruby, sqlite, yarn, kubectl, golang, helm), copies it to `~/.tool-versions` as global fallback, then installs project-specific tools if a `.tool-versions` exists in the working directory (macOS/Linux only)
2. Global `.gitignore` — copies `.gitignore_global` to `~/.gitignore_global` and registers it via `git config --global core.excludesfile`
3. git-delta global config — sets `core.pager`, `interactive.diffFilter`, and `delta.*` options via `git config --global`
4. SSH key → macOS Keychain via `ssh-add --apple-use-keychain` (macOS only)
5. On success, removes `~/.dotfiles-install-failed` if present

## Key Files

- `.tool-versions` — default asdf tool versions used as the system-wide global fallback (`~/.tool-versions`). Does not include postgres — it was dropped because building it from source via asdf failed in Dev Containers (missing OpenSSL library path); MSYS2 users still get a native-installer nudge (see step 10 above)
- `.gitignore_global` — global gitignore (Vim swap files, macOS artifacts); registered via `git config`
- `custom-atomic.omp.json` — oh-my-posh theme file; install.sh warns if missing

## Dev Container Usage

This repo is intended to be used as a dotfiles repo in Dev Containers via `postCreateCommand`. When run from a project workspace, `install.sh` will install both the default tools (from this repo's `.tool-versions`) and any project-specific tools (from the workspace's `.tool-versions`).

The `bypassPermissions` Claude Code setting for Dev Containers belongs in a `post-start.sh` script, not here.
