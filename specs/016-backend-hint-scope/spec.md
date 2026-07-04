# Spec: Backend Hint Validation Against Definitions Scope

## User Story

As a performer, I want shared Tidal definition blocks to be in scope when a
track is validated or interpreted, so a track can safely reference named
patterns such as `feel` before it is allowed to produce sound.

## Functional Requirements

- `Riptide.Eval` exposes scoped validation and interpretation functions that
  accept active definition source text independently of `Riptide.Session`.
- Existing unscoped validation and interpretation functions continue to work
  as empty-scope variants.
- Scoped validation makes valid definition bindings available to the track
  expression.
- A track that references an undefined name fails with a compiler error rather
  than crashing.
- A syntactically broken definition in scope causes dependent validation to
  fail with a compiler error rather than crashing.
- The existing hint setup is preserved: the Nix-provided `RIPTIDE_GHC` libdir,
  `-XOverloadedStrings`, `Sound.Tidal.Context`, and `Data.Map` import wiring.

## Success Criteria

- Unit tests exercise real Tidal/hint validation for defined names,
  undefined names, broken definitions, and empty-scope compatibility.
- `./gate.sh` passes locally before the draft PR is marked complete.
- The PR remains decoupled from `Riptide.Session`; a later service layer can
  bridge `Session` definitions into the simple scoped Eval input.
