{ self }:
{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.services.penguin_memories;

  system = pkgs.stdenv.system;
  penguin_memories_pkg = self.packages.${system}.default;

  private_locations = lib.concatMapStringsSep ";"
    (l: "${toString l.longitude},${toString l.latitude},${toString l.distance}")
    cfg.private_locations;

  wrapper = pkgs.writeShellScriptBin "penguin_memories" ''
    export PATH="$PATH:${pkgs.gawk}/bin"
    export RELEASE_TMP="${cfg.data_dir}/tmp"
    export HTTP_URL="${cfg.http_url}"
    export IMAGE_DIR="${cfg.image_dir}"
    export PORT="${toString (cfg.port)}"
    export PRIVATE_LOCATIONS="${private_locations}"
    . "${cfg.secrets}"

    mkdir -p "${cfg.data_dir}"
    mkdir -p "${cfg.data_dir}/tmp"
    exec "${penguin_memories_pkg}/bin/penguin_memories" "$@"
  '';

  locations = types.submodule {
    options = {
      longitude = mkOption { type = types.float; };
      latitude = mkOption { type = types.float; };
      distance = mkOption { type = types.int; };
    };
  };

in {
  options.services.penguin_memories = {
    enable = mkEnableOption "penguin_memories service";
    secrets = mkOption { type = types.path; };
    http_url = mkOption { type = types.str; };
    image_dir = mkOption { type = types.path; };
    private_locations = mkOption { type = types.listOf locations; };
    port = mkOption { type = types.int; };
    data_dir = mkOption {
      type = types.str;
      default = "/var/lib/penguin_memories";
    };
  };

  config = mkIf cfg.enable {
    users.users.penguin_memories = {
      isSystemUser = true;
      description = "PhoneDB user";
      group = "penguin_memories";
      createHome = true;
      home = "${cfg.data_dir}";
    };

    users.groups.penguin_memories = { };

    systemd.services.penguin_memories = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "penguin_memories";
        ExecStart = "${wrapper}/bin/penguin_memories start";
        ExecStop = "${wrapper}/bin/penguin_memories stop";
        ExecReload = "${wrapper}/bin/penguin_memories reload";
      };
    };
  };
}
