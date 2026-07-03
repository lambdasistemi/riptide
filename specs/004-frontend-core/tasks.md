# Tasks

## Slice 1 — Model, Validation, and Helpers

- [X] T004-S1 Define the Riptide domain/state modules and constants.
- [X] T004-S1 Implement pure validation, defined-name parsing, cascade, selected
      fallback, and score/id helper functions.
- [X] T004-S1 Add `spec`/QuickCheck test dependencies and focused tests for the
      helper layer.
- [X] T004-S1 Wire `frontend/justfile` and CI so frontend tests run.
- [X] T004-S1 Pass `./gate.sh` and commit with the required trailer.

## Slice 2 — Reducers and Transforms

- [ ] T004-S2 Implement all pure reducers/actions, score automation, gated
      delete, and import/export transforms.
- [ ] T004-S2 Add reducer examples and properties covering invariants,
      regenerated ids, and import/export round trips.
- [ ] T004-S2 Pass `./gate.sh` and commit with the required trailer.

## Finalization

- [ ] T004-F1 Create/update the draft PR against `main`.
- [ ] T004-F1 Verify final `./gate.sh`, `nix build .#frontend`, and PR metadata.
