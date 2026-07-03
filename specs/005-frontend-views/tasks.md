# Issue 5 Tasks

## Slice 1 — App Foundation And Seed
- [x] T005-S1 Replace `frontend/src/Main.purs` with the Halogen entry.
- [x] T005-S1 Add root app/view modules under `frontend/src/Riptide/`.
- [x] T005-S1 Seed `Riptide.Model.App` from the prototype §11 data.
- [x] T005-S1 Wire shell navigation, engine toggle, Hush, scope chip, active count, and id minting.
- [x] T005-S1 Prove with `./gate.sh` and commit `feat(frontend): add riptide app shell`.

## Slice 2 — Song Page
- [ ] T005-S2 Implement song rail list/new/open/rename/duplicate/delete.
- [ ] T005-S2 Implement launch grid track gutters, controls, stop, add track, add cell, and cell editing/launch/select/delete.
- [ ] T005-S2 Render visually distinct empty, has-text-idle, selected-armed, active-playing, invalid, and being-edited cell states.
- [ ] T005-S2 Add the clearly marked Score timeline placeholder without timeline behavior.
- [ ] T005-S2 Prove with `./gate.sh` and commit `feat(frontend): build song page`.

## Slice 3 — Definitions Page
- [ ] T005-S3 Implement toolbox rail list/new/open/rename/duplicate/delete.
- [ ] T005-S3 Implement block editing, validity, invalid errors, unsaved/applied badges, apply/apply-all enablement, and delete.
- [ ] T005-S3 Render cascade warnings via `Riptide.Helpers.cascade` and live-scope warnings.
- [ ] T005-S3 Polish empty states and responsive page layout.
- [ ] T005-S3 Prove with `./gate.sh`, smoke both pages, and commit `feat(frontend): build definitions page`.
