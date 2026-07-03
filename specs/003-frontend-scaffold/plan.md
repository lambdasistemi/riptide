# Plan

## Stack

- PureScript app under `frontend/`.
- Spago 2 (`spago-unstable`) with registry `72.1.0`.
- Halogen for the minimal UI.
- esbuild for the browser bundle entry.
- Nix packaging via `purescript-overlay` and `mkSpagoDerivation`.
- CI on the existing self-hosted `nixos` runner with Cachix.

## Slices

### Slice 1: frontend project skeleton

Create `frontend/` with the PureScript source, static shell, package manifests, Spago lock, justfile, and copied design reference files. The app only renders the toolchain placeholder.

### Slice 2: Nix frontend package and shell

Add the PureScript overlay inputs and expose `packages.frontend` plus `devShells.frontend` while keeping the existing backend outputs intact.

### Slice 3: frontend CI

Add a frontend CI job to the existing workflow. It builds `.#frontend` and runs the PureScript formatter check through the frontend dev shell.

## Gate

The ticket gate is `./gate.sh` from the worktree root. It runs:

- `nix build .#frontend`
- verifies the result contains `index.html` and `index.js`
- `nix develop .#frontend -c just lint`
