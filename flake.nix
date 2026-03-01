{
  description = "direnv with a 'new' subcommand for scaffolding .envrc files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        direnv-new-script = pkgs.writeShellScriptBin "direnv-new" (builtins.readFile ./direnv-new.sh);
        direnv-wrapped = pkgs.writeShellScriptBin "direnv" ''
          if [[ "''${1:-}" == "new" ]]; then
            shift
            exec ${direnv-new-script}/bin/direnv-new "$@"
          else
            exec ${pkgs.direnv}/bin/direnv "$@"
          fi
        '';

        direnv-combined = pkgs.symlinkJoin {
          name = "direnv";
          paths = [
            direnv-wrapped
            direnv-new-script
          ];
        };
      in {
        packages = {
          direnv-new = direnv-new-script;
          direnv = direnv-combined;
          default = direnv-combined;
        };

        apps = {
          direnv = {
            type = "app";
            program = "${direnv-combined}/bin/direnv";
          };
          direnv-new = {
            type = "app";
            program = "${direnv-combined}/bin/direnv-new";
          };
          default = {
            type = "app";
            program = "${direnv-combined}/bin/direnv";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [direnv-combined];
        };
      }
    );
}
