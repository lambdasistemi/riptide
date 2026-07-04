# Implementation Plan

## Tech stack

- PureScript Halogen frontend.
- Static CSS in `frontend/dist/index.html`.
- Existing repository gate in `gate.sh`, including headless Chromium interaction smoke.

## Slice strategy

This is one vertical frontend cleanup slice. The markup and CSS changes are tightly coupled, and the render smoke must move with the renamed/removed control containers.

## Slice 1: compact controls and global labels

Owned implementation surface:

- `frontend/src/Riptide/View/Song.purs`
- `frontend/src/Riptide/View/Shell.purs`
- `frontend/dist/index.html`
- `gate.sh`

Expected changes:

- In `Song.purs`, restructure cell tile controls into one strip and track gutter controls into one row above sliders.
- In `Shell.purs`, group top-bar global actions into labeled Song and Toolbox clusters with visible labels and retained tooltips.
- In `index.html`, tighten spacing and sizes for cells, tracks, controls, and global action groups.
- In `gate.sh`, update smoke selectors to assert the new control structure and continue verifying preserved behavior.

## Verification

- Run `./gate.sh`.
- Inspect the browser-rendered frontend in headless smoke, with selectors proving the layout is compact and the core interactions still work.
