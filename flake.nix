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
    # Shared options
    # ----------------------------------------
    newSubcommandOptions = lib: {
      programs.direnv.new = {
        enable = lib.mkEnableOption "direnv 'new' subcommand";

        templates = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.oneOf [
              lib.types.lines
              (lib.types.submodule {
                options.content = lib.mkOption {
                  type = lib.types.lines;
                  description = "Template content inserted into generated .envrc.";
                };
              })
            ]
          );
          default = {};
          example = {
            "flake" = {
              content = ''
                #!/usr/bin/env bash

                use flake
              '';
            };
          };
          description = "Named templates available via direnv new -t/--template.";
        };
      };
    };

    mkTemplateConfig = lib: templates:
      lib.optionalString (templates != {}) ''
        declare -Ag DIRENV_NEW_TEMPLATES
      ''
      + lib.concatStringsSep "\n" (lib.mapAttrsToList (
          name: template: let
            content =
              if builtins.isAttrs template
              then template.content
              else template;
          in "DIRENV_NEW_TEMPLATES[${lib.escapeShellArg name}]=${lib.escapeShellArg content}"
        )
        templates)
      + lib.optionalString (templates != {}) "\n";

    # ----------------------------------------
    # NixOS module
    # ----------------------------------------
    nixosDirenvModule = {
      config,
      lib,
      pkgs,
      ...
    }: let
      templates = config.programs.direnv.new.templates;
      templateConfig = mkTemplateConfig lib templates;
    in {
      options = newSubcommandOptions lib;

      config = lib.mkIf config.programs.direnv.new.enable {
        programs.direnv = {
          enable = true;
          package =
            lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
          nix-direnv.enable = lib.mkDefault true;
        };

        environment.etc = lib.mkIf (templateConfig != "") {
          "direnv-new/config".text = templateConfig;
        };
      };
    };

    # ----------------------------------------
    # Home Manager module
    # ----------------------------------------
    homeManagerDirenvModule = {
      config,
      lib,
      pkgs,
      ...
    }: let
      templates = config.programs.direnv.new.templates;
      templateConfig = mkTemplateConfig lib templates;
    in {
      options = newSubcommandOptions lib;

      config = lib.mkIf config.programs.direnv.new.enable {
        programs.direnv = {
          enable = true;
          package =
            lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
          nix-direnv.enable = lib.mkDefault true;
        };

        home.file = lib.mkIf (templateConfig != "") {
          ".config/direnv-new/config".text = templateConfig;
        };
      };
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
