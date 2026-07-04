# Tasks

## Slice 1 - Delete cancel and icon centering
- [ ] T034-S1 Add reducer disarm coverage and implementation.
- [ ] T034-S1 Wire cancel action through all delete views and the top-level app interactions.
- [ ] T034-S1 Center icon glyphs in all button boxes without regressing click behavior.
- [ ] T034-S1 Extend browser smoke for arm/cancel, arm/confirm, and practical icon centering checks.
- [ ] T034-S1 Run `./gate.sh` and commit one bisect-safe changeset.

## Slice 2 - Cell control cleanup
- [ ] T034-S2 Replace the cell eye select button with per-track radio groups wired to `selectCell`.
- [ ] T034-S2 Replace the pause-like grip glyph with a subtle six-dot drag handle.
- [ ] T034-S2 Adjust cell header CSS to read cleanly as grip, radio, state badge.
- [ ] T034-S2 Extend browser smoke for radio mutual exclusion, grip shape, centered glyphs, and clean render.
- [ ] T034-S2 Run `./gate.sh` and commit one bisect-safe changeset.
