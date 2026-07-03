# Issue 6 Spec

## User Story
As a live performer, I need the Song page Score to schedule each track's selected variation across a 16-bar timeline, so playback and the launch grid stay visibly coupled while I paint arrangements and adjust loop bounds.

## Functional Requirements
- Replace the Song page score placeholder with a real Score panel below the launch grid.
- Render one score lane per current song track, in the same order and accent hue as the grid.
- Render 16 bar cells per lane; painted bars are filled, the current playhead bar is lit, and bars outside the effective loop are dimmed.
- Show a left lane label with accent, track name, on-now dot, and truncated `> selected cell code` using the reducer/helper semantics for effective selection.
- Support score painting with pointer handlers that call the existing pure `startPaint`, `paintEnter`, and `stopPaint` reducer actions.
- Add transport controls/readout for play/pause, loop on/off, `BAR n`, and loop bounds.
- Add loop limiter controls for start, end, and moving the loop, wired to the existing pure loop reducers.
- Add a view toggle for scroll-vs-fixed playhead behavior over the same underlying score data.
- Add the playhead rAF engine as the only genuine effect. It runs only while `playing`, advances at 1.6 seconds per bar, caps frame dt at 0.25s, wraps within the effective loop, and calls pure `applyAutomation bar` on bar change.

## Success Criteria
- `nix build .#frontend` passes.
- `nix develop -c just unit` passes.
- The Score renders on the Song page instead of the placeholder.
- Painting a bar schedules the selected cell, and playback calls `applyAutomation` so the matching grid cell enters the playing state at the playhead bar.
- Stopping playback cancels the loop while preserving the current playhead.

## Out Of Scope
- Definition page changes.
- Drag/drop track or cell ordering.
- Import/export file effects.
- Backend behavior or backend flake changes.
