# direnv-new

A Nix flake that extends [direnv](https://direnv.net/) with a `new` subcommand for scaffolding `.envrc` files with templates and nix packages.

## Features

- 🚀 **Quick scaffolding**: Create `.envrc` files with a single command
- 📦 **Package management**: Add nix packages directly via CLI flags
- 📝 **Template support**: Define reusable templates via NixOS or Home Manager
- 🔄 **Flake integration**: Built-in support for `use flake`
- 🎯 **Smart defaults**: Auto-manages `.gitignore` entries for `.direnv/`
- ⌨️ **Bash completion**: Tab-complete packages and templates
- ⚙️ **Flexible**: Works standalone or integrated with system configuration

## Quick Start

### Using with Nix Flakes

```nix
{
  inputs.direnv-new.url = "github:yourusername/direnv-new";
  # ...
}
```

#### Home Manager

```nix
{
  imports = [ inputs.direnv-new.homeManagerModules.default ];

  programs.direnv.new = {
    enable = true;
    templates = {
      node = ''
        use nix -p nodejs_20
        layout node
      '';
      python = {
        content = ''
          use nix -p python312 python312Packages.pip
          layout python
        '';
      };
    };
    defaultTemplate = "node";
  };
}
```

#### NixOS

```nix
{
  imports = [ inputs.direnv-new.nixosModules.default ];

  programs.direnv.new = {
    enable = true;
    templates = {
      flake = ''
        use flake
      '';
    };
  };
}
```

### Standalone Usage

```bash
# Run directly with nix
nix run github:yourusername/direnv-new

# Or use in a dev shell
nix develop github:yourusername/direnv-new
```

## Usage

### Basic Commands

```bash
# Create a simple .envrc
direnv new

# Add nix packages
direnv new -p nodejs_20 -p yarn

# Use a template
direnv new -t python

# Use with flake
direnv new -f

# Combine options
direnv new -p postgresql -p redis -e -a
```

### Options

| Option                  | Description                               |
| ----------------------- | ----------------------------------------- |
| `-p, --package <pkg>`   | Add a nix package (repeatable)            |
| `-t, --template <name>` | Use a configured template                 |
| `-f, --flake`           | Add `use flake` directive                 |
| `-e, --edit`            | Open `.envrc` in `$EDITOR` after creation |
| `-a, --apply`           | Run `direnv allow` automatically          |
| `-s, --silent`          | Suppress package load messages            |
| `-c, --current`         | Include current path in load message      |
| `-u, --up`              | Source parent `.envrc` if it exists       |
| `-n, --no-shebang`      | Don't add shebang to `.envrc`             |
| `-d, --dry-run`         | Print to stdout instead of creating file  |
| `--no-ignore`           | Don't modify `.gitignore`                 |
| `--git`                 | Initialize git repo if missing            |
| `-h, --help`            | Show help message                         |

### Environment Variables

Configure default behavior via configuration files:

**System**: `/etc/direnv-new/config`  
**User**: `~/.config/direnv-new/config` (or `$XDG_CONFIG_HOME/direnv-new/config`)

```bash
# Set default template
DIRENV_NEW_DEFAULT_TEMPLATE="python"

# Disable .gitignore management
DIRENV_NEW_NO_IGNORE=true

# Auto-initialize git repos
DIRENV_NEW_CREATE_GIT=true

# Disable package autocomplete (improves performance)
DIRENV_NEW_AUTOCOMPLETE=false
```

When using NixOS or Home Manager modules, templates are automatically written to these config files.

## Examples

### Python Development

```bash
direnv new -p python312 -p python312Packages.pip -p python312Packages.pytest -e -a
```

Creates an `.envrc` with:

```bash
#!/usr/bin/env bash
use nix -p python312 python312Packages.pip python312Packages.pytest
echo "Direnv loaded with packages: { pkgs.python312 } { pkgs.python312Packages.pip } { pkgs.python312Packages.pytest }"
```

### Node.js with Template

Template definition (in NixOS/Home Manager):

```nix
programs.direnv.new.templates.node = ''
  use nix -p nodejs_20
  layout node

  export NODE_ENV=development
'';
```

Usage:

```bash
direnv new -t node -e -a
```

### Monorepo Subdirectory

```bash
cd packages/frontend
direnv new -u -p nodejs_20 -p yarn
```

The `-u` flag adds `source_up` to inherit the parent directory's `.envrc`.

### Flake Project

```bash
direnv new -f -e -a
```

Creates an `.envrc` with `use flake` and opens it for editing.

## Completions

Bash completion is automatically included when using the flake's package. It provides:

- **Command completions**: All flags and options
- **Package name completions**: Auto-complete nix packages (requires 3+ characters)
- **Template completions**: Auto-complete configured template names

To disable package name autocomplete (which can be slow):

```bash
echo 'DIRENV_NEW_AUTOCOMPLETE=false' >> ~/.config/direnv-new/config
```

## Development

### Building

```bash
# Build the package
nix build

# Run in development shell
nix develop

# Test the script
nix run . -- --help
```

### Project Structure

```
.
├── flake.nix              # Main flake definition
├── direnv-new.sh          # Core implementation
├── completions.bash       # Bash completion script
└── modules/
    ├── common.nix         # Shared module options
    ├── home-manager.nix   # Home Manager integration
    └── nixos.nix          # NixOS integration
```

## How It Works

1. **Dispatch wrapper**: The flake creates a `direnv` wrapper that intercepts the `new` subcommand
2. **Script execution**: `direnv new` calls the `direnv-new.sh` script
3. **Configuration loading**: Loads templates from system/user config files
4. **File generation**: Builds `.envrc` content based on flags and templates
5. **Post-processing**: Optionally updates `.gitignore`, opens editor, runs `direnv allow`

## License

MIT

## Contributing

Contributions welcome! Please open issues or pull requests.
