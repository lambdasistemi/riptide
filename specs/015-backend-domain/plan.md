# Implementation Plan: Backend Domain And Stores

## Context

The existing backend package exposes only `Riptide` and `Riptide.Eval`.
`Riptide.Eval` is read-only for this ticket because a sibling ticket extends the
hint layer. This ticket adds pure backend state and a thin JSON persistence
shell, mirroring the frontend behavior spec sections 1, 2, 6, and 7.

## Technical Shape

- Add `Riptide.Session` for pure domain types, hidden slot assignment, and
  reducers.
- Add `Riptide.Store` for separate JSON stores for tracks and definitions.
- Keep IO out of `Riptide.Session`; only `Riptide.Store` touches the filesystem.
- Add only needed library dependencies to `riptide.cabal`: expected additions
  are `aeson`, `containers`, `text`, `directory`, and `filepath`.
- Keep tests in Hspec with explicit QuickCheck generators.

## Slice 1: Pure Session Domain

Add `Riptide.Session` and focused tests for pure reducer behavior. This slice
establishes typed IDs, cells/texts, tracks, definitions, slots, session state,
slot lifecycle, and reducer semantics. It also adds cabal exposure and test
dependencies required by this module.

Proof:

- A focused `Session` unit-test run observes RED before implementation.
- QuickCheck properties prove at most one active text per track and unique live
  slots after generated operation sequences.
- `./gate.sh` passes after the commit.

## Slice 2: Separate JSON Stores

Add `Riptide.Store` and tests that save/load tracks and definitions as separate
files in a state directory. Loading definitions before tracks must be visible in
the public shell function shape or implementation order. Store round-trip is a
QuickCheck property over generated sessions.

Proof:

- A focused `Store` unit-test run observes RED before implementation.
- Store round-trip property passes for generated sessions.
- `./gate.sh` passes after the commit.

## Orchestrator Finalization

After both behavior slices pass review, restore `gate.sh` to its `origin/main`
contents if this branch changed it only as a PR-lifetime backend gate, update PR
metadata, and mark the draft PR ready only when the final gate is green.
