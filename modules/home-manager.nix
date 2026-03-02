{
  self,
  newSubcommandOptions,
  mkTemplateConfig,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  templates = config.programs.direnv.new.templates;
  defaultTemplate = config.programs.direnv.new.defaultTemplate;
  templateConfig = mkTemplateConfig templates defaultTemplate;
in {
  options = newSubcommandOptions;

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
}
