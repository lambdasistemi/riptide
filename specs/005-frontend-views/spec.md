# Issue 5 — Frontend Views

## P1 Story
As a live performer, I can open riptide and work with the Song and Definitions pages over the pure `Riptide.Model.App` state, seeing every launch-grid and definition state clearly while interactions update state through `Riptide.Reducer`.

## Functional Requirements
- Render a Halogen app from `src/Main.purs` with component state exactly backed by `Riptide.Model.App`.
- Provide a persistent shell with Song/Definitions navigation, engine indicator/toggle, live scope chip, active count, and global Hush.
- Seed the initial app from the §11 prototype data, including invalid `feel` and cascade references.
- Song page must include song rail management, editable song/track names, track controls, launch cells, add/delete affordances, and all §10 cell states.
- The Score timeline is explicitly out of scope; the Song page must leave a clearly marked placeholder region for ticket #6.
- Definitions page must include toolbox rail management, block editing, valid/invalid/empty/applied/unsaved states, apply/apply-all rules, cascade warnings, and live-scope metadata.
- All id creation happens in the Halogen effect boundary and passes fresh opaque ids into pure reducers.

## Success Criteria
- `nix build .#frontend` succeeds.
- `nix develop .#frontend -c just test` keeps the pure core tests green.
- A browser smoke can navigate Song and Definitions, edit fields, launch/stop cells, add/arm-delete entities, and apply definitions.
- No production code outside the ticket-owned frontend view surface is changed.
