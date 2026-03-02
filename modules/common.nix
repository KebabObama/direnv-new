{lib}: {
  newSubcommandOptions = {
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

  mkTemplateConfig = templates:
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
}
