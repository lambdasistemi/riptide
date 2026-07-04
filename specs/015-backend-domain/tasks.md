# Tasks: Backend Domain And Stores

## Slice 1 - Pure Session Domain

- [X] T015-S1 Add `Riptide.Session` with pure domain types, hidden slot values,
  bounded slot pool handling, and reducers for tracks, texts, selection,
  activation, silence, and definition blocks.
- [X] T015-S1 Add Hspec/QuickCheck tests with standalone generators proving at
  most one active text per track and live slot uniqueness.
- [X] T015-S1 Update `riptide.cabal` only as needed for the new exposed module,
  dependencies, and tests.
- [X] T015-S1 Run the focused session tests and `./gate.sh`, then commit as
  `feat(backend): add pure session domain`.

## Slice 2 - Separate JSON Stores

- [ ] T015-S2 Add `Riptide.Store` as a thin impure shell that persists tracks and
  definitions to two separate JSON files under a state directory.
- [ ] T015-S2 Load definitions before tracks when assembling a session from the
  state directory.
- [ ] T015-S2 Add Hspec/QuickCheck tests with standalone generators proving
  `save` followed by `load` returns the same tracks and definitions state.
- [ ] T015-S2 Update `riptide.cabal` only as needed for the new exposed module
  and store dependencies.
- [ ] T015-S2 Run the focused store tests and `./gate.sh`, then commit as
  `feat(backend): add JSON session stores`.
