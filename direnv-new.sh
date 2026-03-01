#!/usr/bin/env bash
set -euo pipefail

# Load configuration
[[ -f "/etc/direnv-new/config" ]] && source "/etc/direnv-new/config"
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/direnv-new/config" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/direnv-new/config"

# Detect silent mode
_silent=false
[[ "${DIRENV_NEW_SILENT:-false}" == "true" ]] && _silent=true
[[ "${DIRENV_LOG_FORMAT+set}" == "set" && -z "${DIRENV_LOG_FORMAT:-}" ]] && _silent=true

log() { [[ "$_silent" != "true" ]] && echo "$@"; }

usage() {
  cat <<EOF
Usage: direnv new [-p package1] [-p package2] [-f] [-e] [-a] ...

Creates an .envrc file with optional nix packages.

Options:
  -p, --package <pkg>  Add a nix package (can be repeated)
  -f, --flake          Add 'use flake' directive
  -e, --edit           Open .envrc in \$EDITOR after creation
  -a, --apply          Run 'direnv allow' after creation
      --no-ignore      Do not write to .gitignore
      --git            Initialize a git repo if .git does not exist
  -h, --help           Show this help message
EOF
  exit 0
}

packages=()
use_flake=false open_editor=false auto_allow=false
no_ignore="${DIRENV_NEW_NO_IGNORE:-false}"
init_git="${DIRENV_NEW_CREATE_GIT:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--package) packages+=("${2:?Error: $1 requires a package name argument}"); shift 2;;
    -f|--flake) use_flake=true; shift;;
    -e|--edit) open_editor=true; shift;;
    -a|--apply) auto_allow=true; shift;;
    --no-ignore) no_ignore=true; shift;;
    --git) init_git=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

# Check if .envrc already exists
[[ -f .envrc ]] && { echo "Error: .envrc already exists in the current directory. Remove it first if you want to recreate it."; exit 1; }

# Build the .envrc content
envrc_content='#!/usr/bin/env bash'
if [[ ${#packages[@]} -gt 0 ]]; then
  envrc_content+=$'\n'"use nix -p ${packages[*]}"
  display_parts=""
  for pkg in "${packages[@]}"; do
    display_parts+="{ pkgs.${pkg} } "
  done
  envrc_content+=$'\n'"echo \"Direnv loaded: ${display_parts% }\""
fi
[[ "$use_flake" == true ]] && envrc_content+=$'\n'"use flake"

# Write .envrc
echo "$envrc_content" > .envrc
log "Created .envrc"

# Initialize git repo if --git flag was given
if [[ "$init_git" == true ]] && [[ ! -d .git ]]; then
  git init
  log "Initialized git repository"
fi

# Handle .gitignore if inside a git repo (unless --no-ignore)
if [[ "$no_ignore" == false ]] && git rev-parse --git-dir &>/dev/null; then
  gitignore_entry="/.direnv/*"
  if [[ -f .gitignore ]]; then
    grep -qxF "$gitignore_entry" .gitignore || { echo "" >> .gitignore; echo "$gitignore_entry" >> .gitignore; log "Appended $gitignore_entry to .gitignore"; }
  else
    echo "$gitignore_entry" > .gitignore
    log "Created .gitignore with $gitignore_entry"
  fi
fi

log "Done!"

# Open in editor if -e flag was given
if [[ "$open_editor" == true ]]; then
  if [[ -z "${EDITOR:-}" ]]; then
    echo "Warning: \$EDITOR is not set. Cannot open .envrc."
  else
    "$EDITOR" .envrc
  fi
fi

# Run direnv allow if -a/--apply flag was given
if [[ "$auto_allow" == true ]]; then
  log "Running 'direnv allow'..."
  direnv allow
else
  log "Run 'direnv allow' to activate."
fi
