# Issue 7 Plan

## Existing Surface
- Pure transforms exist in `Riptide.ImportExport`.
- `App` already has `drag`, `over`, and `toast`.
- `Reducer` has pure app actions but lacks exported move helpers on this base.
- Song/Definitions/Shell views are Halogen, with CSS in `frontend/dist/index.html`.

## Slice 1 — Pure DnD Reducers
Add `moveTrack` and `moveCell` to `Riptide.Reducer` with focused tests. Keep this
small and core-only so UI slices can call stable pure actions.

## Slice 2 — DnD View Wiring
Wire HTML5 DnD through explicit handles in `Riptide.App` and `Riptide.View.Song`.
Use existing `drag`/`over` state, insertion classes, and clear state on drop/end.

## Slice 3 — Import/Export Effects And Toasts
Add `Riptide.View.Files.purs`/`.js` for Blob download and file read effects,
decode/encode the existing wire records in `Riptide.App`, add controls to Shell,
and render transient toasts.

## Slice 4 — Serve And Pages
Add static serve/dev recipes, ensure `dist/index.html` references the Nix-built
bundle cleanly, and add `.github/workflows/pages.yml` following the PureScript
skill's self-hosted `nixos` runner pattern.

## Finalization
Run the full gate, open a draft PR against `main`, include the operator step to
enable GitHub Pages, then mark the ticket complete with PR URL and SHA.
