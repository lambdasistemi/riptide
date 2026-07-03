{
  description = "riptide — live TidalCycles track mixer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkSpagoDerivation = {
      url = "github:jeslie0/mkSpagoDerivation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      purescript-overlay,
      mkSpagoDerivation,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            mkSpagoDerivation.overlays.default
            purescript-overlay.overlays.default
          ];
        };
        hp = pkgs.haskellPackages;

        riptide-hs = hp.callCabal2nix "riptide" ./. { };
        frontendSrc = ./frontend;
        frontendNodeModules = pkgs.importNpmLock.buildNodeModules {
          npmRoot = frontendSrc;
          nodejs = pkgs.nodejs_22;
        };

        frontend = pkgs.mkSpagoDerivation {
          pname = "riptide-frontend";
          version = "0.0.0";
          src = frontendSrc;
          spagoYaml = "${frontendSrc}/spago.yaml";
          spagoLock = "${frontendSrc}/spago.lock";
          nativeBuildInputs = [
            pkgs.esbuild
            pkgs.nodejs_22
            pkgs.purs
            pkgs.spago-unstable
          ];
          buildPhase = ''
            ln -s ${frontendNodeModules}/node_modules node_modules
            spago bundle --offline --module Main
            mv index.js dist/index.js
          '';
          installPhase = ''
            mkdir -p $out
            substitute dist/index.html $out/index.html \
              --replace-fail "../src/bootstrap.js" "./index.js"
            cp dist/index.js $out/index.js
          '';
        };

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
        packages.frontend = frontend;

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
        devShells.frontend = pkgs.mkShell {
          packages = [
            pkgs.esbuild
            pkgs.just
            pkgs.nodejs_22
            pkgs.purescript-language-server
            pkgs.purs
            pkgs.purs-tidy-bin.purs-tidy-0_10_0
            pkgs.spago-unstable
          ];
          shellHook = ''
            cd frontend
          '';
        };
      }
    );
}
