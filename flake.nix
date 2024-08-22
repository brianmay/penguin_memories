{
  description = "Photo Database";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-24.05"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
    devenv = { url = "github:cachix/devenv"; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, devenv }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (pkgs.lib) optional optionals;
        pkgs = nixpkgs.legacyPackages.${system};

        elixir = pkgs.beam.packages.erlang.elixir;
        beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang;

        src = ./.;
        version = "0.0.0";
        pname = "penguin_memories";

        mixFodDeps = beamPackages.fetchMixDeps {
          TOP_SRC = src;
          pname = "${pname}-mix-deps";
          inherit src version;
          hash = "sha256-1wbiuDQHQj6QKwKacBgsG2qaPlrCYv+XbuYStzqfIPI=";
          # hash = pkgs.lib.fakeHash;
        };

        nodejs = pkgs.nodejs;
        nodePackages =
          import assets/default.nix { inherit pkgs system nodejs; };

        pkg = beamPackages.mixRelease {
          TOP_SRC = src;
          inherit pname version elixir src mixFodDeps;

          postBuild = ''
            ln -sf ${mixFodDeps}/deps deps
            ln -sf ${nodePackages.nodeDependencies}/lib/node_modules assets/node_modules
            export PATH="${nodePackages.nodeDependencies}/bin:$PATH"
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
          modules = [{
            enterShell = ''
              export HTTP_URL="http://localhost:6001"
              export PORT="6001"
              export RELEASE_TMP=/tmp

              export DATABASE_URL_TEST="postgres://penguin_memories:your_secure_password_here@localhost:6000/penguin_memories_test"
              export DATABASE_URL="postgres://penguin_memories:your_secure_password_here@localhost:6000/penguin_memories"
              export IMAGE_DIR="/tmp/images"
            '';
            packages = with pkgs;
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
              ] ++ optional stdenv.isLinux inotify-tools
              ++ optional stdenv.isDarwin terminal-notifier
              ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
                CoreFoundation
                CoreServices
              ]);
            services.postgres = {
              enable = true;
              package = pkgs.postgresql_15.withPackages (ps: [ ps.postgis ]);
              listen_addresses = "127.0.0.1";
              port = 6000;
              initialDatabases = [{ name = "penguin_memories"; }];
              initialScript = ''
                \c penguin_memories;
                CREATE USER penguin_memories with encrypted password 'your_secure_password_here';
                GRANT ALL PRIVILEGES ON DATABASE penguin_memories TO penguin_memories;
                ALTER USER penguin_memories WITH SUPERUSER;
              '';
            };
          }];
        };

      in {
        packages = {
          devenv-up = devShell.config.procfileScript;
          default = pkg;
        };
        inherit devShell;
      }) // {
        nixosModules.default = import ./module.nix { inherit self; };
      };
}
