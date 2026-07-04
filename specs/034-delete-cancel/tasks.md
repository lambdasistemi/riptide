# Tasks

## Slice 1 - Delete cancel and icon centering
- [X] T034-S1 Add reducer disarm coverage and implementation.
- [X] T034-S1 Wire cancel action through all delete views and the top-level app interactions.
- [X] T034-S1 Center icon glyphs in all button boxes without regressing click behavior.
- [X] T034-S1 Extend browser smoke for arm/cancel, arm/confirm, and practical icon centering checks.
- [X] T034-S1 Run `./gate.sh` and commit one bisect-safe changeset.

## Slice 2 - Cell control cleanup
- [X] T034-S2 Replace the cell eye select button with per-track radio groups wired to `selectCell`.
- [X] T034-S2 Replace the pause-like grip glyph with a subtle six-dot drag handle.
- [X] T034-S2 Adjust cell header CSS to read cleanly as grip, radio, state badge.
- [X] T034-S2 Extend browser smoke for radio mutual exclusion, grip shape, centered glyphs, and clean render.
- [X] T034-S2 Run `./gate.sh` and commit one bisect-safe changeset.
