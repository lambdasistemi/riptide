{
  description = "riptide — live TidalCycles track mixer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        hp = pkgs.haskellPackages;

        riptide = hp.callCabal2nix "riptide" ./. { };
      in
      {
        packages.default = riptide;
        packages.riptide = riptide;

        devShells.default = hp.shellFor {
          packages = _: [ riptide ];
          withHoogle = false;
          nativeBuildInputs = [
            pkgs.cabal-install
            hp.fourmolu
            hp.hlint
            hp.cabal-fmt
            hp.haskell-language-server
            pkgs.just
            pkgs.nixfmt
            pkgs.shellcheck
          ];
        };
      }
    );
}
