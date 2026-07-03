# Issue 3: Frontend Scaffold

## P1 User Story

As a riptide contributor, I can build a minimal PureScript/Halogen frontend with Nix so later UI tickets start from a proven, reproducible toolchain.

## Requirements

- Create a `frontend/` PureScript app using Spago 2, Halogen, esbuild, and a committed npm lockfile.
- Pin the Spago registry to `72.1.0` and use dependencies `prelude`, `effect`, `aff`, `console`, and `halogen`.
- Render a minimal page containing `riptide` and one placeholder line.
- Copy the provided design reference files into `frontend/design/` unchanged for later tickets.
- Add frontend Nix packaging without removing existing Haskell packages or the default dev shell.
- Add a frontend dev shell with PureScript, Spago, purs-tidy `0.10.0`, esbuild, Node, and just.
- Add CI coverage for `nix build .#frontend` and `nix develop .#frontend -c just lint`.

## Success Criteria

- `nix build .#frontend` succeeds.
- The build output contains `index.html` and `index.js`.
- `nix develop .#frontend -c just lint` succeeds.
- Existing Haskell package outputs and CI jobs remain present.
