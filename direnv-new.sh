#!/usr/bin/env bash
set -euo pipefail

# Load configuration defaults
# System config (set by NixOS module)
_sys_config="/etc/direnv-new/config"
if [[ -f "$_sys_config" ]]; then
  # shellcheck source=/dev/null
  source "$_sys_config"
fi

# User config (set by home-manager module)
_user_config="${XDG_CONFIG_HOME:-$HOME/.config}/direnv-new/config"
if [[ -f "$_user_config" ]]; then
  # shellcheck source=/dev/null
  source "$_user_config"
fi

# Detect silent mode:
#   - Explicit DIRENV_NEW_SILENT=true (from config or env)
#   - programs.direnv.silent sets DIRENV_LOG_FORMAT=""
if [[ "${DIRENV_NEW_SILENT:-false}" == "true" ]] || \
   [[ "${DIRENV_LOG_FORMAT+set}" == "set" && -z "${DIRENV_LOG_FORMAT:-}" ]]; then
  _silent=true
else
  _silent=false
fi

log() {
  if [[ "$_silent" != "true" ]]; then
    echo "$@"
  fi
}

usage() {
  echo "Usage: direnv new [-p package1] [-p package2] [-f] [-e] [-a] ..."
  echo ""
  echo "Creates an .envrc file with optional nix packages."
  echo ""
  echo "Options:"
  echo "  -p, --package <pkg>  Add a nix package (can be repeated)"
  echo "  -f, --flake          Add 'use flake' directive"
  echo "  -e, --edit           Open .envrc in \$EDITOR after creation"
  echo "  -a, --apply          Run 'direnv allow' after creation"
  echo "      --no-ignore      Do not write to .gitignore"
  echo "      --git            Initialize a git repo if .git does not exist"
  echo "  -h, --help           Show this help message"
  exit 0
}

packages=()
use_flake=false
open_editor=false
auto_allow=false
no_ignore="${DIRENV_NEW_NO_IGNORE:-false}"
init_git="${DIRENV_NEW_CREATE_GIT:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--package)
      if [[ -z "${2:-}" ]]; then
        echo "Error: $1 requires a package name argument"
        exit 1
      fi
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

# Check if .envrc already exists
if [[ -f .envrc ]]; then
  echo "Error: .envrc already exists in the current directory."
  echo "Remove it first if you want to recreate it."
  exit 1
fi

# Build the .envrc content
envrc_content='#!/usr/bin/env bash'
envrc_content+=$'\n'

if [[ ${#packages[@]} -gt 0 ]]; then
  pkg_list="${packages[*]}"
  envrc_content+=$'\n'"use nix -p ${pkg_list}"

  # Build "{ pkgs.pkg1 } { pkgs.pkg2 } ..." display string
  display_parts=""
  for pkg in "${packages[@]}"; do
    display_parts+="{ pkgs.${pkg} } "
  done
  display_parts="${display_parts% }"  # trim trailing space

  envrc_content+=$'\n'"[[ \"\${DIRENV_LOG_FORMAT-unset}\" != \"\" ]] && echo \"Direnv loaded: ${display_parts}\""
fi

if [[ "$use_flake" == true ]]; then
  envrc_content+=$'\n'"use flake"
fi

# Write .envrc
echo "$envrc_content" > .envrc
log "Created .envrc"

# Initialize git repo if --git flag was given
if [[ "$init_git" == true ]]; then
  if [[ ! -d .git ]]; then
    git init
    log "Initialized git repository"
  else
    log "Git repository already exists"
  fi
fi

# Handle .gitignore if inside a git repo (unless --no-ignore)
if [[ "$no_ignore" == false ]] && git rev-parse --git-dir &>/dev/null; then
  gitignore_entry="/.direnv/*"
  if [[ -f .gitignore ]]; then
    if ! grep -qxF "$gitignore_entry" .gitignore; then
      echo "" >> .gitignore
      echo "$gitignore_entry" >> .gitignore
      log "Appended $gitignore_entry to .gitignore"
    else
      log ".gitignore already contains $gitignore_entry"
    fi
  else
    echo "$gitignore_entry" > .gitignore
    log "Created .gitignore with $gitignore_entry"
  fi
fi

log "Done!"

# Open in editor if -e flag was given (wait for editor to close)
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
