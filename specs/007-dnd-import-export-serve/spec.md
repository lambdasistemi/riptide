# Issue 7 Spec — DnD, Import/Export, Serve

## P1 User Story
A performer can reorder a song during live editing, move variations between
tracks without fighting text selection, round-trip songs/toolboxes through JSON
files, and open the built mock from a static served `dist/` directory.

## Functional Requirements
- Track rows reorder by dragging only the explicit gutter grip.
- Cell tiles move within or across tracks by dragging only the explicit cell
  header grip.
- Drop targets expose insertion feedback through `over` state and clear on drop
  or drag end.
- Starting any drag clears a pending delete confirmation.
- Cross-track movement of an active cell clears the source track's `active`.
- Song export downloads a `{ "riptideSong": 1, ... }` JSON file from the pure
  `Riptide.ImportExport.exportSong` transform.
- Song import reads a local file, decodes it, regenerates ids through
  `Riptide.ImportExport.importSong`, makes it current, and switches to Song.
- Toolbox export/import mirror song export/import with
  `{ "riptideToolbox": 1, ... }` and switch to Definitions on import.
- Success and failure paths set a transient toast that clears after 2400 ms.
- `frontend/justfile` exposes a local static `serve`/`dev` recipe for `dist/`.
- GitHub Pages deploy builds `.#frontend`, uploads `dist`, and deploys on pushes
  to `main`; enabling Pages remains an operator step noted in the PR.

## Acceptance
- `nix develop .#frontend -c just test` keeps the 21 core tests green.
- `nix build .#frontend` produces `dist/index.html` and `dist/index.js`.
- Browser smoke confirms drag handles work, textareas remain editable, import
  and export round-trip, toasts appear and clear, and `dist/` is serveable.
