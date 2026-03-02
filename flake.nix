{
  description = "direnv with a 'new' subcommand for scaffolding .envrc files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = flake-utils.lib.defaultSystems;
    moduleCommon = import ./modules/common.nix {lib = nixpkgs.lib;};
    nixosDirenvModule = import ./modules/nixos.nix {
      inherit self;
      inherit (moduleCommon) newSubcommandOptions mkTemplateConfig;
    };
    homeManagerDirenvModule = import ./modules/home-manager.nix {
      inherit self;
      inherit (moduleCommon) newSubcommandOptions mkTemplateConfig;
    };
  in
    {
      homeManagerModules.default = homeManagerDirenvModule;
      nixosModules.default = nixosDirenvModule;
    }
    // flake-utils.lib.eachSystem systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        direnv-new-script =
          pkgs.writeShellScriptBin "direnv-new"
          (builtins.readFile ./direnv-new.sh);

        direnv-dispatch = pkgs.writeShellScriptBin "direnv" ''
          if [[ "''${1:-}" == "new" ]]; then
            shift
            exec ${direnv-new-script}/bin/direnv-new "$@"
          else
            exec ${pkgs.direnv}/bin/direnv "$@"
          fi
        '';

        completions = pkgs.runCommand "direnv-new-completions" {} ''
          mkdir -p $out/share/bash-completion/completions
          cp ${./completions.bash} $out/share/bash-completion/completions/direnv
        '';

        direnv-combined = pkgs.symlinkJoin {
          name = "direnv";
          meta.mainProgram = "direnv";
          paths = [
            direnv-dispatch
            completions
          ];
        };
      in {
        packages = {
          direnv-new = direnv-new-script;
          direnv = direnv-combined;
          default = direnv-combined;
        };

        apps.default = {
          type = "app";
          program = "${direnv-combined}/bin/direnv";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [direnv-combined];
        };
      }
    );
}
