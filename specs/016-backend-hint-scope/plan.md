# Plan: Backend Hint Scope

## Technical Shape

`Riptide.Eval` remains the impure shell around `hint`. It should not import
`Riptide.Session`; instead it accepts a simple list of definition source
strings. The implementation can build a Haskell expression that places the
definitions before the track expression and asks hint to type-check or
interpret the result as `ControlPattern`.

The important existing interpreter wiring must remain unchanged:

- `interpLibdir` reads `RIPTIDE_GHC` and falls back to `ghc`.
- `interpArgs` includes `-XOverloadedStrings`.
- imports include `Prelude`, `Sound.Tidal.Context`, and `Data.Map`.
- validation uses `typeChecks` and interpretation uses `interpret`.

## Slice Breakdown

### Slice 1: Scoped Eval API and Tests

Add scoped Eval functions and focused Hspec coverage. Keep the old API as
empty-scope wrappers. The slice owns only:

- `src/Riptide/Eval.hs`
- `test/Riptide/EvalSpec.hs`
- `test/Spec.hs`
- `riptide.cabal`

The driver must run a focused Eval unit test through the Nix dev shell, then
the full `./gate.sh`.

## Risks

- Hint parse failures for assembled scoped expressions must surface as
  `InterpreterError` values. Do not use partial string parsing or exceptions.
- Definition text may already include `let`. The implementation should support
  the domain model's current representation without forcing service-layer
  changes.
- Tidal expressions depend on type inference and overloaded string literals;
  changing imports or interpreter args would regress existing behavior.
