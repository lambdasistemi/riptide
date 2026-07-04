# Plan

## Stack
- PureScript / Halogen frontend.
- Hand-written CSS in `frontend/dist/index.html`.
- Pure reducer tests in `frontend/test/Main.purs`.
- Browser interaction smoke embedded in `gate.sh`.

## Slice 1: delete cancel + centered icons
Implement one bisect-safe frontend slice because the reducer, views, CSS, and smoke test are tightly coupled:

- Add a pure disarm function such as `cancelConfirm :: App -> App` in `Riptide.Reducer` and expose it.
- Add an app action for cancel/disarm and route it from:
  - explicit cancel buttons shown beside armed delete buttons,
  - `Esc`,
  - clicks outside the active confirm affordance.
- Add a cancel glyph or use a clear existing icon pattern; do not add dependencies.
- Ensure every delete surface shows both "Confirm delete ..." and an adjacent cancel button when armed.
- Keep the second click on "Confirm delete ..." as the only delete confirmation path.
- Center all icon glyphs via CSS and stable button dimensions.
- Extend reducer and smoke tests.

## Verification
- Focused RED/GREEN: `nix develop --command just -f frontend/justfile test` from repo root if needed, or `cd frontend && nix develop .. --command just unit` if that is the local pattern.
- Full gate: `./gate.sh`.
- Manual browser proof through the smoke: arm -> cancel leaves target; arm -> confirm removes target; centered icon assertions pass.
