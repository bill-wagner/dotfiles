# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a dotfiles repository for managing personal system configuration. The primary entry point is `install.sh`, which is intended to set up the environment by symlinking or copying configuration files.

## Structure

As the repo grows, typical dotfiles conventions to follow:
- Shell configs (`.bashrc`, `.zshrc`, `.bash_profile`) at the repo root or in a `shell/` directory
- Tool-specific configs in named subdirectories (e.g., `git/`, `vim/`, `tmux/`)
- `install.sh` handles linking configs to their expected locations in `$HOME`
