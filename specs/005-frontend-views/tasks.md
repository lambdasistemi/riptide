# Issue 5 Tasks

## Slice 1 — App Foundation And Seed
- [x] T005-S1 Replace `frontend/src/Main.purs` with the Halogen entry.
- [x] T005-S1 Add root app/view modules under `frontend/src/Riptide/`.
- [x] T005-S1 Seed `Riptide.Model.App` from the prototype §11 data.
- [x] T005-S1 Wire shell navigation, engine toggle, Hush, scope chip, active count, and id minting.
- [x] T005-S1 Prove with `./gate.sh` and commit `feat(frontend): add riptide app shell`.

## Slice 2 — Song Page
- [x] T005-S2 Implement song rail list/new/open/rename/duplicate/delete.
- [x] T005-S2 Implement launch grid track gutters, controls, stop, add track, add cell, and cell editing/launch/select/delete.
- [x] T005-S2 Render visually distinct empty, has-text-idle, selected-armed, active-playing, invalid, and being-edited cell states.
- [x] T005-S2 Add the clearly marked Score timeline placeholder without timeline behavior.
- [x] T005-S2 Prove with `./gate.sh` and commit `feat(frontend): build song page`.

## Slice 3 — Definitions Page
- [x] T005-S3 Implement toolbox rail list/new/open/rename/duplicate/delete.
- [x] T005-S3 Implement block editing, validity, invalid errors, unsaved/applied badges, apply/apply-all enablement, and delete.
- [x] T005-S3 Render cascade warnings via `Riptide.Helpers.cascade` and live-scope warnings.
- [x] T005-S3 Polish empty states and responsive page layout.
- [x] T005-S3 Prove with `./gate.sh`, smoke both pages, and commit `feat(frontend): build definitions page`.
