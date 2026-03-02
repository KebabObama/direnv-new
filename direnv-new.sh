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
  -s, --silent         Suppress package messages
  -c, --current        Use current path in message
  -u, --up             Add source up to parent .envrc if exists
  -n, --no-shebang     Do not add shebang to .envrc
  -d, --dry-run        Write .envrc to stdout instead of file
      --no-ignore      Do not modify .gitignore
      --git            Initialize git repo if missing
  -h, --help           Show this help
EOF
  exit 0
}

if [[ "$dry_run" != true && -f .envrc ]]; then
  echo "Error: .envrc already exists."
  exit 1
fi

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

packages=()
dry_run=false
use_flake=false
current=false
source_up=false
open_editor=false
no_shebang=false
auto_allow=false
silent=false
no_ignore="${DIRENV_NEW_NO_IGNORE:-false}"
init_git="${DIRENV_NEW_CREATE_GIT:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage;;
    -p|--package)
      [[ -z "${2:-}" ]] && { echo "Error: $1 requires argument"; exit 1; }
      packages+=("$2"); shift 2;;
    -f|--flake) use_flake=true;shift;;
    -e|--edit) open_editor=true; shift;;
    -a|--apply) auto_allow=true; shift;;
    -s|--silent) silent=true; shift;;
    -c|--current) current=true; shift;;
    -u|--up) source_up=true; shift;;
    -n|--no-shebang) no_shebang=true; shift;;
    -d|--dry-run) dry_run=true; shift;;
    --no-ignore) no_ignore=true; shift;;
    --git) init_git=true; shift;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

# -----------------------------------------------------------------------------
# Build .envrc
# -----------------------------------------------------------------------------

if [[ "$no_shebang" != true ]]; then
  envrc_content='#!/usr/bin/env bash'
  envrc_content+=$'\n'
fi

if [[ "$source_up" == true ]]; then
  envrc_content+=$'\n'
  envrc_content+=$'\n# Inherit parent .envrc if it exists'
  envrc_content+=$'\n'"if command -v source_up >/dev/null 2>&1; then"
  envrc_content+=$'\n  source_up || true'
  envrc_content+=$'\nfi'
fi

if [[ ${#packages[@]} -gt 0 ]]; then
  envrc_content+=$'\n'"use nix -p ${packages[*]}"
  display_parts=""
  for pkg in "${packages[@]}"; do
    display_parts+="{ pkgs.${pkg} } "
  done
  if [[ "$silent" == false ]]; then
    if [[ "$current" == true ]]; then
      envrc_content+=$'\n'"echo \"Direnv loaded in $(pwd) with packages: ${display_parts% }\""
    else
      envrc_content+=$'\n'"echo \"Direnv loaded\""
    fi
  fi
else
  if [[ "$silent" == false ]]; then
    if [[ "$current" == true ]]; then
      envrc_content+=$'\n'"echo \"Direnv loaded in $(pwd)\""
    else
      envrc_content+=$'\n'"echo \"Direnv loaded\""
    fi
  fi
fi

if [[ "$use_flake" == true ]]; then
  envrc_content+=$'\n'"use flake"
fi

# -----------------------------------------------------------------------------
# Write file
# -----------------------------------------------------------------------------

if [[ "$dry_run" == true ]]; then
  echo "$envrc_content"
else
  echo "$envrc_content" > .envrc
fi

# -----------------------------------------------------------------------------
# Git initialization
# -----------------------------------------------------------------------------

if [[ "$dry_run" != true && "$init_git" == true ]]; then
  if [[ ! -d .git ]]; then
    git init >/dev/null 2>&1
  fi
fi

# -----------------------------------------------------------------------------
# .gitignore handling
# -----------------------------------------------------------------------------

if [[ "$dry_run" != true && "$no_ignore" == false ]] && git rev-parse --git-dir &>/dev/null; then  entry="/.direnv"
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

if [[ "$dry_run" != true && "$open_editor" == true ]]; then
  if [[ -n "${EDITOR:-}" ]]; then
    "$EDITOR" .envrc
  else
    echo "Warning: \$EDITOR not set."
  fi
fi

# -----------------------------------------------------------------------------
# Optional allow
# -----------------------------------------------------------------------------

if [[ "$dry_run" != true && "$auto_allow" == true ]]; then
  direnv allow
fi