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

    # ----------------------------------------
    # Shared module (works for NixOS + HM)
    # ----------------------------------------
    direnvModule = {
      config,
      lib,
      pkgs,
      ...
    }: {
      options.programs.direnv.new.enable =
        lib.mkEnableOption "direnv 'new' subcommand";

      config = lib.mkIf config.programs.direnv.new.enable {
        programs.direnv = {
          enable = true;
          package =
            lib.mkDefault self.packages.${pkgs.system}.default;
          nix-direnv.enable = lib.mkDefault true;
        };
      };
    };
  in
    {
      homeManagerModules.default = direnvModule;
      nixosModules.default = direnvModule;
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
