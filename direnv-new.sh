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
  -p, --package <pkg>       Add a nix package (repeatable)
  -t, --template <name>     Use a configured template (defaults to \$DIRENV_NEW_DEFAULT_TEMPLATE)
  -x, --export [file]       Export variables via dotenv (default file: .env)
  -f, --flake               Add 'use flake'
  -e, --edit                Open .envrc in \$EDITOR
  -a, --apply               Run 'direnv allow' after creation
  -s, --silent              Suppress package messages
  -c, --current             Use current path in message
  -u, --up                  Add source up to parent .envrc if exists
  -n, --no-shebang          Do not add shebang to .envrc
  -d, --dry-run             Write .envrc to stdout instead of file
  -i, --ignore [type]       Skip adding to .gitignore [both|shell|folder] (default: both)
  -o, --once                Create hook that will run only once per session
      --git                 Initialize git repo if missing
  -h, --help                Show this help
EOF
  exit 0
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

packages=()
template_name="${DIRENV_NEW_DEFAULT_TEMPLATE:-}"
dry_run=false
use_flake=false
current=false
source_up=false
open_editor=false
no_shebang=false
auto_allow=false
silent=false
ignore_type=""
init_git="${DIRENV_NEW_CREATE_GIT:-false}"
once=false
use_export=false
export_file=".env"

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help) usage ;;
  -p | --package) 
    [[ -z "${2:-}" ]] && { echo "Error: $1 requires argument"; exit 1; }
    packages+=("$2"); shift 2 ;;
  -t | --template)
    [[ -z "${2:-}" ]] && { echo "Error: $1 requires argument"; exit 1; }
    template_name="$2"; shift 2 ;;
  -x | --export)
    use_export=true
    if [[ -n "${2:-}" && "$2" != -* ]]; then
      export_file="$2"
      shift 2
    else
      shift
    fi
    ;;
  -f | --flake) use_flake=true; shift ;;
  -e | --edit) open_editor=true; shift ;;
  -o | --once) once=true; shift ;;
  -a | --apply) auto_allow=true; shift ;;
  -s | --silent) silent=true; shift ;;
  -c | --current) current=true; shift ;;
  -u | --up) source_up=true; shift ;;
  -n | --no-shebang) no_shebang=true; shift ;;
  -d | --dry-run) dry_run=true; shift ;;
  -i | --ignore)
    if [[ -n "${2:-}" && "$2" != -* ]]; then
      ignore_type="$2"; shift 2
    else
      ignore_type="both"; shift
    fi
    if [[ "$ignore_type" != "both" && "$ignore_type" != "shell" && "$ignore_type" != "folder" ]]; then
      echo "Error: --ignore argument must be 'both', 'shell', or 'folder'"
      exit 1
    fi
    ;;
  --git) init_git=true; shift ;;
  *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ "$dry_run" != true && -f .envrc ]]; then
  echo "Error: .envrc already exists."
  exit 1
fi

