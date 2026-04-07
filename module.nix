{ self }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    mkEnableOption
    mkIf
    optional
    ;

  cfg = config.services.penguin_memories;

  system = pkgs.stdenv.hostPlatform.system;
  penguin_memories_pkg = self.packages.${system}.default;

  private_locations = lib.concatMapStringsSep ";" (
    l: "${toString l.longitude},${toString l.latitude},${toString l.distance}"
  ) cfg.private_locations;

  # Minimal wrapper: only loads secrets (for RELEASE_COOKIE) so that
  # commands like "remote", "rpc", and "eval" can authenticate to the
  # running daemon.  All other configuration lives in the systemd unit.
  wrapper = pkgs.writeShellScriptBin "penguin_memories" ''
    set -a
    . "${cfg.secrets}"
    set +a
    exec "${penguin_memories_pkg}/bin/penguin_memories" "$@"
  '';

  locations = types.submodule {
    options = {
      longitude = mkOption { type = types.float; };
      latitude = mkOption { type = types.float; };
      distance = mkOption { type = types.int; };
    };
  };
in
{
  options.services.penguin_memories = {
    enable = mkEnableOption "penguin_memories service";
    secrets = mkOption { type = types.path; };
    http_url = mkOption { type = types.str; };
    image_dir = mkOption {
      type = types.path;
      default = "/var/lib/penguin_memories";
    };
    private_locations = mkOption {
      type = types.listOf locations;
      default = [ ];
    };
    port = mkOption {
      type = types.int;
      default = 4000;
    };
    upload_staging_dir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Directory prefix that admin users may import from via the web UI. Set to null to disable the feature.";
    };
    data_dir = mkOption {
      type = types.str;
      default = "/var/lib/penguin_memories";
    };
  };

  config = mkIf cfg.enable {
    users.users.penguin_memories = {
      isSystemUser = true;
      description = "Penguin Memories user";
      group = "penguin_memories";
      createHome = true;
      home = "${cfg.data_dir}";
    };

    users.groups.penguin_memories = { };

    # Expose the wrapper system-wide so any user (including root) can run
    # "penguin_memories remote / rpc / eval" against the running daemon.
    environment.systemPackages = [ wrapper ];

    systemd.services.penguin_memories = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "postgresql.service" ];
      after = [
        "network.target"
        "postgresql.service"
      ];
      serviceConfig = {
        User = "penguin_memories";
        # Non-secret configuration is declared directly in the unit.
        Environment = [
          "PATH=${pkgs.gawk}/bin:${pkgs.coreutils}/bin"
          "RELEASE_TMP=${cfg.data_dir}/tmp"
          "HTTP_URL=${cfg.http_url}"
          "IMAGE_DIR=${cfg.image_dir}"
          "PORT=${toString cfg.port}"
          "PRIVATE_LOCATIONS=${private_locations}"
        ]
        ++ optional (cfg.upload_staging_dir != null) "UPLOAD_STAGING_DIR=${cfg.upload_staging_dir}";
        # Secrets (DATABASE_URL, RELEASE_COOKIE, …) come from a file that is
        # not world-readable, so they are not baked into the Nix store.
        EnvironmentFile = cfg.secrets;
        ExecStartPre = [
          # Ensure runtime directories exist before starting.
          "+${pkgs.coreutils}/bin/mkdir -p ${cfg.data_dir}/tmp"
          "${penguin_memories_pkg}/bin/penguin_memories eval \"PenguinMemories.Release.migrate\""
        ];
        ExecStart = "${penguin_memories_pkg}/bin/penguin_memories start";
        ExecStop = "${penguin_memories_pkg}/bin/penguin_memories stop";
        ExecReload = "${penguin_memories_pkg}/bin/penguin_memories reload";
      };
    };
  };
}
