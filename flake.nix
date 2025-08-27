{
  description = "Photo Database";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.05";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    devenv = {
      url = "github:cachix/devenv";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      devenv,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        inherit (pkgs.lib) optional optionals;
        pkgs = nixpkgs.legacyPackages.${system};

        elixir = pkgs.beam.packages.erlang_26.elixir_1_18;
        beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang_26;

        src = ./.;
        version = "0.0.0";
        pname = "penguin_memories";

        mixFodDeps = beamPackages.fetchMixDeps {
          TOP_SRC = src;
          pname = "${pname}-mix-deps";
          inherit src version;
          hash = "sha256-GIOyxslX8PUK6RY+pfLXLnV43A2LJPRDSOxw1uWZAio=";
          # hash = pkgs.lib.fakeHash;
        };

        nodejs = pkgs.nodejs;
        nodePackages = pkgs.buildNpmPackage {
          name = "penguin_memories_assets";
          src = ./assets;
          npmDepsHash = "sha256-FFUxj7UCT8upNl1vbwxSTU6ZnL1yUOucVvNerAUhTRg=";
          dontNpmBuild = true;
          inherit nodejs;

          nativeBuildInputs = [
            (pkgs.python3.withPackages (ps: [ ps.setuptools ])) # Used by gyp
          ];

          installPhase = ''
            mkdir $out
            cp -r node_modules $out
            ln -s $out/node_modules/.bin $out/bin

            rm $out/node_modules/phoenix
            ln -s ${mixFodDeps}/phoenix $out/node_modules

            rm $out/node_modules/phoenix_html
            ln -s ${mixFodDeps}/phoenix_html $out/node_modules

            rm $out/node_modules/phoenix_live_view
            ln -s ${mixFodDeps}/phoenix_live_view $out/node_modules
          '';
        };

        pkg = beamPackages.mixRelease {
          TOP_SRC = src;
          inherit
            pname
            version
            elixir
            src
            mixFodDeps
            ;

          postBuild = ''
            ln -sf ${mixFodDeps}/deps deps
            ln -sf ${nodePackages}/node_modules assets/node_modules
            export PATH="${nodePackages}/bin:$PATH"
            ${nodejs}/bin/npm run deploy --prefix ./assets

            # for external task you need a workaround for the no deps check flag
            # https://github.com/phoenixframework/phoenix/issues/2690
            mix do deps.loadpaths --no-deps-check, phx.digest
            mix phx.digest --no-deps-check
          '';
        };

        psql = pkgs.writeShellScriptBin "pm_psql" ''
          exec "${pkgs.postgresql}/bin/psql" "$DATABASE_URL" "$@"
        '';

        devShell = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              enterShell = ''
                export HTTP_URL="http://localhost:6001"
                export PORT="6001"
                export RELEASE_TMP=/tmp

                export DATABASE_URL_TEST="postgres://penguin_memories:your_secure_password_here@localhost:6000/penguin_memories_test"
                export DATABASE_URL="postgres://penguin_memories:your_secure_password_here@localhost:6000/penguin_memories"
                export IMAGE_DIR="/tmp/images"
              '';
              packages =
                with pkgs;
                [
                  psql
                  elixir
                  elixir_ls
                  glibcLocales
                  node2nix
                  nodejs
                  exiftool
                  fbida
                  imagemagick
                  ffmpeg-headless
                  libraw
                  pkgs.prefetch-npm-deps
                ]
                ++ optional stdenv.isLinux inotify-tools
                ++ optional stdenv.isDarwin terminal-notifier
                ++ optionals stdenv.isDarwin (
                  with darwin.apple_sdk.frameworks;
                  [
                    CoreFoundation
                    CoreServices
                  ]
                );
              services.postgres = {
                enable = true;
                package = pkgs.postgresql_15.withPackages (ps: [ ps.postgis ]);
                listen_addresses = "127.0.0.1";
                port = 6000;
                initialDatabases = [ { name = "penguin_memories"; } ];
                initialScript = ''
                  \c penguin_memories;
                  CREATE USER penguin_memories with encrypted password 'your_secure_password_here';
                  ALTER DATABASE penguin_memories OWNER TO penguin_memories;
                  ALTER USER penguin_memories WITH SUPERUSER;
                '';
              };
            }
          ];
        };

        test = pkgs.nixosTest {
          name = "penguin_memories";
          nodes.machine =
            { ... }:
            {
              imports = [
                self.nixosModules.default
              ];
              services.penguin_memories = {
                enable = true;
                http_url = "http://localhost:4000";
                port = 4000;
                secrets = pkgs.writeText "secrets.txt" ''
                  export RELEASE_COOKIE="12345678901234567890123456789012345678901234567890123456"
                  export DATABASE_URL="postgres://penguin_memories:your_secure_password_here@localhost/penguin_memories"
                  export GUARDIAN_SECRET="1234567890123456789012345678901234567890123456789012345678901234"
                  export SECRET_KEY_BASE="1234567890123456789012345678901234567890123456789012345678901234"
                  export SIGNING_SALT="12345678901234567890123456789012"
                  export OIDC_DISCOVERY_URL="http://localhost"
                  export OIDC_CLIENT_ID="photos"
                  export OIDC_CLIENT_SECRET="12345678901234567890123456789012"
                  export OIDC_AUTH_SCOPE="openid profile groups"
                '';
              };
              system.stateVersion = "24.05";

              services.postgresql = {
                enable = true;
                package = pkgs.postgresql_15;
                extraPlugins = ps: [ ps.postgis ];
                initialScript = pkgs.writeText "init.psql" ''
                  CREATE DATABASE penguin_memories;
                  CREATE USER penguin_memories with encrypted password 'your_secure_password_here';
                  ALTER DATABASE penguin_memories OWNER TO penguin_memories;
                  ALTER USER penguin_memories WITH SUPERUSER;
                '';
              };
            };

          testScript = ''
            machine.wait_for_unit("penguin_memories.service")
            machine.wait_for_open_port(4000)
            machine.succeed("${pkgs.curl}/bin/curl --fail -v http://localhost:4000/_health")
          '';
        };
      in
      {
        checks.nixosModules = test;
        packages = {
          devenv-up = devShell.config.procfileScript;
          default = pkg;
        };
        inherit devShell;
      }
    )
    // {
      nixosModules.default = import ./module.nix { inherit self; };
    };
}
