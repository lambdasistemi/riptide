# Tasks

## Slice 1 - icon button skin

- [X] T029-S1 Add a shared inline SVG icon helper under `frontend/src/Riptide/View/`.
- [X] T029-S1 Replace command button text in Song, Definitions, Shell, and Score views with icon buttons where appropriate.
- [X] T029-S1 Add or adjust CSS in `frontend/dist/index.html` for comfortable icon targets, visual states, and tooltip/accessibility support.
- [X] T029-S1 Preserve existing handlers and behavior; only button contents/classes/titles and view imports may change.
- [X] T029-S1 Run `nix build .#frontend` and `./gate.sh`.
- [X] T029-S1 Commit as `feat(frontend): replace command labels with icon buttons` with `Tasks: T029-S1`.

## Slice 2 - blank render regression gate

- [X] T029-S2 Fix the SVG icon helper so SVG classes are set via attributes, not the `className` DOM property.
- [X] T029-S2 Add a headless browser smoke to `gate.sh` that fails on blank render and console/runtime errors.
- [X] T029-S2 Prove RED on the existing SVG `className` crash, then GREEN with `./gate.sh`.
- [X] T029-S2 Commit as `fix(frontend): guard icon render smoke` with `Tasks: T029-S2`.
