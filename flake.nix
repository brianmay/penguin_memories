{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        beamPkg = pkgs.beam.packagesWith pkgs.erlangR25;
        elixir = beamPkg.elixir.override {
          version = "1.14.0";
          sha256 = "NJQ2unK7AeLGfaW/hVXm7yroweEfudKVUa216RUmLJs=";
        };
        elixir_ls = pkgs.elixir_ls.override { elixir = elixir; };

      in {
        devShell = pkgs.mkShell {
          packages = with pkgs.buildPackages; [ elixir elixir_ls ];
        };
      });
}
