# Issue 29: frontend icon buttons and tooltips

## P1 user story

As a riptide user arranging live songs and definitions, I want repeated command
buttons to use compact, readable icons with tooltips so the interface is easier
to scan while every action remains discoverable.

## Functional requirements

- Replace text-label command buttons in `frontend/src/Riptide/View/*.purs` with
  self-contained inline SVG line icons where the action is conventional: open,
  rename, duplicate/copy, delete/confirm delete, stop, launch/play, add, import,
  export, hush, pause/play, loop, and loop movement.
- Keep text only where the label itself is primary content or where an icon-only
  control would be ambiguous, such as tabs, row names, status chips, score
  readouts, form labels, and validation/status badges.
- Every icon button must expose an accessible name and tooltip via `title`, and
  icon-only controls must not depend on visible text for discoverability.
- Icons must be inline SVG in one consistent Feather/Lucide-like line style;
  no icon fonts, CDNs, remote scripts, or image assets.
- Preserve all existing handlers, state flow, reducers, client behavior, and
  import/export semantics. This ticket is markup and CSS only.
- Match the existing dark app aesthetic in `frontend/design/Riptide.dc.html`:
  compact command targets, muted lines, cyan/green accents, and a clear danger
  style.

## Success criteria

- Song, toolbox, track, cell, top-bar/action-bar, and score transport controls
  use consistent icon buttons with comfortable hit targets and 18-20px glyphs.
- All icon buttons have `title` attributes; danger confirmations remain
  distinguishable from ordinary delete actions.
- `nix build .#frontend` succeeds.
- Pure core tests and repo checks remain green through `./gate.sh`.
