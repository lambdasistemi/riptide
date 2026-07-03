# Plan

## Slice 1 — Model, Validation, and Helpers

Add the PureScript domain modules under `frontend/src/Riptide/` plus focused
tests for validation, definition parsing, cascade, selected fallback, and score
normalization. This slice establishes the data contracts and pure helper
surface, with no reducers yet.

Owned files:

- `frontend/src/Riptide/**`
- `frontend/test/**`
- `frontend/spago.yaml`
- `frontend/spago.lock` only for dependency entries mechanically required by
  the `spago.yaml` changes; no registry bump.
- `frontend/justfile`
- `.github/workflows/ci.yml`

## Slice 2 — Reducers and Transforms

Add the total reducer/action surface and pure import/export transforms. Expand
tests with example reducer specs and QuickCheck properties for invariant
preservation, regenerated ids, import/export round trips, and automation.

Owned files:

- `frontend/src/Riptide/**`
- `frontend/test/**`
- `frontend/spago.yaml`
- `frontend/spago.lock` only for dependency entries mechanically required by
  the `spago.yaml` changes; no registry bump.
- `frontend/justfile`
- `.github/workflows/ci.yml`

## Verification

`gate.sh` runs:

- `nix develop .#frontend -c just test`
- `nix develop .#frontend -c purs-tidy check 'src/**/*.purs' 'test/**/*.purs'`
- `nix build .#frontend`

The CI frontend job must run the new test recipe before build/lint.
