{
  description = "Photo Database";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-26.05";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    devenv = {
      url = "github:cachix/devenv";
    };
    flockenzeit.url = "github:balsoft/flockenzeit";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      devenv,
      flockenzeit,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        inherit (pkgs.lib) optional optionals;
        pkgs = nixpkgs.legacyPackages.${system};

        elixir = pkgs.beam.packages.erlang_29.elixir_1_20;
        beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang_29;

        # rebar3 3.27 fails to compile under OTP 29 (new compiler warnings
        # are treated as errors in its build). Escripts built with OTP 28
        # run fine on OTP 29, so borrow them from the erlang_28 package set.
        rebarOverrides = {
          rebar = pkgs.beam.packages.erlang_28.rebar;
          rebar3 = pkgs.beam.packages.erlang_28.rebar3;
        };

        src = ./.;
        version = "0.0.0";
        pname = "penguin_memories";

        build_env = {
          BUILD_DATE = with flockenzeit.lib.splitSecondsSinceEpoch { } self.lastModified; "${F}T${T}${Z}";
          VCS_REF = "${self.shortRev or self.dirtyShortRev or "dirty"}";
        };

        mixFodDeps = (beamPackages.fetchMixDeps.override rebarOverrides) {
          TOP_SRC = src;
          pname = "${pname}-mix-deps";
          inherit src version;
          hash = "sha256-tNvtgeB2sVyhd5Uh4YhEcj5/4OzdiBzVjjPCd4G33nQ=";
          # hash = pkgs.lib.fakeHash;
        };

        nodejs = pkgs.nodejs;

        # assets/package-lock.json links phoenix, phoenix_html and
        # phoenix_live_view as `file:../deps/*`. That directory only exists in a
        # working tree after `mix deps.get`, so the already fetched mix deps are
        # substituted for them here. Every other dependency is fetched from the
        # integrity hashes in package-lock.json, which is why this needs no
        # aggregate hash of its own.
        npmSources = pkgs.importNpmLock {
          npmRoot = ./assets;
          packageSourceOverrides = {
            "node_modules/phoenix" = "${mixFodDeps}/phoenix";
            "node_modules/phoenix_html" = "${mixFodDeps}/phoenix_html";
            "node_modules/phoenix_live_view" = "${mixFodDeps}/phoenix_live_view";
          };
        };

        nodePackages = pkgs.importNpmLock.buildNodeModules {
          npmRoot = ./assets;
          inherit nodejs;
          derivationArgs = {
            pname = "${pname}-assets";
            inherit version;
            # Overrides the sources buildNodeModules would derive itself, so
            # that the phoenix packages resolve to mixFodDeps (see npmSources).
            npmDeps = npmSources;
            nativeBuildInputs = [
              (pkgs.python3.withPackages (ps: [ ps.setuptools ])) # Used by gyp
            ];
            postInstall = ''
              ln -s $out/node_modules/.bin $out/bin
            '';
          };
        };

        pkg = (beamPackages.mixRelease.override rebarOverrides) {
          TOP_SRC = src;
          inherit
            pname
            version
            elixir
            src
            mixFodDeps
            ;

          BUILD_DATE = build_env.BUILD_DATE;
          VCS_REF = build_env.VCS_REF;

          postBuild = ''
            ln -sf ${mixFodDeps}/deps deps
            ln -sf ${nodePackages}/node_modules assets/node_modules
            export PATH="${nodePackages}/bin:$PATH"
            ${nodejs}/bin/npm run deploy --prefix ./assets

            # for external task you need a workaround for the no deps check flag
            # https://github.com/phoenixframework/phoenix/issues/2690
            mix do deps.loadpaths --no-deps-check + phx.digest
          '';

          postInstall = ''
            # Fix rambo binary execute permission (nix store issue)
            chmod +x $out/lib/rambo-0.3.4/priv/rambo-linux
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
                export PORT="4000"
                export HTTP_URL="http://localhost:$PORT"
                export RELEASE_TMP=/tmp

                export DATABASE_URL_TEST="postgres://penguin_memories:your_secure_password_here@localhost:6000/penguin_memories_test"
                export DATABASE_URL="postgres://penguin_memories:your_secure_password_here@localhost:6000/penguin_memories"
                export IMAGE_DIR="/tmp/images"
                export UPLOAD_STAGING_DIR="/tmp/staging"
              '';
              packages =
                with pkgs;
                [
                  psql
                  elixir
                  elixir-ls
                  glibcLocales
                  nodejs
                  exiftool
                  fbida
                  imagemagick
                  ffmpeg-headless
                  libraw
                  pkgs.prefetch-npm-deps
                  pkgs.osv-scanner
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

        test = pkgs.testers.nixosTest {
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
                  RELEASE_COOKIE="12345678901234567890123456789012345678901234567890123456"
                  DATABASE_URL="postgres://penguin_memories:your_secure_password_here@localhost/penguin_memories"
                  GUARDIAN_SECRET="1234567890123456789012345678901234567890123456789012345678901234"
                  SECRET_KEY_BASE="1234567890123456789012345678901234567890123456789012345678901234"
                  SIGNING_SALT="12345678901234567890123456789012"
                  OIDC_DISCOVERY_URL="http://localhost"
                  OIDC_CLIENT_ID="photos"
                  OIDC_CLIENT_SECRET="12345678901234567890123456789012"
                  OIDC_AUTH_SCOPE="openid profile groups"
                '';
              };
              system.stateVersion = "24.05";

              services.postgresql = {
                enable = true;
                package = pkgs.postgresql_15;
                extensions = ps: [ ps.postgis ];
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

        # Refreshes the fixed-output hashes pinned in flake.nix.
        #
        # A fixed-output derivation is addressed by its hash alone, so a stale
        # hash resolves to the store path that was fetched for it earlier: the
        # build succeeds, the fetcher never runs and nothing reports a mismatch,
        # while the old content is silently used. Building and waiting for an
        # error therefore finds nothing. Each pinned hash is instead invalidated
        # on purpose, one at a time, and the hash the fetcher then reports is
        # written back. Every run consequently re-fetches, which is the price of
        # an answer that does not depend on what happens to sit in the store.
        #
        # The files to patch are looked up by their pinned hashes rather than
        # named here, so neither moving a module nor pinning a further
        # fixed-output derivation elsewhere needs a change to this script.
        updateNixHashes = pkgs.writeShellApplication {
          name = "update-nix-hashes";
          runtimeInputs = [
            pkgs.nix
            pkgs.coreutils
            pkgs.gawk
            pkgs.gnugrep
            pkgs.gnused
          ];
          text = ''
            # lib.fakeHash. Its output can never be a valid store path, so a
            # derivation pinned to it always runs and always reports what it got.
            # Assembled at run time rather than written out, so that the search
            # for pinned hashes below does not find this file's own placeholder.
            fake="sha256-$(printf 'A%.0s' {1..43})="

            # Anchored on the flake, because that is what the build resolves
            # against.
            if [ ! -f flake.nix ]; then
              echo "run this from the project root (no flake.nix here)" >&2
              exit 1
            fi

            log="$(mktemp)"
            patched="$(mktemp)"
            restore=1
            saved_files=()
            saved_copies=()

            save() {
              local file="$1" copy known
              for known in ''${saved_files[@]+"''${saved_files[@]}"}; do
                if [ "$known" = "$file" ]; then
                  return 0
                fi
              done
              copy="$(mktemp)"
              cp "$file" "$copy"
              saved_files+=("$file")
              saved_copies+=("$copy")
            }

            cleanup() {
              local i
              if [ "$restore" -eq 1 ] && [ ''${#saved_files[@]} -gt 0 ]; then
                echo "restoring the hashes this run had replaced" >&2
                for i in "''${!saved_files[@]}"; do
                  cat "''${saved_copies[$i]}" > "''${saved_files[$i]}"
                done
              fi
              rm -f "$log" "$patched" ''${saved_copies[@]+"''${saved_copies[@]}"}
            }
            trap cleanup EXIT

            # Writes through a temporary file rather than with sed -i, which is
            # not portable, and copies it back so the source file keeps its mode
            # instead of the one mktemp created.
            replace() {
              sed "s|$2|$3|" "$1" > "$patched"
              cat "$patched" > "$1"
            }

            mapfile -t pins < <(grep -Eo 'sha256-[A-Za-z0-9+/]{43}=' flake.nix module.nix | sort -u)
            if [ ''${#pins[@]} -eq 0 ]; then
              echo "no pinned hashes found in flake.nix" >&2
              exit 1
            fi

            for pin in "''${pins[@]}"; do
              file="''${pin%%:*}"
              hash="''${pin#*:}"

              # Two pins sharing one file and hash cannot be told apart once both
              # carry the placeholder, so refuse instead of updating them wrongly.
              occurrences="$(grep -cF "$hash" "$file")"
              if [ "$occurrences" -ne 1 ]; then
                echo "$file pins $hash on $occurrences lines, which cannot be updated independently" >&2
                exit 1
              fi

              save "$file"
              replace "$file" "$hash" "$fake"

              # --keep-going so that this fetch still finishes and reports its
              # hash when another fixed-output derivation mismatches first. That
              # happens whenever a second pinned hash is stale as well and its
              # output is not in the store, which is the normal state on a fresh
              # machine after a dependency bump.
              if nix build .#default --no-link --keep-going > "$log" 2>&1; then
                echo "expected $file to report a hash mismatch, but the build succeeded" >&2
                exit 1
              fi

              # Nix reports the pair as "specified: <hash>" followed by
              # "got: <hash>". With several mismatches in one log, taking the
              # first "got:" can pick another derivation's hash, so read the one
              # that follows the placeholder this iteration put in place.
              got="$(awk -v fake="$fake" '
                index($0, "specified:") && index($0, fake) { pending = 1; next }
                pending && index($0, "got:") { print $NF; exit }
              ' "$log" || true)"

              if ! printf '%s' "$got" | grep -qE '^sha256-[A-Za-z0-9+/]{43}=$'; then
                cat "$log" >&2
                echo "the build reported no hash for the placeholder in $file" >&2
                exit 1
              fi

              replace "$file" "$fake" "$got"
              if [ "$got" = "$hash" ]; then
                echo "$file: $hash is unchanged"
              else
                echo "$file: $hash -> $got"
              fi
            done

            # Past this point every hash was produced by a fetch that just ran, so
            # a later failure is not one this script should undo.
            restore=0

            if ! nix build .#default --no-link > "$log" 2>&1; then
              cat "$log" >&2
              echo "the hashes are up to date, but the build fails for another reason" >&2
              exit 1
            fi

            echo "all hashes are up to date"
          '';
        };
      in
      {
        checks.nixosModules = test;
        packages = {
          devenv-up = devShell.config.procfileScript;
          default = pkg;
          update-nix-hashes = updateNixHashes;
        };
        devShells.default = devShell;
      }
    )
    // {
      nixosModules.default = import ./module.nix { inherit self; };
    };
}
