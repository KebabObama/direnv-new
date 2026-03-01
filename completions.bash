# Bash completion for direnv-new and 'direnv new'

_direnv_new_completions() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  opts="-p --package -f --flake -e --edit -a --apply --no-ignore --git -h --help"

  case "$prev" in
    -p|--package)
      # Complete with available nix packages if nix is available
      if command -v nix &>/dev/null; then
        local query="${cur:-}"
        if [[ -n "$query" ]]; then
          local pkgs
          pkgs=$(nix-env -qaP --no-name 2>/dev/null | grep -i "^nixpkgs\.$query" | sed 's/^nixpkgs\.//' | head -20)
          COMPREPLY=( $(compgen -W "$pkgs" -- "$cur") )
        fi
      fi
      return
      ;;
  esac

  COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}

# Completion for standalone direnv-new command
complete -F _direnv_new_completions direnv-new

# Completion for 'direnv new ...' via the direnv wrapper
_direnv_completions() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"

  # If the second word is "new" or we're completing the second word
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    # Complete subcommands: offer "new" alongside direnv's own subcommands
    local direnv_cmds
    direnv_cmds=$(direnv --help 2>&1 | grep -oP '^\s+\K\w+' | head -30)
    COMPREPLY=( $(compgen -W "new $direnv_cmds" -- "$cur") )
    return
  fi

  if [[ "${COMP_WORDS[1]}" == "new" ]]; then
    # Delegate to direnv-new completion logic
    local opts="-p --package -f --flake -e --edit -a --apply --no-ignore --git -h --help"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in
      -p|--package)
        if command -v nix &>/dev/null; then
          local query="${cur:-}"
          if [[ -n "$query" ]]; then
            local pkgs
            pkgs=$(nix-env -qaP --no-name 2>/dev/null | grep -i "^nixpkgs\.$query" | sed 's/^nixpkgs\.//' | head -20)
            COMPREPLY=( $(compgen -W "$pkgs" -- "$cur") )
          fi
        fi
        return
        ;;
    esac
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return
  fi

  # Fall through: let default direnv completion handle it if available
}

complete -F _direnv_completions direnv
