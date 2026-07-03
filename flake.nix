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

        riptide-hs = hp.callCabal2nix "riptide" ./. { };

        # GHC whose package DB exposes tidal — hint interprets track text
        # against this at runtime (see Riptide.Eval).
        ghcInterp = hp.ghcWithPackages (p: [ p.tidal ]);

        # The shipped executable, wrapped to point hint at ghcInterp.
        riptide =
          pkgs.runCommand "riptide-${riptide-hs.version}"
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
              meta = riptide-hs.meta // {
                mainProgram = "riptide";
              };
            }
            ''
              makeWrapper ${riptide-hs}/bin/riptide $out/bin/riptide \
                --set RIPTIDE_GHC ${ghcInterp}/bin/ghc
            '';
      in
      {
        packages.default = riptide;
        packages.riptide = riptide;
        packages.riptide-unwrapped = riptide-hs;

        devShells.default = hp.shellFor {
          packages = _: [ riptide-hs ];
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
