{
  description = "Photo Database";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-23.11"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

  outputs = { self, nixpkgs, flake-utils }:
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
          hash = "sha256-Qmo35Al2TqOqumuiWV3ZobwjogjS40lvKLHSnUkeKtk=";
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

      in with pkgs; {
        packages.default = pkg;
        devShell = pkgs.mkShell {
          buildInputs = [ elixir elixir_ls glibcLocales node2nix nodejs ]
            ++ optional stdenv.isLinux inotify-tools
            ++ optional stdenv.isDarwin terminal-notifier
            ++ optionals stdenv.isDarwin
            (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);
        };
      });
}
