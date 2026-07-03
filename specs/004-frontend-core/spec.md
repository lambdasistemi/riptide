# Issue 4 — Frontend Pure Core

## User Story

As the frontend implementer for riptide, I need a pure domain/state core for the
launch grid, score automation, definition toolboxes, and import/export
transforms so later UI tickets can wire Halogen views without embedding business
logic in components.

## Scope

Source of truth: `frontend/design/riptide-spec.md`, especially sections 1, 2, 4,
5, 7, and pure parts of 9.

In scope:

- Pure domain model for `App`, `Song`, `Track`, `Cell`, `Toolbox`, `Block`, and
  transient UI/transport fields.
- Total pure reducers/actions for transport, grid, song, toolbox, block, rails,
  score painting/loop helpers, gated delete, and import/export transforms.
- Pure validation, definition-name parsing, cascade analysis, and
  `applyAutomation`.
- Deterministic id inputs for every creation/duplicate/import path.
- Focused `spec` and QuickCheck-style tests under `frontend/test`.
- Frontend test wiring through `spago.yaml`, `frontend/justfile`, `gate.sh`, and
  the frontend CI job.

Out of scope:

- Halogen views, DOM events, file reading, blob downloads, random id effects,
  requestAnimationFrame, and `frontend/src/Main.purs`.
- Backend Haskell code and backend flake outputs.

## Functional Requirements

- `TOTAL_BARS` is 16 and every public reducer preserves score length.
- A track has at most one active cell because `active` is a nullable id.
- `effectiveSelected` falls back to the first cell when `selected` is absent or
  stale.
- Editing an active cell to invalid code stops that track.
- Manual launch starts/arms the cell; stopping preserves selected.
- Engine-off and hush silence only the current song.
- Two-step delete uses the pure `confirm` gate and only deletes on matching key.
- Duplicates/imports regenerate ids and remap active/selected references.
- Import/export transforms are pure and round-trip the exported wire shapes.
- `valid`, `definedNames`, and `cascade` match the committed spec behavior.
- `applyAutomation bar` leaves unpainted tracks manual, drives painted tracks,
  respects engine state, selected fallback, and validation.

## Acceptance

- `./gate.sh` passes in `/home/paolino/riptide-4`.
- `nix build .#frontend` passes.
- CI frontend job runs the new test recipe.
- Final PR is a draft against `main` from `feat/frontend-core`.
