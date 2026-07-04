# Issue 34: explicit armed-delete cancel

## P1 Story
A user who accidentally arms a destructive delete can back out immediately without waiting for the timeout and without risking a second click deleting data.

## Scope
- Frontend only.
- Applies to every gated delete: song, toolbox, track, cell, and block.
- Fold in the added CSS/cell-control pass: icon glyphs must be visually centered inside their button boxes, the cell grip must read as a real drag handle, and cell selection must use per-track radios instead of the redundant eye button.

## Functional Requirements
- When `confirm` is set for a delete key, the UI shows a cancel affordance next to that item's "Confirm delete" action.
- Activating cancel clears `confirm` immediately and does not delete the item.
- Pressing `Esc` clears an armed confirmation.
- Clicking elsewhere clears an armed confirmation.
- The existing 2800ms auto-cancel remains as a fallback.
- Confirming by clicking the armed delete button still deletes the target.
- Icon buttons, drag grips, transport buttons, rail buttons, top-bar buttons, and add-cell buttons center their SVG glyphs in a stable box.
- Cell headers render as grip, radio, state badge; bottom actions remain play and delete.
- Each track's cells form one radio group. The checked radio is the selected cell the score fires for that track, and clicking a radio calls the existing `selectCell`.
- The cell drag grip uses a subtle grip-vertical six-dot glyph, not a pause-like two-line glyph.

## Success Criteria
- Unit coverage proves reducer-level disarm if a pure reducer function is added.
- Browser smoke proves arm -> cancel keeps the item and clears confirm UI, and arm -> confirm still deletes.
- Browser smoke includes practical evidence that icon glyphs are visible and centered in their button boxes.
- Browser smoke proves radio selection is mutually exclusive per track.
- Browser smoke proves the grip icon no longer uses the pause-like two-line glyph.
- `./gate.sh` passes.
