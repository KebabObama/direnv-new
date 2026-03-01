#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration loading
# -----------------------------------------------------------------------------

_sys_config="/etc/direnv-new/config"
[[ -f "$_sys_config" ]] && source "$_sys_config"

_user_config="${XDG_CONFIG_HOME:-$HOME/.config}/direnv-new/config"
[[ -f "$_user_config" ]] && source "$_user_config"

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: direnv new [options]

Creates an .envrc file with optional nix packages.

Options:
  -p, --package <pkg>  Add a nix package (repeatable)
  -f, --flake          Add 'use flake'
  -e, --edit           Open .envrc in \$EDITOR
  -a, --apply          Run 'direnv allow' after creation
      --no-ignore      Do not modify .gitignore
      --git            Initialize git repo if missing
  -h, --help           Show this help
EOF
  exit 0
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

packages=()
use_flake=false
open_editor=false
auto_allow=false
no_ignore="${DIRENV_NEW_NO_IGNORE:-false}"
init_git="${DIRENV_NEW_CREATE_GIT:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--package)
      [[ -z "${2:-}" ]] && { echo "Error: $1 requires argument"; exit 1; }
      packages+=("$2")
      shift 2
      ;;
    -f|--flake)
      use_flake=true
      shift
      ;;
    -e|--edit)
      open_editor=true
      shift
      ;;
    -a|--apply)
      auto_allow=true
      shift
      ;;
    --no-ignore)
      no_ignore=true
      shift
      ;;
    --git)
      init_git=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Safety checks
# -----------------------------------------------------------------------------

if [[ -f .envrc ]]; then
  echo "Error: .envrc already exists."
  exit 1
fi

# -----------------------------------------------------------------------------
# Build .envrc
# -----------------------------------------------------------------------------

envrc_content='#!/usr/bin/env bash'
envrc_content+=$'\n'

if [[ ${#packages[@]} -gt 0 ]]; then
  pkg_list="${packages[*]}"
  envrc_content+=$'\n'"use nix -p ${pkg_list}"
fi

if [[ "$use_flake" == true ]]; then
  envrc_content+=$'\n'"use flake"
fi

# -----------------------------------------------------------------------------
# Write file
# -----------------------------------------------------------------------------

echo "$envrc_content" > .envrc

# -----------------------------------------------------------------------------
# Git initialization
# -----------------------------------------------------------------------------

if [[ "$init_git" == true ]]; then
  if [[ ! -d .git ]]; then
    git init >/dev/null 2>&1
  fi
fi

# -----------------------------------------------------------------------------
# .gitignore handling
# -----------------------------------------------------------------------------

if [[ "$no_ignore" == false ]] && git rev-parse --git-dir &>/dev/null; then
  entry="/.direnv"

  if [[ -f .gitignore ]]; then
    if ! grep -qxF "$entry" .gitignore; then
      {
        echo ""
        echo "$entry"
      } >> .gitignore
    fi
  else
    echo "$entry" > .gitignore
  fi
fi

# -----------------------------------------------------------------------------
# Optional editor
# -----------------------------------------------------------------------------

if [[ "$open_editor" == true ]]; then
  if [[ -n "${EDITOR:-}" ]]; then
    "$EDITOR" .envrc
  else
    echo "Warning: \$EDITOR not set."
  fi
fi

# -----------------------------------------------------------------------------
# Optional allow
# -----------------------------------------------------------------------------

if [[ "$auto_allow" == true ]]; then
  direnv allow
fi