template_content=""
if [[ -n "$template_name" ]]; then
  if declare -p DIRENV_NEW_TEMPLATES &>/dev/null; then
    if [[ -n "${DIRENV_NEW_TEMPLATES[$template_name]+_}" ]]; then
      template_content="${DIRENV_NEW_TEMPLATES[$template_name]}"
    else
      echo "Error: unknown template '$template_name'."
      if [[ ${#DIRENV_NEW_TEMPLATES[@]} -gt 0 ]]; then
        echo "Available templates: ${!DIRENV_NEW_TEMPLATES[*]}"
      fi
      exit 1
    fi
  else
    echo "Error: no templates configured."
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# Build .envrc
# -----------------------------------------------------------------------------

if [[ "$no_shebang" != true ]]; then
  envrc_content='#!/usr/bin/env bash'
  envrc_content+=$'\n'
fi

if [[ "$source_up" == true ]]; then
  envrc_content+=$'\n# Inherit parent .envrc if it exists'
  envrc_content+=$'\nsource_up >/dev/null 2>&1 || true'
  envrc_content+=$'\n'
fi

if [[ "$use_export" == true ]]; then
  envrc_content+=$'\nif [ -f '"$export_file"' ]; then'
  if [[ "$export_file" == ".env" ]]; then
    envrc_content+=$'\n  dotenv'
    envrc_content+=$'\nelse'
    envrc_content+=$'\n  echo "No .env file found. Copy .env.example to get started."'
  else
    envrc_content+=$'\n  dotenv '"$export_file"
    envrc_content+=$'\nelse'
    envrc_content+=$'\n  echo "No '"$export_file"' file found."'
  fi
  envrc_content+=$'\nfi'
  envrc_content+=$'\n'
fi

if [[ -n "$template_content" ]]; then
  envrc_content+=$'\n# Template: '"$template_name"
  envrc_content+=$'\n'"$template_content"
fi

if [[ ${#packages[@]} -gt 0 ]]; then
  envrc_content+=$'\n'"use nix -p ${packages[*]}"
  if [[ "$silent" == false ]]; then
    display_parts=""
    for pkg in "${packages[@]}"; do
      display_parts+="pkgs.${pkg} "
    done
    display_parts="{ ${display_parts% } }"
    if [[ "$current" == true ]]; then
      envrc_content+=$'\n'"echo \"Direnv loaded in \$(pwd) with packages: ${display_parts}\""
    else
      envrc_content+=$'\n'"echo \"Direnv loaded with packages: ${display_parts}\""
    fi
  fi
else
  if [[ "$silent" == false ]]; then
    if [[ "$current" == true ]]; then
      envrc_content+=$'\n'"echo \"Direnv loaded in \$(pwd)\""
    else
      envrc_content+=$'\n'"echo \"Direnv loaded\""
    fi
  fi
fi

if [[ "$use_flake" == true ]]; then
  envrc_content+=$'\n'"use flake"
fi

if [[ "$once" == true ]]; then
  envrc_content+=$'\n# Run once per machine boot'
  envrc_content+=$'\nDIRENV_NEW_BOOT_ID_FILE="/proc/sys/kernel/random/boot_id"'
  envrc_content+=$'\nDIRENV_NEW_STATE_FILE=".direnv/.last_boot_id"'
  envrc_content+=$'\nif [[ -f "$DIRENV_NEW_BOOT_ID_FILE" ]]; then'
  envrc_content+=$'\n  CURRENT_BOOT_ID="$(cat "$DIRENV_NEW_BOOT_ID_FILE")"'
  envrc_content+=$'\n  PREV_BOOT_ID=""'
  envrc_content+=$'\n  [[ -f "$DIRENV_NEW_STATE_FILE" ]] && PREV_BOOT_ID="$(cat "$DIRENV_NEW_STATE_FILE")"'
  envrc_content+=$'\n  if [[ "$CURRENT_BOOT_ID" != "$PREV_BOOT_ID" ]]; then'
  envrc_content+=$'\n    echo "Running one-time setup (new boot)..."'
  envrc_content+=$'\n    mkdir -p .direnv'
  envrc_content+=$'\n    echo "$CURRENT_BOOT_ID" > "$DIRENV_NEW_STATE_FILE"'
  envrc_content+=$'\n  fi'
  envrc_content+=$'\nfi'
fi

# -----------------------------------------------------------------------------
# Write file
# -----------------------------------------------------------------------------

if [[ "$dry_run" == true ]]; then
  echo "$envrc_content"
else
  echo "$envrc_content" >.envrc
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

if [[ "$dry_run" != true ]] && git rev-parse --git-dir &>/dev/null; then
  
  add_direnv=true
  add_envrc=true
  
  case "$ignore_type" in
    both) add_direnv=false; add_envrc=false;;
    shell) add_envrc=false;;
    folder) add_direnv=false;;
  esac
  
  if [[ "$add_direnv" == true ]]; then
    entry="/.direnv"
    if [[ -f .gitignore ]]; then
      if ! grep -qxF "$entry" .gitignore; then
        echo "$entry" >>.gitignore
      fi
    else
      echo "$entry" >.gitignore
    fi
  fi
  
  if [[ "$add_envrc" == true ]]; then
    entry="/.envrc"
    if [[ -f .gitignore ]]; then
      if ! grep -qxF "$entry" .gitignore; then
        echo "$entry" >>.gitignore
      fi
    else
      echo "$entry" >.gitignore
    fi
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

