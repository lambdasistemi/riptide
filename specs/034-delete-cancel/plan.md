# Plan

## Stack
- PureScript / Halogen frontend.
- Hand-written CSS in `frontend/dist/index.html`.
- Pure reducer tests in `frontend/test/Main.purs`.
- Browser interaction smoke embedded in `gate.sh`.

## Slice 1: delete cancel + centered icons
Implement the destructive-action safety fix and broad icon-centering pass:

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

## Slice 2: cell control cleanup
After Slice 1 lands, clean up the cell header controls:

- Replace the eye/select icon button with a real radio input per cell.
- Group radios by track, with the checked radio matching `track.selected`; clicking a radio calls existing `selectCell`.
- Change the grip glyph from pause-like `||` to a six-dot grip-vertical icon.
- Keep the grip visually subtle and preserve drag-and-drop from the grip.
- Tighten CSS for the target cell header: grip, radio, state badge; bottom actions remain play and delete.
- Extend browser smoke for radio mutual exclusion, grip glyph shape, and clean centered icon geometry.

## Verification
- Focused RED/GREEN: `nix develop .#frontend --command spago test` from repo root.
- Full gate: `./gate.sh`.
- Manual browser proof through the smoke: arm -> cancel leaves target; arm -> confirm removes target; centered icon, radio, and grip assertions pass.
