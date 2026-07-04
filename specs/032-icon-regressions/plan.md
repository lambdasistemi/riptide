# Plan: Icon Regression And Action Fixes

## Slice 1: Frontend View, CSS, And Smoke

Owned files:

- `frontend/src/Riptide/View/*.purs`
- `frontend/src/Riptide/App.purs` only if handler wiring is genuinely broken
- `frontend/dist/index.html`
- `gate.sh`
- `frontend/test/**`

Forbidden files:

- Haskell backend
- `frontend/src/Riptide/Model.purs`
- `frontend/src/Riptide/Reducer.purs` unless the worker proves the reducer is
  the real bug and writes a Q-file first
- dependency manifests

Implementation notes:

- Prefer fixing button classes/CSS in the view and stylesheet.
- Keep reducers untouched; `armDelete` and `toggleCell` already have pure tests.
- Strengthen the existing render smoke in `gate.sh` with CDP checks for visible
  icon glyphs, launch/stop toggling, and delete arm confirmation.
- Verify in a headless browser, not only by PureScript unit tests.

## Verification

- Focused frontend test or smoke RED before GREEN.
- `nix develop .#frontend --command just test` after code changes.
- `./gate.sh` before commit.
