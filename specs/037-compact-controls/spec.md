# Issue 37: compact controls and labeled global actions

## P1 user story

As a riptide user arranging tracks and cells, I need each editable unit to keep its controls in a compact, predictable place so the code area stays prominent and global song/toolbox actions are unambiguous.

## Scope

- Collapse each cell's header/actions into one compact strip.
- Collapse each track gutter's grip/name/stop/delete controls into one compact row above the existing VOL/FLT/DLY sliders.
- Reduce empty padding, gaps, and min-height where the current layout creates unused space.
- Group top-bar global actions into visible Song and Toolbox clusters, preserving tooltips.

## Functional requirements

- FR-037-001: Cell markup has a single top strip containing the drag grip, native radio selector, state badge, spacer, play/stop button, and delete/confirm/cancel controls.
- FR-037-002: The separate bottom `.rt-cell-actions` row is removed; the textarea occupies the remaining vertical space.
- FR-037-003: Track gutter markup has a compact row containing drag grip, track name, stop, and delete/confirm/cancel controls, followed by the existing control sliders.
- FR-037-004: The separate `.rt-track-tools` box is removed.
- FR-037-005: Global action buttons are grouped into labeled Song and Toolbox clusters: new, export, import.
- FR-037-006: Existing interaction behavior remains intact: radio select is mutually exclusive per track, drag grips still drag, play/stop still toggles/un-arms a cell, and delete remains two-step with cancel.

## Success criteria

- `./gate.sh` passes.
- Browser smoke verifies one compact strip per cell, no legacy `.rt-cell-actions` row, no `.rt-track-tools` wrapper, labeled Song/Toolbox action clusters, and preserved interactions.
- `nix build .#frontend` passes.
