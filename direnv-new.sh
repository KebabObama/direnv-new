#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: direnv new [-p package1] [-p package2] [-f] [-e] ..."
  echo ""
  echo "Creates an .envrc file with optional nix packages."
  echo ""
  echo "Options:"
  echo "  -p <package>   Add a nix package (can be repeated)"
  echo "  -f             Add 'use flake' directive"
  echo "  -e             Open .envrc in \$EDITOR after creation"
  echo "  -h             Show this help message"
  exit 0
}

packages=()
use_flake=false
open_editor=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p)
      if [[ -z "${2:-}" ]]; then
        echo "Error: -p requires a package name argument"
        exit 1
      fi
      packages+=("$2")
      shift 2
      ;;
    -f)
      use_flake=true
      shift
      ;;
    -e)
      open_editor=true
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

  envrc_content+=$'\n'"echo \"Direnv loaded: ${display_parts}\""
fi

if [[ "$use_flake" == true ]]; then
  envrc_content+=$'\n'"use flake"
fi

# Write .envrc
echo "$envrc_content" > .envrc
echo "Created .envrc"

# Handle .gitignore if inside a git repo
if git rev-parse --git-dir &>/dev/null; then
  gitignore_entry="/.direnv/*"
  if [[ -f .gitignore ]]; then
    if ! grep -qxF "$gitignore_entry" .gitignore; then
      echo "" >> .gitignore
      echo "$gitignore_entry" >> .gitignore
      echo "Appended $gitignore_entry to .gitignore"
    else
      echo ".gitignore already contains $gitignore_entry"
    fi
  else
    echo "$gitignore_entry" > .gitignore
    echo "Created .gitignore with $gitignore_entry"
  fi
fi

echo "Done! Run 'direnv allow' to activate."

# Open in editor if -e flag was given
if [[ "$open_editor" == true ]]; then
  if [[ -z "${EDITOR:-}" ]]; then
    echo "Warning: \$EDITOR is not set. Cannot open .envrc."
  else
    exec "$EDITOR" .envrc
  fi
fi
