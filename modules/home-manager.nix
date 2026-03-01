{
  config,
  lib,
  pkgs,
  self,
  ...
}: {
  options.programs.direnv.new.enable =
    lib.mkEnableOption "direnv 'new' subcommand";

  config = lib.mkIf config.programs.direnv.new.enable {
    programs.direnv = {
      enable = true;
      package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      nix-direnv.enable = lib.mkDefault true;
    };
  };
}
